extends TestCase
## Regiões e passagens (ADR-005/020): entrar na passagem leva à outra região; o personagem é
## recriado lá com tudo o que tinha; a região que fica sem ninguém é guardada (save em memória)
## e liberada com as criaturas dela. No coop cada jogador fica na região que quiser, e cada
## cliente só recebe o que é da região dele.

const SAVE_DIR := "user://test_saves/"
const SAVE_PATH := SAVE_DIR + "regions.json"
const PORT := 24720
## Passos de física para a região deixada ser liberada (Main.EMPTY_REGION_TIME, com folga).
const RELEASE_FRAMES := 150


func test_walking_into_the_passage_goes_to_the_forest() -> void:
	var game := start_game()
	calm_monsters(game)
	var player := _player(game)
	(game.session as GameSession).get_inventory(1).add(&"wood", 5)
	player.health.set_current(37)
	var passage := (game.region as Region).get_passage(&"to_forest")
	player.position = passage.arrival_position()
	player.reset_physics_interpolation()
	player.set_move_intent(Vector2.RIGHT)
	var arrived := await wait_until(func() -> bool: return game.region.region_id == &"forest")
	check(arrived, "andando para a passagem, chega na floresta")
	var forest: Region = game.region
	player = _player(game)
	check(player.get_parent() == forest.entities, "personagem está na floresta")
	check(player.position.distance_to(forest.get_passage(&"to_meadow").arrival_position()) < 4.0,
		"chega na passagem de volta (%s)" % player.position)
	check((game.session as GameSession).get_inventory(1).count(&"wood") == 5, "itens vão junto")
	check(player.health.current == 37, "a vida vai junto (%d)" % player.health.current)
	var monsters := forest.entities.get_children().filter(func(n: Node) -> bool: return n is Monster)
	check(monsters.size() == forest.get_monster_spawn_points().size(), "criaturas da floresta")
	var released := await wait_until(func() -> bool: return _loaded(game).size() == 1, RELEASE_FRAMES)
	check(released, "a campina, sem ninguém, foi liberada")
	check((game.session as GameSession).get_entity_count() == monsters.size() + 1,
		"na sessão só ficam o jogador e as criaturas da floresta (%d)"
			% (game.session as GameSession).get_entity_count())


## Bug do João (F3a): depois de viajar (personagem recriado), vestir a mochila não abria os
## espaços e tirá-la não os fechava — o tamanho usava os bônus do equipamento anterior.
func test_backpack_resizes_the_inventory_after_traveling() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var inventory := session.get_inventory(1)
	var state: PlayerStateSync = game.player_state
	var base := inventory.capacity()
	for trip: Array in [[&"forest", &"to_meadow"], [&"meadow", &"to_forest"]]:
		game._travel(1, trip[0], trip[1])
		await physics_frames(2)
		inventory.add(&"simple_backpack", 1)
		state.request_equip(slot_of(inventory, &"simple_backpack"))
		check(inventory.capacity() > base,
			"em %s, vestir a mochila abre os espaços (%d)" % [trip[0], inventory.capacity()])
		var backpack_slot := session.get_equipment(1).index_of_type(EquipmentData.Slot.BACKPACK)
		state.request_click_equipment(backpack_slot)  # tira para a mão
		check(inventory.held_item() == &"simple_backpack" and inventory.capacity() == base,
			"em %s, tirar a mochila fecha os espaços (%d)" % [trip[0], inventory.capacity()])
		state.request_return_held()
		await physics_frames(1)
	inventory.remove(&"simple_backpack", 1)


func test_region_left_behind_keeps_its_state() -> void:
	var game := start_game()
	calm_monsters(game)
	var tree_node := resource_node(game, &"lumber_tree")
	var tree_name := NodePath(tree_node.name)
	while not tree_node.is_depleted():
		tree_node.take_charge()
	await _go_through(game, &"to_forest")
	check(game.region.region_id == &"forest", "foi para a floresta")
	await wait_until(func() -> bool: return _loaded(game).size() == 1, RELEASE_FRAMES)
	await _go_through(game, &"to_meadow")
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


func test_respawns_in_a_released_region_are_dropped() -> void:
	var game := start_game()
	calm_monsters(game)
	var spawner: EntitySpawner = game.get_node("EntitySpawner")
	var meadow: WeakRef = weakref(game.region)
	await _go_through(game, &"to_forest")
	await wait_until(func() -> bool: return meadow.get_ref() == null, RELEASE_FRAMES)
	var before := (game.session as GameSession).get_entity_count()
	spawner._respawn_monster(0, meadow)  # renascimento agendado na campina antes da viagem
	check((game.session as GameSession).get_entity_count() == before,
		"criatura da campina não nasce depois de a campina ser liberada")


## Coop: o cliente vai para a floresta e o host fica na campina. Cada um só recebe a própria
## região; o host simula as duas.
func test_client_goes_to_another_region_alone() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	await wait_until(func() -> bool: return _player(client) != null)
	calm_monsters(host)
	var client_id: int = client.local_player_id()
	(host.session as GameSession).get_inventory(client_id).add(&"stone", 3)
	host._travel(client_id, &"forest", &"to_meadow")
	var arrived := await wait_until(func() -> bool:
		return client.region and client.region.region_id == &"forest" and _player(client) != null)
	check(arrived, "o cliente chega na floresta")
	check(host.region.region_id == &"meadow", "o host continua mostrando a campina")
	check(_loaded(host).size() == 2, "o host simula as duas regiões")
	check(_loaded(client).size() == 1, "o cliente só tem a floresta")
	var forest: Region = client.region
	await wait_until(func() -> bool:
		return _count(forest, Monster) == forest.get_monster_spawn_points().size())
	check(_count(forest, Monster) == forest.get_monster_spawn_points().size(),
		"o cliente recebe as criaturas da floresta")
	check((client.session as GameSession).get_player_entity(1) == null,
		"o personagem do host (na campina) não existe no cliente")
	check((client.session as GameSession).get_inventory(client_id).count(&"stone") == 3,
		"o inventário do cliente continua o mesmo")
	var host_forest := (host.worlds as RegionWorlds).get_region(&"forest")
	check(_player(client).position.distance_to(host_forest.get_passage(&"to_meadow").arrival_position()) < 4.0,
		"chega na passagem de volta")

	# O que acontece na campina não chega ao cliente que está na floresta.
	var host_player := _player(host)
	var bench: StructureData = (host.get_node("EntitySpawner") as EntitySpawner).structures \
		.get_entry(&"workbench")
	(host.get_node("EntitySpawner") as EntitySpawner).spawn_structure(host.region, bench,
		free_spot_near(host_player, bench))
	await physics_frames(10)
	check(_count(forest, Structure) == 0, "a bancada da campina não aparece na floresta")


## O host vai para onde o cliente está: os dois voltam a se ver. Depois o cliente volta para a
## campina (agora vazia de jogadores) e a floresta continua carregada por causa do host.
func test_players_meet_again_in_the_same_region() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	await wait_until(func() -> bool: return _player(client) != null)
	calm_monsters(host)
	var client_id: int = client.local_player_id()
	host._travel(client_id, &"forest", &"to_meadow")
	await wait_until(func() -> bool: return client.region and client.region.region_id == &"forest")
	host._travel(1, &"forest", &"to_meadow")
	var met := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(1) != null)
	check(met, "o cliente vê o host chegar na floresta")
	check(host.region.region_id == &"forest", "o host mostra a floresta")
	var meadow_released := await wait_until(func() -> bool: return _loaded(host).size() == 1,
		RELEASE_FRAMES)
	check(meadow_released, "a campina, sem ninguém, foi liberada no host")

	host._travel(client_id, &"meadow", &"to_forest")
	var back := await wait_until(func() -> bool:
		return client.region and client.region.region_id == &"meadow" and _player(client) != null)
	check(back, "o cliente volta para a campina")
	check((client.session as GameSession).get_player_entity(1) == null,
		"o host (na floresta) não está na campina do cliente")
	await physics_frames(RELEASE_FRAMES)
	check(_loaded(host).size() == 2, "as duas regiões ocupadas continuam carregadas no host")


func _player(game: Node) -> Character:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) as Character


func _loaded(game: Node) -> Array[Region]:
	return (game.worlds as RegionWorlds).loaded()


func _count(region: Region, type: Variant) -> int:
	return region.entities.get_children().filter(func(n: Node) -> bool: return is_instance_of(n, type)).size()


## Põe o jogador no gatilho da passagem e espera a viagem (ou desistir).
func _go_through(game: Node, passage_id: StringName) -> void:
	var from: StringName = game.region.region_id
	var player := _player(game)
	player.position = (game.region as Region).get_passage(passage_id).global_position
	player.reset_physics_interpolation()
	await wait_until(func() -> bool: return game.region.region_id != from, 30)
