class_name PlayerStateSync
extends Node
## Estado de cada jogador que só o host decide: inventário (com a mão) e experiência de
## coleta (ADR-012). Host: envia ao dono cada espaço que mudou, a mão, cada ganho (para os
## avisos) e a experiência. Dono: pede ao host para mexer no inventário (clicar num espaço,
## dividir, jogar fora o que está na mão, devolver a mão, fabricar, colocar uma estrutura); o
## host confere e aplica. Offline, os pedidos são aplicados na hora.
##
## Segurança (ADR-013): pedidos só mexem no inventário de quem pediu; índices, ids e
## quantidades vindos da rede são conferidos.

## Distâncias (chão) do item jogado fora até os pés do jogador, e folga exigida no ponto.
const DROP_DISTANCE := Vector2(8.0, 18.0)
const DROP_CLEARANCE := 4.0

var session: GameSession
var items: ItemDatabase
var skills: DataCatalog
var recipes: RecipeDatabase
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
	inventory.slot_changed.connect(_send_slot.bind(player_id, inventory))
	inventory.held_changed.connect(_send_held.bind(player_id, inventory))
	inventory.added.connect(func(item_id: StringName, amount: int) -> void:
		_send(player_id, &"_added", [item_id, amount]))
	session.get_skills(player_id).changed.connect(func(skill_id: StringName, xp: int) -> void:
		_send(player_id, &"_skill_xp", [skill_id, xp]))


## Cliente: pede ao host o estado completo do próprio jogador (espaços, mão e experiência).
## Chamado quando o personagem local chega: mensagens anteriores podem ter chegado antes de o
## jogador existir aqui.
func request_full_state() -> void:
	if NetRules.is_online(multiplayer) and not multiplayer.is_server():
		_full_state_requested.rpc_id(1)


## Jogador local clicou num espaço (pegar, pôr, juntar ou trocar com a mão).
func request_click(index: int) -> void:
	_request(&"_click_requested", [index])


## Jogador local quer pegar `amount` da pilha de `index` (dividir).
func request_split(index: int, amount: int) -> void:
	_request(&"_split_requested", [index, amount])


## Jogador local quer jogar no chão o que está na mão (só ele vê o item).
func request_drop_held() -> void:
	_request(&"_drop_held_requested", [])


## Jogador local fechou o inventário com algo na mão: volta para os espaços.
func request_return_held() -> void:
	_request(&"_return_held_requested", [])


## Jogador local quer fazer a receita `recipe_id` uma vez.
func request_craft(recipe_id: StringName) -> void:
	_request(&"_craft_requested", [recipe_id])


## Jogador local quer colocar no chão, em `at`, a estrutura que está na mão.
func request_place(at: Vector2) -> void:
	_request(&"_place_requested", [at])


## Lugares de fabricação ao alcance do jogador: a mão e as estações perto dos pés dele.
func stations_of(player_id: int) -> Array[RecipeData.Station]:
	var stations: Array[RecipeData.Station] = [RecipeData.Station.HAND]
	var character := session.get_player_entity(player_id) as Character
	if character == null:
		return stations
	for node in get_tree().get_nodes_in_group(Structure.STATION_GROUP):
		var structure := node as Structure
		# Mesmo mundo: nos testes, host e cliente dividem a mesma árvore.
		if structure.get_world_2d() == character.get_world_2d() \
				and structure.reaches(character.position) and structure.data.station not in stations:
			stations.append(structure.data.station)
	return stations


func _request(method: StringName, args: Array) -> void:
	if multiplayer.is_server():
		callv(method, args)  # host (ou offline): aplica direto
	else:
		callv(&"rpc_id", [1, method] + args)


func _send(player_id: int, method: StringName, args: Array) -> void:
	if player_id in multiplayer.get_peers():
		callv(&"rpc_id", [player_id, method] + args)


func _send_slot(index: int, player_id: int, inventory: Inventory) -> void:
	_send(player_id, &"_slot", [index, inventory.slot_item(index), inventory.slot_amount(index)])


func _send_held(player_id: int, inventory: Inventory) -> void:
	_send(player_id, &"_held", [inventory.held_item(), inventory.held_amount()])


## Host: inventário de quem pediu (o próprio host, numa chamada local, ou o cliente remetente).
func _requester_inventory() -> Inventory:
	if not multiplayer.is_server():
		return null
	return session.get_inventory(_requester())


func _requester() -> int:
	var sender := multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()


@rpc("any_peer", "call_remote", "reliable")
func _click_requested(index: int) -> void:
	var inventory := _requester_inventory()
	if inventory:
		inventory.click_slot(index)  # confere o índice


@rpc("any_peer", "call_remote", "reliable")
func _split_requested(index: int, amount: int) -> void:
	var inventory := _requester_inventory()
	if inventory:
		inventory.split_to_hand(index, amount)  # confere índice, quantidade e mão vazia


@rpc("any_peer", "call_remote", "reliable")
func _return_held_requested() -> void:
	var inventory := _requester_inventory()
	if inventory and inventory.return_held() > 0:
		_drop_held_requested()  # não coube de volta: cai no chão em vez de sumir


@rpc("any_peer", "call_remote", "reliable")
func _drop_held_requested() -> void:
	var inventory := _requester_inventory()
	var player_id := _requester()
	var character := session.get_player_entity(player_id) as Character
	if inventory == null or character == null or not inventory.is_holding():
		return
	var content := inventory.take_held()
	var space := character.get_world_2d().direct_space_state
	var spot := GroundQuery.find_drop_spot(space, character.position, _rng, DROP_DISTANCE.x,
		DROP_DISTANCE.y, DROP_CLEARANCE)
	spawner.spawn_pickup(items.get_item(content[0]), content[1], player_id, character.position,
		spot, true)


@rpc("any_peer", "call_remote", "reliable")
func _craft_requested(recipe_id: StringName) -> void:
	var inventory := _requester_inventory()
	var recipe := recipes.get_recipe(recipe_id) if recipes else null  # id desconhecido: nada
	if inventory and recipe:
		# Confere de novo lugar, ingredientes e espaço: o pedido pode ser velho ou forjado.
		CraftingRules.craft(recipe, inventory, stations_of(_requester()))


@rpc("any_peer", "call_remote", "reliable")
func _place_requested(at: Vector2) -> void:
	var inventory := _requester_inventory()
	var character := session.get_player_entity(_requester()) as Character
	if inventory == null or character == null or not character.is_alive() \
			or not NetRules.is_valid_vector(at):
		return
	# O que é colocado é o que o HOST sabe estar na mão, nunca algo dito pelo cliente.
	var placeable := items.get_item(inventory.held_item()) as PlaceableData
	var space := character.get_world_2d().direct_space_state
	if placeable and PlacementRules.can_place(space, placeable.structure, character.position, at) \
			and inventory.use_held(1):
		spawner.spawn_structure(placeable.structure, at)


@rpc("any_peer", "call_remote", "reliable")
func _full_state_requested() -> void:
	var player_id := multiplayer.get_remote_sender_id()
	var inventory := session.get_inventory(player_id) if multiplayer.is_server() else null
	if inventory == null:
		return
	for index in inventory.capacity():
		_send_slot(index, player_id, inventory)
	_send_held(player_id, inventory)
	var progress := session.get_skills(player_id)
	for skill in skills.entries():
		_send(player_id, &"_skill_xp", [skill.id, progress.xp(skill.id)])


@rpc("authority", "call_remote", "reliable")
func _slot(index: int, item_id: StringName, amount: int) -> void:
	var inventory := _local_inventory()
	if inventory and inventory.is_valid_slot(index) and _is_valid_stack(inventory, item_id, amount):
		inventory.replicate_slot(index, item_id, amount)


@rpc("authority", "call_remote", "reliable")
func _held(item_id: StringName, amount: int) -> void:
	var inventory := _local_inventory()
	if inventory and _is_valid_stack(inventory, item_id, amount):
		inventory.replicate_held(item_id, amount)


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


## Pilha vinda da rede: vazia, ou item conhecido em quantidade dentro do limite dele.
func _is_valid_stack(inventory: Inventory, item_id: StringName, amount: int) -> bool:
	if item_id == Inventory.EMPTY:
		return true
	return items.has(item_id) and amount > 0 and amount <= inventory.stack_limit(item_id)


func _local_inventory() -> Inventory:
	return session.get_inventory(multiplayer.get_unique_id())
