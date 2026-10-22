extends TestCase
## Inventário em espaços com pilhas: guardar, limite, mover, cheio.



func test_items_stack_up_to_their_limit() -> void:
	var inventory := Inventory.new(3, ItemDatabase.load_all())
	var limit := inventory.stack_limit(&"wood")
	check(inventory.add(&"wood", limit + 5) == 0, "tudo coube")
	check(inventory.slot_amount(0) == limit and inventory.slot_amount(1) == 5,
		"primeira pilha cheia (%d), resto na segunda" % limit)
	inventory.add(&"wood", 3)
	check(inventory.slot_amount(1) == 8 and inventory.slot_item(2) == Inventory.EMPTY,
		"completa a pilha existente antes de ocupar espaço novo")
	check(inventory.count(&"wood") == limit + 8, "contagem soma as pilhas")


func test_tools_do_not_stack() -> void:
	var inventory := Inventory.new(3, ItemDatabase.load_all())
	inventory.add(&"stone_axe", 2)
	check(inventory.slot_amount(0) == 1 and inventory.slot_amount(1) == 1, "um machado por espaço")


func test_full_inventory_returns_what_did_not_fit() -> void:
	var inventory := Inventory.new(2, ItemDatabase.load_all())
	var limit := inventory.stack_limit(&"stone")
	inventory.add(&"wood", 1)
	check(inventory.add(&"stone", limit + 7) == 7, "sobraram 7 pedras")
	check(not inventory.can_add(&"stone", 1) and inventory.can_add(&"wood", 1),
		"pedra não cabe mais; madeira ainda cabe na pilha dela")
	var both: Dictionary[StringName, int] = {&"wood": 1, &"copper_ore": 1}
	check(not inventory.can_add_all(both), "juntos não cabem (o minério não tem espaço)")


## Mão vazia: clicar pega a pilha. Mão cheia: espaço vazio recebe, mesmo item junta (o resto
## fica na mão), item diferente troca.
func test_click_picks_places_merges_and_swaps() -> void:
	var inventory := Inventory.new(4, ItemDatabase.load_all())
	var limit := inventory.stack_limit(&"wood")
	inventory.replicate_slot(0, &"wood", 5)
	inventory.replicate_slot(1, &"stone", 2)
	inventory.replicate_slot(2, &"wood", limit - 2)
	inventory.click_slot(0)
	check(inventory.held_item() == &"wood" and inventory.held_amount() == 5
		and inventory.slot_item(0) == Inventory.EMPTY, "pegou as 5 madeiras")
	inventory.click_slot(2)
	check(inventory.slot_amount(2) == limit and inventory.held_amount() == 3,
		"juntou até o limite; 3 ficaram na mão")
	inventory.click_slot(1)
	check(inventory.slot_item(1) == &"wood" and inventory.held_item() == &"stone",
		"item diferente troca: a pedra veio para a mão")
	inventory.click_slot(3)
	check(not inventory.is_holding() and inventory.slot_item(3) == &"stone", "espaço vazio recebe tudo")
	check(inventory.count(&"wood") == limit + 3 and inventory.count(&"stone") == 2,
		"nada se criou nem se perdeu")


func test_split_puts_part_of_a_stack_in_the_hand() -> void:
	var inventory := Inventory.new(3, ItemDatabase.load_all())
	inventory.add(&"wood", 10)
	check(not inventory.split_to_hand(0, 10) and not inventory.split_to_hand(0, 0),
		"nem a pilha toda, nem zero")
	check(inventory.split_to_hand(0, 4), "dividiu")
	check(inventory.slot_amount(0) == 6 and inventory.held_amount() == 4, "6 ficaram, 4 na mão")
	check(not inventory.split_to_hand(0, 2), "com a mão cheia não divide de novo")
	inventory.add(&"stone", 99 * 2)  # enche os outros espaços
	check(inventory.return_held() == 0 and inventory.count(&"wood") == 10,
		"devolver a mão completa a pilha de origem")


func test_remove_is_all_or_nothing() -> void:
	var inventory := Inventory.new(3, ItemDatabase.load_all())
	inventory.add(&"wood", 4)
	check(not inventory.remove(&"wood", 5), "não tira mais do que tem")
	check(inventory.count(&"wood") == 4, "nada saiu")
	check(inventory.remove(&"wood", 3) and inventory.count(&"wood") == 1, "tirou 3")


## Inventário cheio: o drop espera no chão e a coleta avisa em vez de perder itens.
func test_full_inventory_leaves_drops_and_refuses_gathering() -> void:
	var game := start_game()
	calm_monsters(game)
	var session: GameSession = game.session
	var player := session.get_player_entity(game.local_player_id()) as Character
	var inventory := session.get_inventory(game.local_player_id())
	inventory.add(&"stone_axe", inventory.capacity())  # um machado por espaço: tudo ocupado
	var monster := first_monster(game)
	player.position = monster.position
	monster.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, game.local_player_id()))
	await physics_frames(2)
	var pickup: Pickup = pickups(game)[0]
	await physics_frames(roundi(Pickup.POP_TIME * 60) + 2)
	player.position = pickup.position
	await physics_frames(10)
	check(is_instance_valid(pickup), "o drop ficou no chão")

	var reasons: Array = []
	player.gatherer.refused.connect(func(_n: ResourceNode, r: GatheringRules.Check) -> void: reasons.append(r))
	stand_next_to(player, resource_node(game, &"lumber_tree"))
	await physics_frames(2)
	check(not player.request_gather(), "não começa a coletar")
	check(reasons == [GatheringRules.Check.INVENTORY_FULL], "avisa: inventário cheio")



## Tela de inventário: cada espaço mostra quantidade e nome; clicar pega e põe; clicar fora
## joga no chão; botão direito divide para a mão; fechar devolve a mão.
func test_inventory_screen_click_split_and_throw_away() -> void:
	var game := start_game()
	var inventory := (game.session as GameSession).get_inventory(game.local_player_id())
	inventory.add(&"wood", 5)
	inventory.add(&"stone", 2)
	var panel: InventoryPanel = game.get_node("UI/InventoryPanel")
	panel.set_open(true)
	var slots := panel.find_children("*", "InventorySlot", true, false)
	check(slots.size() == inventory.capacity(), "um quadrado por espaço")
	var first: InventorySlot = slots[0]
	var label: Label = first.get_child(1)
	check(label.text == "5" and first.tooltip_text == Texts.name_of("ITEM", &"wood"),
		"mostra a quantidade e o nome")

	first.clicked.emit(0)
	check(inventory.is_holding() and panel.captures_mouse(), "pegou: o clique agora é do inventário")
	check(panel._held.visible, "o item na mão aparece junto ao ponteiro")
	(slots[3] as InventorySlot).clicked.emit(3)
	check(inventory.slot_item(3) == &"wood" and label.text == "", "pôs noutro espaço e a tela atualizou")

	panel._on_split_requested(1)
	check(panel._split.visible, "botão direito abre a janelinha")
	panel._split._slider.value = 1
	panel._split._confirm()
	check(inventory.held_item() == &"stone" and inventory.held_amount() == 1, "1 pedra na mão")
	panel._unhandled_input(left_click())  # clique fora da janela
	await physics_frames(2)
	check(not inventory.is_holding() and pickups(game).size() == 1, "clique fora jogou no chão")

	(slots[3] as InventorySlot).clicked.emit(3)
	panel.set_open(false)
	check(not inventory.is_holding() and inventory.count(&"wood") == 5, "fechar devolveu a mão")
	check(not panel._held.visible, "mão vazia: nada junto ao ponteiro")


## Botão direito abre o menu: "Dividir" só em pilhas de 2+, "Soltar" joga a pilha no chão.
## Clicar fora fecha o menu sem atacar.
func test_right_click_menu_splits_or_drops() -> void:
	var game := start_game()
	var inventory := (game.session as GameSession).get_inventory(game.local_player_id())
	inventory.add(&"wood", 5)
	inventory.add(&"stone_axe", 1)
	var panel: InventoryPanel = game.get_node("UI/InventoryPanel")
	panel.set_open(true)
	panel._on_menu_requested(1)
	check(panel._menu.visible and not panel._menu._split.visible and panel._menu._drop.visible,
		"item único: só Soltar")
	check(panel._menu.captures_mouse(), "menu aberto: o clique fora não ataca")
	var outside := left_click()
	outside.position = panel._menu.get_global_rect().end + Vector2(20, 20)  # longe do menu
	panel._menu._input(outside)
	await physics_frames(1)
	check(not panel._menu.visible, "clique fora fechou o menu")

	panel._on_menu_requested(0)
	check(panel._menu._split.visible, "pilha: Dividir aparece")
	panel._menu._split.pressed.emit()
	check(not panel._menu.visible and panel._split.visible, "Dividir abre a janelinha de quantidade")
	panel._split.hide()
	panel._on_menu_requested(0)
	panel._menu._drop.pressed.emit()
	await physics_frames(2)
	check(inventory.count(&"wood") == 0 and not inventory.is_holding(), "Soltar tirou a pilha inteira")
	check(pickups(game).size() == 1 and (pickups(game)[0] as Pickup).amount == 5,
		"as 5 madeiras estão no chão")
