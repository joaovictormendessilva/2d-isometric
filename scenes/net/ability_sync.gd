class_name AbilitySync
extends HostRequests
## Habilidades de cada jogador, decididas pelo host (ADR-026). O dono pede para lançar a habilidade
## de um espaço (com a mira: direção e distância até o ponto mirado) ou trocar espaços; o host
## confere com o livro e a recarga OFICIAIS dele e aplica. O dono mostra o lançamento na hora
## (previsão; o host avisa os outros pelo NetSync) e recebe do host o livro inteiro a cada
## mudança e cada recarga começada.
##
## Segurança (ADR-013): pedidos só mexem no livro de quem pediu; espaço, mira e ids vindos da
## rede são conferidos (a distância da mira só vale até o alcance da habilidade); o dano é sempre
## do projétil ou da área do host.

## O jogador local tentou lançar e não dá (recarga, tecla vazia...): só o aviso, nada foi pedido.
signal cast_refused(reason: AbilityRules.Check)
## Cliente: chegou a resposta ao `request_full_state`. É a última do estado do jogador local (o
## pedido sai depois do PlayerStateSync e as mensagens confiáveis chegam na ordem em que saíram).
signal full_state_received

var session: GameSession

## Host: livro de cada jogador já ligado aos envios (o personagem é recriado a cada viagem).
var _tracked: Dictionary[int, AbilityBook] = {}


## Host: passa a enviar ao dono (se for um cliente) o livro e as recargas dele.
func track_player(player_id: int) -> void:
	if not NetRules.is_online(multiplayer) or not multiplayer.is_server() \
			or player_id == multiplayer.get_unique_id():
		return
	var book := session.get_ability_book(player_id)
	if _tracked.get(player_id) == book:
		return
	_tracked[player_id] = book
	book.changed.connect(func() -> void: _send(player_id, &"_book", [book.snapshot()]))
	book.cooldowns.started.connect(func(ability_id: StringName, seconds: float) -> void:
		_send(player_id, &"_cooldown", [ability_id, seconds]))
	_send(player_id, &"_book", [book.snapshot()])


## Cliente: pede o livro ao host quando o personagem local chega (avisos anteriores podem ter
## chegado antes de o jogador existir aqui).
func request_full_state() -> void:
	if NetRules.is_online(multiplayer) and not multiplayer.is_server():
		_full_state_requested.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _full_state_requested() -> void:
	var player_id := multiplayer.get_remote_sender_id()
	var book := session.get_ability_book(player_id) if multiplayer.is_server() else null
	if book:
		_send(player_id, &"_full_book", [book.snapshot()])


## Jogador local apertou a tecla do espaço `index`, mirando em `aim` (até o ponto mirado, no chão).
func request_cast(player_id: int, index: int, aim: Vector2) -> void:
	var book := session.get_ability_book(player_id)
	var character := session.get_player_entity(player_id) as Character
	if book == null or character == null:
		return
	var now := NetRules.now()
	var reason := AbilityRules.check_cast(book, index, character.can_act(), now)
	if reason != AbilityRules.Check.OK:
		cast_refused.emit(reason)
		return
	if not multiplayer.is_server():
		# Previsão: lança e começa a recarga aqui na hora; o host confere e manda a oficial.
		character.request_cast(AbilityRules.cast(book, index, true, now), aim)
	_request(&"_cast_requested", [index, aim])


## Jogador local quer pôr a habilidade `ability_id` no espaço `index` ("" = esvaziar).
func request_set_slot(index: int, ability_id: StringName) -> void:
	_request(&"_set_slot_requested", [index, ability_id])


@rpc("any_peer", "call_remote", "reliable")
func _cast_requested(index: int, aim: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var player_id := _requester()
	var book := session.get_ability_book(player_id)
	var character := session.get_player_entity(player_id) as Character
	aim = NetRules.clean_aim(aim)
	if book == null or character == null or aim == Vector2.ZERO:
		return
	if player_id == multiplayer.get_unique_id():
		var ability := AbilityRules.cast(book, index, character.can_act(), NetRules.now())
		if ability:
			character.request_cast(ability, aim)
		return
	# Pedido de um cliente: o atordoamento pode diferir por milissegundos (como nos ataques);
	# vale estar vivo e sem outro lançamento.
	var free := character.is_alive() and not character.caster.is_casting()
	var cast := AbilityRules.cast(book, index, free, NetRules.now())
	if cast:
		character.play_remote_cast(cast, aim)


@rpc("any_peer", "call_remote", "reliable")
func _set_slot_requested(index: int, ability_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	var book := session.get_ability_book(_requester())
	if book:  # confere índice e se a habilidade foi aprendida
		book.set_slot(index, AbilityDatabase.shared().get_ability(ability_id))


## Livro do jogador local vindo do host (conferido contra o catálogo local).
@rpc("authority", "call_remote", "reliable")
func _book(state: Dictionary) -> void:
	var book := session.get_ability_book(multiplayer.get_unique_id())
	if book:
		book.replicate(state, AbilityDatabase.shared())


## O mesmo livro, em resposta ao `request_full_state`.
@rpc("authority", "call_remote", "reliable")
func _full_book(state: Dictionary) -> void:
	_book(state)
	full_state_received.emit()


@rpc("authority", "call_remote", "reliable")
func _cooldown(ability_id: StringName, seconds: float) -> void:
	var book := session.get_ability_book(multiplayer.get_unique_id())
	if book and AbilityDatabase.shared().has(ability_id) and is_finite(seconds) \
			and seconds > 0.0 and seconds <= Cooldowns.MAX_SECONDS:
		book.cooldowns.start(ability_id, seconds, NetRules.now())
