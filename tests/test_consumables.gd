extends TestCase
## Poção de vida (F3b): usar um consumível gasta uma unidade e cura, com espera entre poções;
## tudo ou nada; o host decide (o cliente só pede) e a cura chega a todos.

const PORT := 24730
const POTION := &"health_potion"


func test_potion_data_is_consistent() -> void:
	var items := ItemDatabase.load_all()
	var potion := items.get_item(POTION) as ConsumableData
	check(potion != null and potion.heal > 0 and potion.cooldown > 0.0, "poção cura e tem espera")
	check(potion != null and potion.icon != null, "poção tem ícone")
	for entry in items.entries():
		var consumable := entry as ConsumableData
		if consumable:
			check(consumable.heal >= 0 and consumable.cooldown >= 0.0
				and consumable.cooldown <= Cooldowns.MAX_SECONDS,
				"%s: cura e espera dentro dos limites" % consumable.id)
			check(items.has_cooldown_group(consumable.cooldown_group), "%s: grupo conhecido" % consumable.id)
	var merchant := DataCatalog.new("res://data/npcs/").get_entry(&"merchant") as NpcData
	check(merchant.sells(POTION), "o mercador vende poção")


func test_use_heals_spends_one_and_starts_cooldown() -> void:
	var items := ItemDatabase.load_all()
	var potion := items.get_item(POTION) as ConsumableData
	var inventory := Inventory.new(4, items)
	var cooldowns := Cooldowns.new()
	inventory.add(&"gel", 1)
	inventory.add(POTION, 3)
	check(ConsumableRules.healing_slot(inventory, items) == 1, "a tecla acha a poção, não a gosma")
	check(ConsumableRules.use(inventory, 1, items, 30, 100, cooldowns, 5.0) == potion.heal, "curou")
	check(inventory.count(POTION) == 2, "gastou uma")
	check_near(cooldowns.remaining(potion.cooldown_group, 5.0), potion.cooldown, 0.001, "espera começou")
	check(ConsumableRules.check_use(inventory, 1, items, 30, 100, cooldowns, 6.0)
		== ConsumableRules.Check.COOLING_DOWN, "esperando: recusa")
	check(ConsumableRules.use(inventory, 1, items, 30, 100, cooldowns, 6.0) == -1
		and inventory.count(POTION) == 2, "recusa não gasta")
	var later := 5.0 + potion.cooldown
	check(ConsumableRules.check_use(inventory, 1, items, 30, 100, cooldowns, later)
		== ConsumableRules.Check.OK, "depois da espera, pode de novo")


func test_refusals_change_nothing() -> void:
	var items := ItemDatabase.load_all()
	var inventory := Inventory.new(4, items)
	var cooldowns := Cooldowns.new()
	check(ConsumableRules.check_quick_heal(inventory, items, 30, 100, cooldowns, 0.0)
		== ConsumableRules.Check.NO_POTION, "sem poções")
	inventory.add(&"gel", 1)
	inventory.add(POTION, 1)
	var cases := [
		[0, 30, ConsumableRules.Check.NOT_USABLE, "gosma não se usa"],
		[2, 30, ConsumableRules.Check.NOT_USABLE, "espaço vazio"],
		[-1, 30, ConsumableRules.Check.NOT_USABLE, "índice negativo"],
		[99, 30, ConsumableRules.Check.NOT_USABLE, "índice fora"],
		[1, 100, ConsumableRules.Check.FULL_HEALTH, "vida cheia não desperdiça"],
		[1, 0, ConsumableRules.Check.DEAD, "morto não bebe"],
	]
	for entry: Array in cases:
		check(ConsumableRules.check_use(inventory, entry[0], items, entry[1], 100, cooldowns, 0.0)
			== entry[2], entry[3])
		check(ConsumableRules.use(inventory, entry[0], items, entry[1], 100, cooldowns, 0.0) == -1,
			"%s: não usa" % entry[3])
	check(inventory.count(POTION) == 1 and inventory.count(&"gel") == 1, "nada foi gasto")
	check(cooldowns.is_ready(&"potion", 0.0), "nenhuma espera começou")


func test_heal_is_capped_and_needs_life() -> void:
	var character := spawn_character(Vector2(100, 100))
	var health := character.health
	var healed := []
	health.healed.connect(healed.append)
	health.set_current(90)
	check(health.heal(40) == 10 and health.current == health.max_health, "não passa do máximo")
	check(health.heal(40) == 0, "cheia: nada")
	check(healed == [10], "aviso só com a cura de fato")
	health.replicate_current(0)
	check(health.heal(40) == 0 and health.current == 0, "morto não cura")


## Jogo sozinho: a tecla de poção bebe pelo PlayerStateSync; vida cheia avisa sem gastar.
func test_quick_heal_in_game() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var player_id: int = game.local_player_id()
	var state: PlayerStateSync = game.player_state
	var inventory := session.get_inventory(player_id)
	var health := (session.get_player_entity(player_id) as Character).health
	var refusals := []
	state.use_refused.connect(refusals.append)
	state.request_quick_heal()
	check(refusals == [ConsumableRules.Check.NO_POTION], "sem poções: avisa")
	inventory.add(POTION, 2)
	state.request_quick_heal()
	check(refusals.back() == ConsumableRules.Check.FULL_HEALTH and inventory.count(POTION) == 2,
		"vida cheia: avisa e não gasta")
	health.set_current(20)
	state.request_quick_heal()
	check(health.current == 60 and inventory.count(POTION) == 1, "bebeu uma e curou 40")
	state.request_use(slot_of(inventory, POTION))
	check(refusals.back() == ConsumableRules.Check.COOLING_DOWN and inventory.count(POTION) == 1,
		"pelo menu, durante a espera: avisa e não gasta")
	inventory.add(POTION, 2)
	var slot: PotionSlot = game.find_children("*", "PotionSlot", true, false)[0]
	check(slot._wait.text != "" and slot._view._amount.text == "", "o HUD mostra a espera")
	var cooldowns := session.get_cooldowns(player_id)
	await wait_until(func() -> bool: return cooldowns.is_ready(&"potion", NetRules.now()), 900)
	await physics_frames(2)
	check(slot._wait.text == "" and slot._view._amount.text == "3", "passou a espera: 3 poções")


## Coop: o cliente pede; o host confere com o estado dele (índice, vida, espera) e cura. A vida,
## o aviso da cura e a espera chegam ao cliente.
func test_client_heals_through_host() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(connected, "cliente conectou")
	calm_monsters(host)
	await physics_frames(10)
	var client_id: int = client.local_player_id()
	var host_session := host.session as GameSession
	var client_session := client.session as GameSession
	var on_host := host_session.get_inventory(client_id)
	var host_health := (host_session.get_player_entity(client_id) as Character).health
	var client_health := (client_session.get_player_entity(client_id) as Character).health
	var healed := []
	client_health.healed.connect(healed.append)
	on_host.add(&"gel", 1)
	on_host.add(POTION, 2)
	host_health.set_current(30)
	var state: PlayerStateSync = client.player_state
	check(await wait_until(func() -> bool:
		return client_health.current == 30 \
			and client_session.get_inventory(client_id).count(POTION) == 2, 30),
		"vida e poções chegam ao cliente")

	# Pedidos forjados (sem passar pela conferência local): o host recusa.
	for index in [0, -1, 99]:
		state._request(&"_use_requested", [index])
	await physics_frames(10)
	check(host_health.current == 30 and on_host.count(POTION) == 2, "índices inválidos: nada")

	state.request_quick_heal()
	check(await wait_until(func() -> bool: return client_health.current == 70, 30),
		"curou pelo host e a vida chegou")
	check(host_health.current == 70 and on_host.count(POTION) == 1, "host gastou uma")
	check(healed == [40], "o cliente viu a cura")
	var cooldowns := client_session.get_cooldowns(client_id)
	check(await wait_until(func() -> bool: return not cooldowns.is_ready(&"potion", NetRules.now()), 30),
		"a espera chegou ao cliente")
	state._request(&"_quick_heal_requested", [])  # forjado, durante a espera
	await physics_frames(10)
	check(host_health.current == 70 and on_host.count(POTION) == 1, "durante a espera o host recusa")
