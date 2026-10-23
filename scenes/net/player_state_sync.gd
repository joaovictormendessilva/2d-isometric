class_name PlayerStateSync
extends Node
## Estado de cada jogador que só o host decide: inventário (com a mão), equipamento,
## experiência de coleta e moedas (ADR-012). Host: envia ao dono cada espaço do inventário que
## mudou, a mão, cada ganho (para os avisos), a experiência e as moedas; e o equipamento de cada
## jogador a todos. Dono: pede ao host para mexer no inventário (clicar num espaço,
## dividir, soltar um espaço, jogar fora o que está na mão, devolver a mão, fabricar, colocar uma
## estrutura, vestir e tirar equipamento, comprar e vender com um NPC, usar um item como a poção);
## o host confere e aplica. Esperas (poções) começadas no host também vão ao dono.
## Offline, os pedidos são aplicados na hora.
##
## Segurança (ADR-013): pedidos só mexem no inventário de quem pediu; índices, ids e
## quantidades vindos da rede são conferidos.

## O jogador local tentou usar um item e não dá (vida cheia, esperando...): só o aviso, nada
## foi pedido ao host.
signal use_refused(reason: ConsumableRules.Check)

## Distâncias (chão) do item jogado fora até os pés do jogador, e folga exigida no ponto.
const DROP_DISTANCE := Vector2(8.0, 18.0)
const DROP_CLEARANCE := 4.0

var session: GameSession
var items: ItemDatabase
var skills: DataCatalog
var recipes: RecipeDatabase
var spawner: EntitySpawner

var _rng := RandomNumberGenerator.new()
## Host: inventário de cada jogador já ligado aos envios (ver `track_player`).
var _tracked: Dictionary[int, Inventory] = {}


func _ready() -> void:
	_rng.randomize()


## Host: passa a enviar o estado do jogador: equipamento a TODOS (define o golpe, que todos
## animam, e um dia a aparência); inventário e experiência só ao dono (se for um cliente).
func track_player(player_id: int) -> void:
	if not NetRules.is_online(multiplayer) or not multiplayer.is_server():
		return
	# Uma vez por jogador na sessão: o personagem é recriado a cada viagem, o inventário não.
	var inventory := session.get_inventory(player_id)
	if _tracked.get(player_id) == inventory:
		return
	_tracked[player_id] = inventory
	session.get_equipment(player_id).slot_changed.connect(
		_broadcast_equipment.bind(player_id).unbind(1))
	if player_id == multiplayer.get_unique_id():
		return
	inventory.slot_changed.connect(_send_slot.bind(player_id, inventory))
	inventory.held_changed.connect(_send_held.bind(player_id, inventory))
	inventory.added.connect(func(item_id: StringName, amount: int) -> void:
		_send(player_id, &"_added", [item_id, amount]))
	session.get_skills(player_id).changed.connect(func(skill_id: StringName, xp: int) -> void:
		_send(player_id, &"_skill_xp", [skill_id, xp]))
	var wallet := session.get_wallet(player_id)
	wallet.changed.connect(func(coins: int) -> void: _send(player_id, &"_coins", [coins]))
	wallet.earned.connect(func(amount: int) -> void: _send(player_id, &"_earned", [amount]))
	session.get_cooldowns(player_id).started.connect(func(group: StringName, seconds: float) -> void:
		_send(player_id, &"_cooldown", [group, seconds]))


## Cliente: um jogador (qualquer um) apareceu aqui; pede ao host o equipamento dele. Assim não
## importa se avisos de equipamento chegaram antes de o personagem existir neste computador.
func request_equipment_of(player_id: int) -> void:
	if NetRules.is_online(multiplayer) and not multiplayer.is_server():
		_equipment_requested.rpc_id(1, player_id)


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


## Jogador local quer soltar no chão a pilha inteira do espaço `index` (menu do botão direito).
func request_drop_slot(index: int) -> void:
	_request(&"_drop_slot_requested", [index])


## Jogador local fechou o inventário com algo na mão: volta para os espaços.
func request_return_held() -> void:
	_request(&"_return_held_requested", [])


## Jogador local quer vestir o item do espaço `index` do inventário (menu "Equipar").
func request_equip(index: int) -> void:
	_request(&"_equip_requested", [index])


## Jogador local clicou no espaço de equipamento `index` (vestir o que está na mão, ou tirar).
func request_click_equipment(index: int) -> void:
	_request(&"_click_equipment_requested", [index])


## Jogador local quer fazer a receita `recipe_id` uma vez.
func request_craft(recipe_id: StringName) -> void:
	_request(&"_craft_requested", [recipe_id])


## Jogador local quer colocar no chão, em `at`, a estrutura que está na mão.
func request_place(at: Vector2) -> void:
	_request(&"_place_requested", [at])


## Jogador local quer comprar uma unidade de `item_id` do NPC perto dele.
func request_buy(item_id: StringName) -> void:
	_request(&"_buy_requested", [item_id])


## Jogador local quer vender `amount` da pilha do espaço `index` ao NPC perto dele.
func request_sell(index: int, amount: int) -> void:
	_request(&"_sell_requested", [index, amount])


## Jogador local quer usar o item do espaço `index` (menu "Usar"). Se já se sabe que não dá,
## avisa (`use_refused`) em vez de pedir.
func request_use(index: int) -> void:
	var reason := check_use(multiplayer.get_unique_id(), index)
	if reason == ConsumableRules.Check.OK:
		_request(&"_use_requested", [index])
	else:
		use_refused.emit(reason)


## Jogador local apertou a tecla de poção: o host escolhe a poção (ver `ConsumableRules`).
func request_quick_heal() -> void:
	var reason := check_use(multiplayer.get_unique_id(), -1)
	if reason == ConsumableRules.Check.OK:
		_request(&"_quick_heal_requested", [])
	else:
		use_refused.emit(reason)


## Se o jogador pode usar o item do espaço `index` (-1 = a poção que a tecla escolheria), com o
## estado que este computador conhece (no host, o oficial).
func check_use(player_id: int, index: int) -> ConsumableRules.Check:
	var inventory := session.get_inventory(player_id)
	var character := session.get_player_entity(player_id) as Character
	if inventory == null or character == null:
		return ConsumableRules.Check.NOT_USABLE
	var health := character.health
	var cooldowns := session.get_cooldowns(player_id)
	if index < 0:
		return ConsumableRules.check_quick_heal(inventory, items, health.current,
			health.max_health, cooldowns, NetRules.now())
	return ConsumableRules.check_use(inventory, index, items, health.current, health.max_health,
		cooldowns, NetRules.now())


## Lugares de fabricação ao alcance do jogador: a mão e as estações perto dos pés dele.
func stations_of(player_id: int) -> Array[RecipeData.Station]:
	var stations: Array[RecipeData.Station] = [RecipeData.Station.HAND]
	for node in _in_reach(Structure.STATION_GROUP, player_id):
		var structure := node as Structure
		if structure.data.station not in stations:
			stations.append(structure.data.station)
	return stations


## NPC mais próximo ao alcance do jogador (para negociar), ou null.
func npc_near(player_id: int) -> Npc:
	var character := session.get_player_entity(player_id) as Character
	var best: Npc
	for node in _in_reach(Npc.GROUP, player_id):
		if best == null or Iso.ground_distance(node.position, character.position) \
				< Iso.ground_distance(best.position, character.position):
			best = node
	return best


## Nós do grupo (com `reaches(pés)`) ao alcance do jogador vivo, no mundo dele.
func _in_reach(group: StringName, player_id: int) -> Array[Node2D]:
	var found: Array[Node2D] = []
	var character := session.get_player_entity(player_id) as Character
	if character == null or not character.is_alive():
		return found
	for node: Node2D in get_tree().get_nodes_in_group(group):
		# Mesmo mundo: nos testes, host e cliente dividem a mesma árvore.
		if node.get_world_2d() == character.get_world_2d() and node.reaches(character.position):
			found.append(node)
	return found


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


## Host: o equipamento inteiro de `player_id` para todos os clientes (uma mensagem só).
func _broadcast_equipment(player_id: int) -> void:
	for peer in multiplayer.get_peers():
		_send_equipment(peer, player_id)


func _send_equipment(peer: int, player_id: int) -> void:
	var equipment := session.get_equipment(player_id)
	var ids := PackedStringArray()
	for index in equipment.size():
		ids.append(equipment.item_id(index))
	_send(peer, &"_equipment", [player_id, ids])


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
func _equip_requested(index: int) -> void:
	var inventory := _requester_inventory()
	if inventory:  # confere índice, mão vazia, tipo do item e regras de mão
		EquipmentRules.equip_from_inventory(inventory, session.get_equipment(_requester()), index)


@rpc("any_peer", "call_remote", "reliable")
func _click_equipment_requested(index: int) -> void:
	var inventory := _requester_inventory()
	if inventory:  # confere índice e se o item da mão cabe no espaço
		EquipmentRules.click_slot(inventory, session.get_equipment(_requester()), index)


## Soltar um espaço = pegar a pilha e jogar fora o que está na mão, de uma vez no host.
@rpc("any_peer", "call_remote", "reliable")
func _drop_slot_requested(index: int) -> void:
	var inventory := _requester_inventory()
	if inventory == null or session.get_player_entity(_requester()) == null \
			or inventory.is_holding() or not inventory.is_valid_slot(index) \
			or inventory.slot_amount(index) == 0:
		return
	inventory.click_slot(index)
	_drop_held_requested()


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
	spawner.spawn_pickup(Region.of(character), items.get_item(content[0]), content[1], player_id,
		character.position, spot, true)


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
		spawner.spawn_structure(Region.of(character), placeable.structure, at)


## O NPC é o que o HOST sabe estar perto do jogador; o preço é o dos dados dele, nunca um valor
## dito pelo cliente.
@rpc("any_peer", "call_remote", "reliable")
func _buy_requested(item_id: StringName) -> void:
	var inventory := _requester_inventory()
	var npc := npc_near(_requester()) if inventory else null
	if npc:  # confere item à venda, moedas e espaço
		TradeRules.buy(npc.data, item_id, inventory, session.get_wallet(_requester()))


@rpc("any_peer", "call_remote", "reliable")
func _sell_requested(index: int, amount: int) -> void:
	var inventory := _requester_inventory()
	var npc := npc_near(_requester()) if inventory else null
	if npc:  # confere índice, quantidade, item que o NPC compra e teto da carteira
		TradeRules.sell(npc.data, inventory, index, amount, session.get_wallet(_requester()), items)


@rpc("any_peer", "call_remote", "reliable")
func _use_requested(index: int) -> void:
	if _requester_inventory():
		_use_slot(_requester(), index)


@rpc("any_peer", "call_remote", "reliable")
func _quick_heal_requested() -> void:
	var inventory := _requester_inventory()
	if inventory:
		_use_slot(_requester(), ConsumableRules.healing_slot(inventory, items))


## Host: confere tudo de novo com o estado oficial (índice, item, vida, espera) e aplica.
func _use_slot(player_id: int, index: int) -> void:
	var character := session.get_player_entity(player_id) as Character
	if character == null:
		return
	var health := character.health
	var heal := ConsumableRules.use(session.get_inventory(player_id), index, items, health.current,
		health.max_health, session.get_cooldowns(player_id), NetRules.now())
	if heal > 0:
		health.heal(heal)


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
	_send(player_id, &"_coins", [session.get_wallet(player_id).coins()])


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


@rpc("authority", "call_remote", "reliable")
func _coins(coins: int) -> void:
	var wallet := session.get_wallet(multiplayer.get_unique_id())
	if wallet and coins >= 0 and coins <= Wallet.MAX_COINS:
		wallet.replicate(coins)


@rpc("authority", "call_remote", "reliable")
func _earned(amount: int) -> void:
	var wallet := session.get_wallet(multiplayer.get_unique_id())
	if wallet and amount > 0 and amount <= Wallet.MAX_COINS:
		wallet.notify_earned(amount)


## Espera começada no host (o cliente conta no próprio relógio; chega um pouco depois, então
## nunca libera antes do host).
@rpc("authority", "call_remote", "reliable")
func _cooldown(group: StringName, seconds: float) -> void:
	var cooldowns := session.get_cooldowns(multiplayer.get_unique_id())
	if cooldowns and is_finite(seconds) and seconds > 0.0 and seconds <= Cooldowns.MAX_SECONDS \
			and items.has_cooldown_group(group):
		cooldowns.start(group, seconds, NetRules.now())


## Host: alguém pediu o equipamento de um jogador (público no coop). Uma resposta por pedido.
@rpc("any_peer", "call_remote", "reliable")
func _equipment_requested(player_id: int) -> void:
	if multiplayer.is_server() and session.get_equipment(player_id) != null:
		_send_equipment(multiplayer.get_remote_sender_id(), player_id)


## Equipamento de um jogador vindo do host: tudo ou nada — mesmo número de espaços, e cada um
## vazio ou com um equipamento conhecido do tipo do espaço.
@rpc("authority", "call_remote", "reliable")
func _equipment(player_id: int, ids: PackedStringArray) -> void:
	var equipment := session.get_equipment(player_id)
	if equipment == null or ids.size() != equipment.size():
		return
	for index in ids.size():
		var item := equipment.data_of(ids[index])
		if ids[index] != Equipment.EMPTY \
				and (item == null or item.get_slot() != equipment.slot_type(index)):
			return
	for index in ids.size():
		equipment.replicate_slot(index, StringName(ids[index]))


## Pilha vinda da rede: vazia, ou item conhecido em quantidade dentro do limite dele.
func _is_valid_stack(inventory: Inventory, item_id: StringName, amount: int) -> bool:
	if item_id == Inventory.EMPTY:
		return true
	return items.has(item_id) and amount > 0 and amount <= inventory.stack_limit(item_id)


func _local_inventory() -> Inventory:
	return session.get_inventory(multiplayer.get_unique_id())
