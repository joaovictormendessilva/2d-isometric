extends TestCase
## Coleta no mundo: mãos, ferramentas, níveis, cancelamento, esgotar e renascer.

const STONE_AXE := preload("res://data/items/stone_axe.tres")
const BALANCE := preload("res://data/balance/gathering.tres")


func test_hands_gather_lumber_until_depleted() -> void:
	var game := start_game()
	calm_monsters(game)
	var player := _player(game)
	var tree_node := resource_node(game, &"lumber_tree")
	stand_next_to(player, tree_node)
	await physics_frames(2)
	check(player.request_gather(), "começou a coletar com as mãos")
	var charges := tree_node.data.charges
	var duration := tree_node.data.gather_time / BALANCE.hands_speed
	await physics_frames(roundi(duration * 60) + 3)
	var inventory := _inventory(game)
	check(inventory.count(&"wood") == 1, "uma coleta: 1 madeira (tem %d)" % inventory.count(&"wood"))
	check(_skills(game).xp(&"woodcutting") == tree_node.data.xp_per_gather, "ganhou experiência de Lenhador")
	check(tree_node.charges_left == charges - 1, "gastou uma carga")
	await physics_frames(roundi(duration * 60 * (charges - 1)) + 10)
	check(tree_node.is_depleted(), "seguiu coletando sozinho até esgotar")
	check(inventory.count(&"wood") == charges, "%d madeiras no total (tem %d)" % [charges, inventory.count(&"wood")])
	check(not player.gatherer.is_gathering(), "parou ao esgotar")
	check(not player.request_gather() or player.gatherer.current_node() != tree_node,
		"ponto esgotado não é coletado")


func test_moving_or_attacking_cancels_gathering() -> void:
	var game := start_game()
	calm_monsters(game)
	var player := _player(game)
	stand_next_to(player, resource_node(game, &"lumber_tree"))
	await physics_frames(2)
	player.request_gather()
	player.set_move_intent(Vector2.LEFT)
	await physics_frames(10)
	check(not player.gatherer.is_gathering(), "andar cancela")
	player.set_move_intent(Vector2.ZERO)
	await physics_frames(10)
	stand_next_to(player, resource_node(game, &"lumber_tree"))
	player.request_gather()
	player.request_attack(Vector2.RIGHT)
	check(not player.gatherer.is_gathering(), "atacar cancela")
	await physics_frames(roundi(3.0 * 60))
	check(_inventory(game).count(&"wood") == 0, "nada coletado")


func test_old_oak_needs_tool_and_level() -> void:
	var game := start_game()
	calm_monsters(game)
	var player := _player(game)
	var oak := resource_node(game, &"old_oak")
	stand_next_to(player, oak)
	await physics_frames(2)
	var reasons: Array = []
	player.gatherer.refused.connect(func(_n: ResourceNode, reason: GatheringRules.Check) -> void:
		reasons.append(reason))
	check(not player.request_gather(), "sem ferramenta não coleta")
	check(reasons == [GatheringRules.Check.NEEDS_TOOL], "motivo: falta ferramenta")


func test_tool_from_inventory_speeds_gathering() -> void:
	var game := start_game()
	calm_monsters(game)
	var player := _player(game)
	stand_next_to(player, resource_node(game, &"lumber_tree"))
	await physics_frames(2)
	var durations: Array[float] = []
	player.gatherer.started.connect(func(_n: ResourceNode, d: float) -> void: durations.append(d))
	player.request_gather()
	player.gatherer.stop()
	_inventory(game).add(STONE_AXE.id, 1)
	player.request_gather()
	check(durations.size() == 2 and durations[1] < durations[0],
		"com machado é mais rápido (%s)" % [durations])


func test_depleted_node_respawns() -> void:
	var game := start_game()
	var node := resource_node(game, &"copper_vein")
	for i in node.data.charges:
		node.take_charge()
	check(node.is_depleted(), "esgotado")
	await physics_frames(roundi(node.data.respawn_time * 60) + 5)
	check(node.charges_left == node.data.charges, "voltou com todas as cargas")


func _player(game: Node) -> Character:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) as Character


func _inventory(game: Node) -> Inventory:
	return (game.session as GameSession).get_inventory(game.local_player_id())


func _skills(game: Node) -> SkillProgress:
	return (game.session as GameSession).get_skills(game.local_player_id())
