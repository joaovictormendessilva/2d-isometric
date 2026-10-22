extends TestCase
## Regiões e passagens (ADR-005/020): sozinho, entrar na passagem troca a região carregada; o
## personagem chega na passagem de volta com tudo o que tinha; a região deixada guarda o estado
## (save em memória) e some com as criaturas dela. No coop a viagem ainda não existe (F2c).

const SAVE_DIR := "user://test_saves/"
const SAVE_PATH := SAVE_DIR + "regions.json"
const PORT := 24720


func test_walking_into_the_passage_goes_to_the_forest() -> void:
	var game := start_game()
	calm_monsters(game)
	var player := _player(game)
	(game.session as GameSession).get_inventory(1).add(&"wood", 5)
	var passage := (game.region as Region).get_passage(&"to_forest")
	player.position = passage.arrival_position()
	player.reset_physics_interpolation()
	player.set_move_intent(Vector2.RIGHT)
	var arrived := await wait_until(func() -> bool: return game.region.region_id == &"forest")
	player.set_move_intent(Vector2.ZERO)
	check(arrived, "andando para a passagem, chega na floresta")
	var forest: Region = game.region
	check(player.get_parent() == forest.entities, "personagem está na floresta")
	check(player.position.distance_to(forest.get_passage(&"to_meadow").arrival_position()) < 4.0,
		"chega na passagem de volta (%s)" % player.position)
	check((game.session as GameSession).get_inventory(1).count(&"wood") == 5, "itens vão junto")
	check(is_instance_valid(player.health) and not player.health.is_dead(), "continua vivo")
	var monsters := forest.entities.get_children().filter(func(n: Node) -> bool: return n is Monster)
	check(monsters.size() == forest.get_monster_spawn_points().size(), "criaturas da floresta")
	check((game.session as GameSession).get_entity_count() == monsters.size() + 1,
		"na sessão só ficam o jogador e as criaturas da floresta (%d)"
			% (game.session as GameSession).get_entity_count())
	check(game.get_node("World").get_children().filter(
		func(n: Node) -> bool: return n is Region).size() == 1, "a campina foi liberada")


func test_region_left_behind_keeps_its_state() -> void:
	var game := start_game()
	calm_monsters(game)
	var tree_node := resource_node(game, &"lumber_tree")
	var tree_name := NodePath(tree_node.name)
	while not tree_node.is_depleted():
		tree_node.take_charge()
	await _go_through(game, &"to_forest")
	check(game.region.region_id == &"forest", "foi para a floresta")
	await _go_through(game, &"to_forest" if game.region.region_id == &"meadow" else &"to_meadow")
	check(game.region.region_id == &"meadow", "voltou para a campina")
	var again := game.region.entities.get_node(tree_name) as ResourceNode
	check(again.is_depleted(), "a árvore coletada continua esgotada")


func test_save_remembers_the_region() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var game := start_game(SAVE_PATH)
	calm_monsters(game)
	await _go_through(game, &"to_forest")
	check((game.saves as SaveService).save_now() == OK, "grava")
	game.free()
	game = start_game(SAVE_PATH)
	check(game.region.region_id == &"forest", "volta para a floresta")
	check(_player(game).position == (game.region as Region).get_spawn_position(),
		"no ponto de entrada dela")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_respawns_from_the_old_region_are_dropped() -> void:
	var game := start_game()
	calm_monsters(game)
	var spawner: EntitySpawner = game.get_node("EntitySpawner")
	var stale := spawner._region_generation
	await _go_through(game, &"to_forest")
	var before := (game.session as GameSession).get_entity_count()
	spawner._respawn_monster(0, stale)  # renascimento agendado na campina
	check((game.session as GameSession).get_entity_count() == before,
		"criatura da campina não nasce na floresta")


## No coop ainda não há viagem: a passagem não troca a região e a parede segura o jogador.
func test_passage_does_not_travel_in_coop() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	await wait_until(func() -> bool: return _player(client) != null)
	calm_monsters(host)
	var player := _player(host)
	player.position = (host.region as Region).get_passage(&"to_forest").arrival_position()
	player.reset_physics_interpolation()
	player.set_move_intent(Vector2.RIGHT)
	await physics_frames(120)
	player.set_move_intent(Vector2.ZERO)
	check(host.region.region_id == &"meadow", "host continua na campina")
	check(player.position.x < (host.region as Region).camera_bounds.end.x,
		"a parede não deixa sair do mapa (%s)" % player.position)


func _player(game: Node) -> Character:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) as Character


## Põe o jogador no gatilho da passagem e espera a viagem (ou desistir).
func _go_through(game: Node, passage_id: StringName) -> void:
	var from: StringName = game.region.region_id
	var player := _player(game)
	player.position = (game.region as Region).get_passage(passage_id).global_position
	player.reset_physics_interpolation()
	await wait_until(func() -> bool: return game.region.region_id != from, 30)
