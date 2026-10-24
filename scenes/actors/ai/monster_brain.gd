class_name MonsterBrain
extends Node
## IA simples e reutilizável: percebe jogadores dentro do raio de agressão, persegue quem tem
## mais ameaça (ThreatTable: quem fere, de qualquer distância, vira alvo), ataca quando no
## alcance e só desiste ao passar da coleira (distância de casa).
## Ao desistir ("evadir"), volta até casa imune e sem perceber ninguém, e lá recupera a vida
## toda. Sem isso, ela oscila na borda da coleira ou vira alvo fácil enquanto foge.
## Sem alvo, passeia por pontos perto de casa (`MonsterData.wander_radius`), com pausas.
## Gera só INTENÇÕES para o Monster pai — igual a um jogador, mas automatizado.
## Criaturas com salto (SlamAttacker, chefes) saltam sobre alvos a meia distância, se o ponto
## de queda for chão livre; perto, usam o golpe comum.
## Filhotes de chefe (`leader`) não têm casa nem coleira: seguem o chefe e atacam o alvo dele
## (quem o chefe persegue, mesmo longe); se o chefe desiste ou morre, os filhotes somem.
## Sem busca de caminho por enquanto: as pegadas redondas deslizam em volta dos obstáculos.

## A escolha de alvo roda a 5 Hz (barato com muitas criaturas); o movimento, todo quadro.
const THINK_INTERVAL := 0.2
## Sem `engage_distance` no ataque: ataca quando a folga até o alvo for menor que esta fração do
## alcance.
const ATTACK_RANGE_FRACTION := 0.8
const HOME_TOLERANCE := 6.0
## Fração da velocidade ao voltar para casa sem ter desistido (perdeu o alvo: morreu, viajou) e
## do filhote seguindo o chefe.
const IDLE_RETURN_SPEED := 0.6
## Fração da velocidade ao passear: devagar, para ler como "à toa", não como perseguição.
const WANDER_SPEED := 0.35
## Pausa entre um passeio e outro (s), sorteada neste intervalo.
const WANDER_PAUSE_MIN := 1.5
const WANDER_PAUSE_MAX := 4.0
## Desiste de um ponto de passeio que não alcança (obstáculo no caminho) depois deste tempo (s).
const WANDER_GIVE_UP := 4.0
## Filhote sem alvo fica a esta distância (chão) do chefe, em vez de colar nele.
const LEADER_FOLLOW_DISTANCE := 30.0

var session: GameSession
## Chefe que invocou esta criatura (host; ver EntitySpawner). Null = criatura comum.
var leader: Monster

var _home := Vector2.ZERO
var _target: Character
var _threat := ThreatTable.new()
var _returning := false
var _think_left := 0.0
## Sem alvo: ponto para onde anda (tela), velocidade, tempo para desistir dele e pausa restante.
var _idle_point := Vector2.ZERO
var _idle_speed := WANDER_SPEED
var _idle_time_left := 0.0
var _pause_left := 0.0

@onready var _body: Monster = get_parent()


func _ready() -> void:
	process_physics_priority = -10  # decide antes da física do corpo
	_home = _body.position
	_idle_point = _home
	_think_left = randf() * THINK_INTERVAL  # espalha o custo entre quadros
	_pause_left = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)
	_body.health.damaged.connect(_on_damaged)


## Jogador que está perseguindo (null = nenhum). Filhotes atacam o alvo do chefe.
func target() -> Character:
	return _target if is_instance_valid(_target) else null


## Desistiu da perseguição e está voltando para casa (imune, ignora jogadores até chegar).
func is_returning() -> bool:
	return _returning


## Ameaça que o jogador tem contra esta criatura (0 = nenhuma).
func threat_of(player_id: int) -> float:
	return _threat.get_threat(player_id)


func _physics_process(delta: float) -> void:
	if not _body.is_alive() or session == null:
		return
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = THINK_INTERVAL
		_think()
	if _body.slammer and _body.slammer.is_slamming():
		return  # no ar ou se recuperando: o salto decide
	if _target == null:
		_idle(delta)
		return
	var to_target := Iso.screen_to_ground(_target.position - _body.position)
	if _try_slam(to_target):
		return
	var gap := to_target.length() - _target.footprint_radius() - _body.footprint_radius()
	if gap <= _engage_distance():
		_body.set_move_intent(Vector2.ZERO)
		_body.request_attack(to_target)
	else:
		_body.set_move_intent(to_target.normalized())


## Só no host (a IA dos clientes não tem sessão). Quem fere ganha ameaça e a criatura reage já,
## sem esperar a próxima escolha de alvo.
func _on_damaged(info: DamageInfo) -> void:
	if session == null or _returning or is_instance_valid(leader) or info.source_player_id <= 0:
		return
	_threat.add(info.source_player_id, info.amount)
	_think_left = 0.0


func _think() -> void:
	if is_instance_valid(leader) and leader.is_alive():
		_home = leader.position
		var leader_target := (leader.get_node("Brain") as MonsterBrain).target()
		_target = leader_target if leader_target else _nearest_in_aggro()
		return
	if not _returning and Iso.ground_distance(_body.position, _home) > _body.data.leash_radius:
		_returning = true
		_threat.clear()
		_body.health.set_immune(true)
	var had_target := _target != null
	_target = null if _returning else _pick_by_threat()
	if had_target and _target == null:
		_go_idle_to(_home, IDLE_RETURN_SPEED, INF)  # perdeu o alvo: volta para casa


## Atualiza a ameaça (some quem morreu ou saiu da região; ganha o mínimo quem chegou perto) e
## escolhe o alvo por ela.
func _pick_by_threat() -> Character:
	for player_id: int in _threat.player_ids():
		if _valid_player(player_id) == null:
			_threat.remove(player_id)
	for player_id in session.get_player_ids():
		var candidate := _valid_player(player_id)
		if candidate and Iso.ground_distance(_body.position, candidate.position) \
				<= _body.data.aggro_radius:
			_threat.notice(player_id)
	var current_id := _target.player_id if is_instance_valid(_target) else 0
	return _valid_player(_threat.pick(current_id))


## Salta no alvo se puder: salto pronto, alvo a meia distância e chão livre onde ele está.
func _try_slam(to_target: Vector2) -> bool:
	if _body.slammer == null or not _body.slammer.can_slam():
		return false
	var slam := _body.slammer.attack
	var distance := to_target.length()
	if distance < slam.min_distance or distance > slam.max_distance:
		return false
	var space := _body.get_world_2d().direct_space_state
	return GroundQuery.is_walkable(space, _target.position, _body.footprint_radius()) \
		and _body.request_slam(_target.position)


## Folga até o alvo para começar o golpe: a do ataque (investidas começam de longe) ou parte
## do alcance.
func _engage_distance() -> float:
	var attack := _body.data.attack
	return attack.engage_distance if attack.engage_distance > 0.0 \
		else attack.reach * ATTACK_RANGE_FRACTION


## Jogador vivo mais próximo dentro do raio de agressão (filhote sem alvo do chefe).
func _nearest_in_aggro() -> Character:
	var best: Character
	var best_distance := _body.data.aggro_radius
	for player_id in session.get_player_ids():
		var candidate := _valid_player(player_id)
		if candidate == null:
			continue
		var distance := Iso.ground_distance(_body.position, candidate.position)
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	return best


## Personagem do jogador, se estiver vivo e na mesma região (o host simula várias, cada uma no
## seu mundo); senão, null.
func _valid_player(player_id: int) -> Character:
	if player_id <= 0:
		return null
	var candidate := session.get_player_entity(player_id) as Character
	if candidate == null or not candidate.is_alive() or candidate.get_parent() != _body.get_parent():
		return null
	return candidate


## Sem alvo: voltando (imune) ou filhote, vai para casa; senão, passeia com pausas.
func _idle(delta: float) -> void:
	if _returning or is_instance_valid(leader):
		_return_home()
		return
	var to_point := Iso.screen_to_ground(_idle_point - _body.position)
	_idle_time_left -= delta
	if to_point.length() > HOME_TOLERANCE and _idle_time_left > 0.0:
		_body.set_move_intent(to_point.normalized() * _idle_speed)
		return
	_body.set_move_intent(Vector2.ZERO)
	_pause_left -= delta
	if _pause_left <= 0.0:
		_go_idle_to(_wander_point(), WANDER_SPEED, WANDER_GIVE_UP)


func _go_idle_to(point: Vector2, speed: float, give_up: float) -> void:
	_idle_point = point
	_idle_speed = speed
	_idle_time_left = give_up
	_pause_left = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)


## Ponto sorteado (uniforme no disco) a até `wander_radius` de casa, no chão.
func _wander_point() -> Vector2:
	var radius := _body.data.wander_radius * sqrt(randf())
	return _home + Iso.ground_to_screen(Vector2.from_angle(randf() * TAU) * radius)


## Voltando de vez (imune, a toda velocidade) ou filhote seguindo o chefe.
func _return_home() -> void:
	var to_home := Iso.screen_to_ground(_home - _body.position)
	var tolerance := LEADER_FOLLOW_DISTANCE if is_instance_valid(leader) else HOME_TOLERANCE
	if to_home.length() > tolerance:
		_body.set_move_intent(to_home.normalized() * (1.0 if _returning else IDLE_RETURN_SPEED))
		return
	_body.set_move_intent(Vector2.ZERO)
	if _returning:
		_returning = false
		_idle_point = _home
		_body.health.set_immune(false)
		_body.health.restore_full()
		_body.forget_mastery_damage()
