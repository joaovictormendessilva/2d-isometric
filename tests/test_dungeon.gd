extends TestCase
## Dungeon (Etapa J1, ADR-031): a boca da caverna na floresta leva a uma região temporária que
## começa do zero a cada vez que é carregada, não vai para o save, não tem renascimento nem
## construção; quem sai do jogo lá dentro volta para a entrada.

const SAVE_DIR := "user://test_saves/"
const SAVE_PATH := SAVE_DIR + "dungeon.json"
const PORT := 24720
const CAVE := &"slime_cave"
## Passos de física para a região deixada ser liberada (Main.EMPTY_REGION_TIME, com folga).
const RELEASE_FRAMES := 150


func test_walking_into_the_cave_mouth_enters_the_dungeon() -> void:
	var game := await _in_forest()
	var player := _player(game)
	var mouth := (game.region as Region).get_passage(&"cave_entrance")
	player.position = mouth.arrival_position()
	player.reset_physics_interpolation()
	player.set_move_intent(Vector2.UP)  # de frente para a boca: o monte não barra antes
	check(await wait_until(func() -> bool: return game.region.region_id == CAVE),
		"andando para a boca da caverna, entra na dungeon")
	var cave: Region = game.region
	check(cave.is_temporary(), "a caverna é temporária")
	check(_player(game).position.distance_to(cave.get_passage(&"to_forest").arrival_position()) < 4.0,
		"chega na saída da caverna (%s)" % _player(game).position)


func test_leaving_the_dungeon_arrives_at_the_cave_mouth() -> void:
	var game := await _in_cave()
	await _go_through(game, &"to_forest")
	check(game.region.region_id == &"forest", "saiu para a floresta")
	var mouth := (game.region as Region).get_passage(&"cave_entrance")
	check(_player(game).position.distance_to(mouth.arrival_position()) < 4.0,
		"na frente da boca da caverna (%s)" % _player(game).position)


func test_dungeon_starts_over_when_everyone_leaves() -> void:
	var game := await _in_cave()
	var cave: Region = game.region
	var full := cave.get_monster_spawn_points().size()
	_kill(first_monster(game))
	var vein := resource_node(game, &"copper_vein")
	var vein_name := NodePath(vein.name)
	while not vein.is_depleted():
		vein.take_charge()
	await _go_through(game, &"to_forest")
	var cave_ref: WeakRef = weakref(cave)
	check(await wait_until(func() -> bool: return cave_ref.get_ref() == null, RELEASE_FRAMES),
		"a caverna vazia é liberada")
	await _go_through(game, &"cave_entrance")
	check(game.region.region_id == CAVE, "voltou para a caverna")
	check(_monsters(game.region).size() == full, "todas as criaturas de novo (%d de %d)"
		% [_monsters(game.region).size(), full])
	var again := game.region.entities.get_node(vein_name) as ResourceNode
	check(not again.is_depleted(), "o veio de cobre está cheio de novo")


func test_dungeon_creatures_do_not_respawn() -> void:
	var game := await _in_cave()
	var cave: Region = game.region
	for point in cave.get_monster_spawn_points():
		point.respawn_time = 0.05  # numa região comum, renasceria logo
	var before := _monsters(cave).size()
	_kill(first_monster(game))
	await physics_frames(60)
	check(_monsters(cave).filter(func(m: Monster) -> bool: return m.is_alive()).size() == before - 1,
		"a criatura morta não renasce")


func test_no_building_in_the_dungeon() -> void:
	var game := await _in_forest()
	var bench: StructureData = (game.get_node("EntitySpawner") as EntitySpawner).structures \
		.get_entry(&"workbench")
	var player := _player(game)
	var spot := free_spot_near(player, bench)
	check((game.region as Region).can_place(bench, player.position, spot), "na floresta, pode")
	await _go_through(game, &"cave_entrance")
	player = _player(game)
	spot = free_spot_near(player, bench)
	check(PlacementRules.can_place(player.get_world_2d().direct_space_state, bench,
		player.position, spot), "o chão da caverna está livre")
	check(not (game.region as Region).can_place(bench, player.position, spot),
		"mas na dungeon não se constrói")
	var inventory := (game.session as GameSession).get_inventory(1)
	inventory.add(&"workbench", 1)
	(game.player_state as PlayerStateSync).request_click(slot_of(inventory, &"workbench"))
	(game.player_state as PlayerStateSync).request_place(spot)
	await physics_frames(2)
	check(game.region.entities.get_children().filter(func(n: Node) -> bool: return n is Structure)
		.is_empty(), "o host recusa o pedido")
	check(inventory.held_item() == &"workbench", "a bancada continua na mão")


func test_quitting_inside_returns_to_the_entrance() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var game := start_game(SAVE_PATH)
	calm_monsters(game)
	await _go_through_to(game, &"forest", &"to_meadow")
	await _go_through(game, &"cave_entrance")
	check(game.region.region_id == CAVE, "dentro da caverna")
	check((game.saves as SaveService).save_now() == OK, "grava")
	game.free()
	game = start_game(SAVE_PATH)
	check(game.region.region_id == &"forest", "volta para a floresta")
	var mouth := (game.region as Region).get_passage(&"cave_entrance")
	check(_player(game).position.distance_to(mouth.arrival_position()) < 4.0,
		"na frente da boca da caverna (%s)" % _player(game).position)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Coop: o cliente entra na caverna sozinho e recebe as criaturas dela; o host continua fora.
func test_client_enters_the_dungeon() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	await wait_until(func() -> bool: return _player(client) != null)
	calm_monsters(host)
	host._travel(client.local_player_id(), CAVE, &"to_forest")
	check(await wait_until(func() -> bool:
		return client.region and client.region.region_id == CAVE and _player(client) != null),
		"o cliente chega na caverna")
	var cave: Region = client.region
	check(await wait_until(func() -> bool:
		return _monsters(cave).size() == cave.get_monster_spawn_points().size()),
		"e recebe as criaturas dela")
	check(host.region.region_id == &"meadow", "o host continua na campina")


# --- Auxiliares ------------------------------------------------------------------------------

func _in_forest() -> Node:
	var game := start_game()
	await _go_through_to(game, &"forest", &"to_meadow")
	calm_monsters(game)
	return game


func _in_cave() -> Node:
	var game := await _in_forest()
	await _go_through(game, &"cave_entrance")
	check(game.region.region_id == CAVE, "entrou na caverna")
	calm_monsters(game)
	return game


## Viagem direta do jogador do host (sem andar até a passagem).
func _go_through_to(game: Node, region_id: StringName, passage_id: StringName) -> void:
	game._travel(1, region_id, passage_id)
	await physics_frames(2)


## Põe o jogador no gatilho da passagem e espera a viagem.
func _go_through(game: Node, passage_id: StringName) -> void:
	var from: StringName = game.region.region_id
	var player := _player(game)
	player.position = (game.region as Region).get_passage(passage_id).global_position
	player.reset_physics_interpolation()
	await wait_until(func() -> bool: return game.region.region_id != from, 30)
	await physics_frames(2)


func _player(game: Node) -> Character:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) as Character


func _monsters(region: Region) -> Array:
	return region.entities.get_children().filter(func(n: Node) -> bool:
		return n is Monster and not n.is_queued_for_deletion())


func _kill(monster: Monster) -> void:
	monster.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, 1))
