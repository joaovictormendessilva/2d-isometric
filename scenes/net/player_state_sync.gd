class_name PlayerStateSync
extends Node
## Estado de cada jogador que só o host decide: inventário e experiência de coleta (ADR-012).
## Host: envia ao dono cada espaço do inventário que mudou, cada ganho (para os avisos) e a
## experiência. Dono: pede ao host para mexer no inventário (mover, jogar fora); o host
## confere o pedido e aplica. Offline, os pedidos são aplicados na hora.
##
## Segurança (ADR-013): pedidos só mexem no inventário de quem pediu; índices, ids e
## quantidades vindos da rede são conferidos.

## Distâncias (chão) do item jogado fora até os pés do jogador, e folga exigida no ponto.
const DROP_DISTANCE := Vector2(8.0, 18.0)
const DROP_CLEARANCE := 4.0

var session: GameSession
var items: ItemDatabase
var skills: DataCatalog
var spawner: EntitySpawner

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Host: passa a enviar ao dono (se for um cliente) tudo o que mudar no estado dele.
func track_player(player_id: int) -> void:
	if not NetRules.is_online(multiplayer) or not multiplayer.is_server() \
			or player_id == multiplayer.get_unique_id():
		return
	var inventory := session.get_inventory(player_id)
	inventory.slot_changed.connect(func(index: int) -> void:
		_send(player_id, &"_slot", [index, inventory.slot_item(index), inventory.slot_amount(index)]))
	inventory.added.connect(func(item_id: StringName, amount: int) -> void:
		_send(player_id, &"_added", [item_id, amount]))
	session.get_skills(player_id).changed.connect(func(skill_id: StringName, xp: int) -> void:
		_send(player_id, &"_skill_xp", [skill_id, xp]))


## Jogador local quer mover o conteúdo de um espaço para outro.
func request_move(from: int, to: int) -> void:
	_request(&"_move_requested", [from, to])


## Jogador local quer jogar fora o conteúdo de um espaço (cai no chão, só ele vê).
func request_drop(index: int) -> void:
	_request(&"_drop_requested", [index])


func _request(method: StringName, args: Array) -> void:
	if multiplayer.is_server():
		callv(method, args)  # host (ou offline): aplica direto
	else:
		callv(&"rpc_id", [1, method] + args)


func _send(player_id: int, method: StringName, args: Array) -> void:
	if player_id in multiplayer.get_peers():
		callv(&"rpc_id", [player_id, method] + args)


## Quem pediu: o próprio host (chamada local) ou o cliente remetente.
func _requester() -> int:
	var sender := multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()


@rpc("any_peer", "call_remote", "reliable")
func _move_requested(from: int, to: int) -> void:
	var inventory := session.get_inventory(_requester()) if multiplayer.is_server() else null
	if inventory and inventory.is_valid_slot(from) and inventory.is_valid_slot(to):
		inventory.move(from, to)


@rpc("any_peer", "call_remote", "reliable")
func _drop_requested(index: int) -> void:
	if not multiplayer.is_server():
		return
	var player_id := _requester()
	var inventory := session.get_inventory(player_id)
	var character := session.get_player_entity(player_id) as Character
	if inventory == null or character == null or not character.is_alive() \
			or not inventory.is_valid_slot(index) or inventory.slot_item(index) == Inventory.EMPTY:
		return
	var content := inventory.take_slot(index)
	var space := character.get_world_2d().direct_space_state
	var spot := GroundQuery.find_drop_spot(space, character.position, _rng, DROP_DISTANCE.x,
		DROP_DISTANCE.y, DROP_CLEARANCE)
	spawner.spawn_pickup(items.get_item(content[0]), content[1], player_id, character.position, spot,
		true)


@rpc("authority", "call_remote", "reliable")
func _slot(index: int, item_id: StringName, amount: int) -> void:
	var inventory := _local_inventory()
	if inventory == null or not inventory.is_valid_slot(index):
		return
	var valid := item_id == Inventory.EMPTY or (items.has(item_id)
		and amount > 0 and amount <= inventory.stack_limit(item_id))
	if valid:
		inventory.replicate_slot(index, item_id, amount)


@rpc("authority", "call_remote", "reliable")
func _added(item_id: StringName, amount: int) -> void:
	var inventory := _local_inventory()
	if inventory and items.has(item_id) and amount > 0:
		inventory.notify_added(item_id, amount)


@rpc("authority", "call_remote", "reliable")
func _skill_xp(skill_id: StringName, xp: int) -> void:
	var progress := session.get_skills(multiplayer.get_unique_id())
	if progress != null and xp >= 0 and skills.has(skill_id):
		progress.replicate_xp(skill_id, xp)


func _local_inventory() -> Inventory:
	return session.get_inventory(multiplayer.get_unique_id())
