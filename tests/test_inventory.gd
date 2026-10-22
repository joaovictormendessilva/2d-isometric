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


func test_move_swaps_or_merges() -> void:
	var inventory := Inventory.new(3, ItemDatabase.load_all())
	var limit := inventory.stack_limit(&"wood")
	inventory.replicate_slot(0, &"wood", 5)
	inventory.replicate_slot(1, &"stone", 2)
	inventory.move(0, 1)
	check(inventory.slot_item(0) == &"stone" and inventory.slot_item(1) == &"wood", "itens diferentes trocam")
	inventory.replicate_slot(2, &"wood", limit - 2)
	inventory.move(1, 2)
	check(inventory.slot_amount(2) == limit and inventory.slot_amount(1) == 3,
		"mesmo item junta até o limite; o resto fica")
	check(inventory.count(&"wood") == limit + 3, "mover não cria nem some itens")


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
