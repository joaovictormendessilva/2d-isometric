class_name NetSync
extends Node
## Replica o Character pai pela rede (ADR-012). Offline, não faz nada.
##
## Quem SIMULA o corpo: o próprio jogador, para o personagem dele (resposta imediata ao
## controle); o host, para todo o resto. Os demais computadores só interpolam os estados
## recebidos, desenhando o corpo um pouco no passado para o movimento sair suave.
##
## Segurança (ADR-013): todo estado vem do host. O dono de um personagem só envia AO HOST
## a própria posição e pedidos de ataque; o host confere remetente, valores, frequência e
## velocidade antes de aceitar e repassar. Vida, dano, morte e renascimento são decididos
## só pelo host.

## Estados por segundo enviados por quem simula (20 Hz).
const SEND_INTERVAL := 0.05
## Atraso de desenho das entidades remotas: dois estados de folga contra variação de chegada.
const INTERPOLATION_DELAY := 0.1
## Salto entre estados que é tratado como teletransporte (renascer), sem interpolar.
const TELEPORT_DISTANCE := 48.0
const BUFFER_SIZE := 8
## Folga de chegada para ataques pela rede (ver `MeleeAttacker.try_attack`).
const ATTACK_TOLERANCE := 0.05
## Folga de alcance e de movimento para coletas pedidas pela rede (o host vê o dono atrasado).
const GATHER_SLACK := 8.0
## Validação de movimento no host: velocidade máxima aceita, em múltiplos da velocidade do
## personagem (cobre recuo e bote), e quanto deslocamento pode acumular (pacotes atrasados).
const MAX_SPEED_FACTOR := 3.0
const MOVE_BUDGET_TIME := 0.5
## Estados de um dono chegando mais rápido que isto são descartados (contra inundação).
const MIN_STATE_INTERVAL := SEND_INTERVAL * 0.5

var _send_left := 0.0
var _snapshots: Array[Dictionary] = []  # {t, position, facing}, em ordem de tempo
var _clock_offset := INF
var _last_sender_time := -INF
# Validação no host dos estados enviados pelo dono.
var _accepted_position := Vector2.ZERO
var _move_budget := 0.0
var _last_accept_time := -INF
var _broadcast: HostBroadcast
# Coleta pela rede: cada coleta do dono tem um número, para uma ordem de parar atrasada não
# derrubar uma coleta mais nova.
var _gather_seq := 0
var _stopping_on_request := false
## Calculados ao nascer: a conexão e o dono não mudam durante a vida da entidade, e estas
## perguntas são feitas todo quadro por todas as criaturas.
var _online := false
var _simulating := true
## Personagem trocado por outro numa viagem (ver Character.retire): ignora o dono.
var _retired := false

@onready var _body: Character = get_parent()


func _ready() -> void:
	_online = NetRules.is_online(multiplayer)
	_simulating = not _online or multiplayer.get_unique_id() == owner_peer()
	set_physics_process(_online)
	_accepted_position = _body.position
	_body.revived.connect(_on_revived.unbind(1))
	if _body.attacker:
		_body.attacker.attack_started.connect(_on_attack_started.unbind(1))
	if _body.health:
		_body.health.damaged.connect(_on_damaged)
		_body.health.changed.connect(_on_health_changed)
		_body.health.healed.connect(_on_healed)
		_body.health.blocked.connect(_on_blocked.unbind(1))
		_body.health.immunity_changed.connect(_on_immunity_changed)
	if _body.gatherer:
		_body.gatherer.started.connect(_on_gather_started.unbind(1))
		_body.gatherer.stopped.connect(_on_gather_stopped)
	_broadcast = HostBroadcast.new(self)
	HostBroadcast.request_from_host(self, &"_request_full_state")


func is_online() -> bool:
	return _online


## Computador que simula este corpo.
func owner_peer() -> int:
	return _body.player_id if _body.player_id != 0 else 1


## Host: o corpo foi aposentado (viagem); mensagens atrasadas do dono deixam de valer.
func retire() -> void:
	_retired = true


func is_simulating() -> bool:
	return _simulating


func _physics_process(delta: float) -> void:
	if _simulating:
		_send_left -= delta
		if _send_left <= 0.0:
			_send_left += SEND_INTERVAL
			_send_state(NetRules.now(), _body.position, _body.facing)
	else:
		_interpolate(delta)


func _send_state(t: float, position: Vector2, facing: Vector2) -> void:
	if multiplayer.is_server():
		_send_to_clients(&"_state", [t, position, facing], false)
	else:
		_owner_state.rpc_id(1, t, position, facing)


## Dono → host: posição do personagem do jogador, validada antes de valer.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _owner_state(t: float, position: Vector2, facing: Vector2) -> void:
	if _retired or not multiplayer.is_server() or multiplayer.get_remote_sender_id() != owner_peer():
		return
	if not is_finite(t) or not NetRules.is_valid_vector(position) or not facing.is_finite():
		return
	var now := NetRules.now()
	if now - _last_accept_time < MIN_STATE_INTERVAL:
		return
	if not _within_move_budget(position, now):
		_correct.rpc_id(owner_peer(), _accepted_position)
		return
	facing = NetRules.clean_direction(facing)
	if facing == Vector2.ZERO:
		facing = _body.facing
	_receive_state(t, position, facing)
	_send_state(t, position, facing)


## Host → clientes: estado oficial do corpo.
@rpc("authority", "call_remote", "unreliable_ordered")
func _state(t: float, position: Vector2, facing: Vector2) -> void:
	if is_finite(t) and NetRules.is_valid_vector(position) and facing.is_finite():
		_receive_state(t, position, facing)


## Deslocamento desde o último estado aceito cabe na velocidade máxima (plano do chão)?
## O "orçamento" acumula com o tempo do HOST (o do cliente não é confiável).
func _within_move_budget(position: Vector2, now: float) -> bool:
	var max_speed := _body.move_speed() * MAX_SPEED_FACTOR
	var elapsed := minf(now - _last_accept_time, MOVE_BUDGET_TIME)
	_move_budget = minf(_move_budget + max_speed * elapsed, max_speed * MOVE_BUDGET_TIME)
	_last_accept_time = now
	var distance := Iso.ground_distance(position, _accepted_position)
	if distance > _move_budget:
		return false
	_move_budget -= distance
	_accepted_position = position
	return true


func _receive_state(t: float, position: Vector2, facing: Vector2) -> void:
	if t <= _last_sender_time:
		return  # velho ou repetido
	_last_sender_time = t
	_clock_offset = minf(_clock_offset, NetRules.now() - t)
	var last: Vector2 = _snapshots[-1].position if not _snapshots.is_empty() else position
	if position.distance_to(last) > TELEPORT_DISTANCE:
		_snapshots.clear()
		_teleport(position)
	_snapshots.append({t = t, position = position, facing = facing})
	if _snapshots.size() > BUFFER_SIZE:
		_snapshots.pop_front()


## Desenha o corpo no instante "agora − atraso" do relógio de quem o simula, entre os dois
## estados vizinhos. Sem estado novo, fica no último (sem adivinhar o futuro).
func _interpolate(delta: float) -> void:
	if _snapshots.is_empty():
		return
	var render_time := NetRules.now() - _clock_offset - INTERPOLATION_DELAY
	while _snapshots.size() >= 2 and _snapshots[1].t <= render_time:
		_snapshots.pop_front()
	var from: Dictionary = _snapshots[0]
	var position: Vector2 = from.position
	var facing: Vector2 = from.facing
	if _snapshots.size() >= 2 and render_time > from.t:
		var to: Dictionary = _snapshots[1]
		var weight := clampf((render_time - from.t) / (to.t - from.t), 0.0, 1.0)
		position = from.position.lerp(to.position, weight)
		facing = to.facing if weight >= 0.5 else facing
	_body.ground_velocity = Iso.screen_to_ground(position - _body.position) / delta
	_body.position = position
	if facing != Vector2.ZERO:
		_body.facing = facing


func _teleport(position: Vector2) -> void:
	_body.position = position
	_body.reset_physics_interpolation()
	_accepted_position = position


## Host → clientes que já têm esta entidade. `include_owner`: o dono também precisa (ex.:
## dano no próprio personagem); estado e ataques ele mesmo gerou.
func _send_to_clients(method: StringName, args: Array, include_owner: bool) -> void:
	_broadcast.send(method, args, 0 if include_owner else owner_peer())


# --- Ataques -------------------------------------------------------------------------------

func _on_attack_started(direction: Vector2) -> void:
	if not is_online():
		return
	if multiplayer.is_server():
		_send_to_clients(&"_attack_played", [direction], false)
	elif is_simulating():
		_request_attack.rpc_id(1, direction)


## Dono → host. O host aplica as próprias regras (vivo, ritmo do ataque) antes de aceitar.
@rpc("any_peer", "call_remote", "reliable")
func _request_attack(direction: Vector2) -> void:
	if _retired or not multiplayer.is_server() or multiplayer.get_remote_sender_id() != owner_peer():
		return
	direction = NetRules.clean_direction(direction)
	if direction != Vector2.ZERO:
		_body.play_remote_attack(direction, ATTACK_TOLERANCE)


@rpc("authority", "call_remote", "reliable")
func _attack_played(direction: Vector2) -> void:
	direction = NetRules.clean_direction(direction)
	if direction != Vector2.ZERO:
		_body.play_remote_attack(direction, ATTACK_TOLERANCE)


# --- Coleta ------------------------------------------------------------------------------

func _on_gather_started(node: ResourceNode) -> void:
	if is_online() and is_simulating() and not multiplayer.is_server():
		_gather_seq += 1
		_request_gather.rpc_id(1, String(node.name), _gather_seq)


func _on_gather_stopped() -> void:
	if not is_online():
		return
	if is_simulating() and not multiplayer.is_server():
		_stop_gather.rpc_id(1, _gather_seq)
	elif multiplayer.is_server() and owner_peer() != 1 and not _stopping_on_request:
		_gather_stopped.rpc_id(owner_peer(), _gather_seq)


## Dono → host. O host confere tudo de novo (alcance, ferramenta, nível) antes de aceitar.
@rpc("any_peer", "call_remote", "reliable")
func _request_gather(node_name: String, seq: int) -> void:
	if _retired or not multiplayer.is_server() or multiplayer.get_remote_sender_id() != owner_peer():
		return
	_stop_silently()  # a coleta anterior acabou a pedido do dono: não avisar de volta
	_gather_seq = seq
	var node := _sibling_resource_node(node_name)
	if node == null or not _body.is_alive() or not _body.gatherer.try_gather(node, GATHER_SLACK):
		_gather_stopped.rpc_id(owner_peer(), seq)


@rpc("any_peer", "call_remote", "reliable")
func _stop_gather(seq: int) -> void:
	if not _retired and multiplayer.is_server() and multiplayer.get_remote_sender_id() == owner_peer() \
			and seq == _gather_seq:
		_stop_silently()


func _stop_silently() -> void:
	_stopping_on_request = true
	_body.gatherer.stop()
	_stopping_on_request = false


## Host → dono: a coleta acabou no host (recusada, esgotou, apanhou...).
@rpc("authority", "call_remote", "reliable")
func _gather_stopped(seq: int) -> void:
	if seq == _gather_seq:
		_body.gatherer.stop()


## Ponto de coleta irmão do corpo, pelo nome recebido da rede. Só nomes simples (sem "/",
## "..", ":" etc.): o cliente não pode apontar para outro lugar da árvore.
func _sibling_resource_node(node_name: String) -> ResourceNode:
	if node_name.is_empty() or node_name.validate_node_name() != node_name \
			or node_name.contains(".."):
		return null
	return _body.get_parent().get_node_or_null(NodePath(node_name)) as ResourceNode


# --- Vida, decidida pelo host ----------------------------------------------------------------

func _on_damaged(info: DamageInfo) -> void:
	_send_to_clients(&"_damaged", [info.amount, info.direction, info.knockback], true)


func _on_health_changed(current: int, _maximum: int) -> void:
	_send_to_clients(&"_health", [current], true)


func _on_healed(amount: int) -> void:
	_send_to_clients(&"_healed", [amount], true)


func _on_blocked() -> void:
	_send_to_clients(&"_blocked", [], true)


func _on_immunity_changed(immune: bool) -> void:
	_send_to_clients(&"_immunity", [immune], true)


func _on_revived() -> void:
	_snapshots.clear()
	_accepted_position = _body.position
	_send_to_clients(&"_revived", [_body.position], true)


@rpc("authority", "call_remote", "reliable")
func _damaged(amount: int, direction: Vector2, knockback: float) -> void:
	if amount < 0 or not is_finite(knockback):
		return
	_body.health.replicate_damage(DamageInfo.create(amount, NetRules.clean_direction(direction),
		clampf(knockback, 0.0, NetRules.MAX_COORDINATE), 0, 0))


@rpc("authority", "call_remote", "reliable")
func _health(current: int) -> void:
	_body.health.replicate_current(current)


@rpc("authority", "call_remote", "reliable")
func _healed(amount: int) -> void:
	if amount > 0 and amount <= _body.health.max_health:
		_body.health.replicate_healed(amount)


@rpc("authority", "call_remote", "reliable")
func _blocked() -> void:
	_body.health.replicate_blocked()


@rpc("authority", "call_remote", "reliable")
func _immunity(immune: bool) -> void:
	_body.health.set_immune(immune)


@rpc("authority", "call_remote", "reliable")
func _revived(at: Vector2) -> void:
	if NetRules.is_valid_vector(at):
		_body.revive(at)


## Host → dono: posição recusada; volta para a última aceita.
@rpc("authority", "call_remote", "reliable")
func _correct(position: Vector2) -> void:
	if NetRules.is_valid_vector(position):
		_teleport(position)
		_body.ground_velocity = Vector2.ZERO


## Cliente que acabou de receber esta entidade pede o estado atual (ex.: entrou com a
## partida em andamento). Atendido uma vez por computador.
@rpc("any_peer", "call_remote", "reliable")
func _request_full_state() -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not _broadcast.add_peer(peer):
		return
	_full_state.rpc_id(peer, _body.position, _body.health.current, _body.health.is_immune())


@rpc("authority", "call_remote", "reliable")
func _full_state(position: Vector2, current: int, immune: bool) -> void:
	if not is_simulating() and NetRules.is_valid_vector(position):
		_teleport(position)
	_body.health.replicate_current(current)
	_body.health.set_immune(immune)
