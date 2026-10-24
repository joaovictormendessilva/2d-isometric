extends TestCase
## Pedras de portal (J5a, ADR-037): ativar uma pedra (fica para o personagem, vai no save) e viajar
## de uma pedra ativada para outra, canalizando 1 s (dano ou andar interrompem). O host decide.

const PORT := 24850
const SAVE_DIR := "user://test_saves/"
const SAVE_PATH := SAVE_DIR + "waystones_world.json"
const CAMP := &"meadow_camp"
const FOREST_EDGE := &"forest_edge"
const FOREST_CAVE := &"forest_cave"


func test_waystones_are_listed_with_unique_ids_and_names() -> void:
	var regions := DataCatalog.new("res://data/regions/")
	var atlas := WaystoneAtlas.new(regions)
	var seen := {}
	for entry in regions.entries():
		var region := entry as RegionData
		check(not region.temporary or region.waystones.is_empty(), "%s: dungeon sem pedras" % region.id)
		for stone in region.waystones:
			check(not seen.has(stone.id), "%s: id único" % stone.id)
			seen[stone.id] = true
			check(atlas.region_of(stone.id) == region.id, "%s: o atlas acha a região" % stone.id)
			check(stone.get_display_name() != String(stone.id), "%s: tem nome" % stone.id)
	check(seen.has(CAMP) and seen.has(FOREST_EDGE) and seen.has(FOREST_CAVE), "pedras de teste")


func test_activating_a_waystone_lights_it_for_the_player() -> void:
	var game := start_game()
	calm_monsters(game)
	var player := _player(game)
	var stone := _stone(game, CAMP)
	check(stone != null and not stone.is_lit(), "a pedra da campina existe, apagada")
	var state: PlayerStateSync = game.player_state
	player.position = stone.position + Iso.ground_to_screen(Vector2(80, 0))
	state.request_activate_waystone()
	check(not _known(game).knows(CAMP), "longe: nada acontece")
	_stand_at(player, stone)
	state.request_activate_waystone()
	await physics_frames(2)
	check(_known(game).knows(CAMP) and stone.is_lit(), "perto: ativou e acendeu")
	check(Texts.format(&"FEEDBACK_WAYSTONE_ACTIVATED", [stone.data.get_display_name()])
		in feedback_texts(game), "avisou")


func test_traveling_channels_then_arrives_at_the_other_waystone() -> void:
	var game := start_game()
	calm_monsters(game)
	var state: PlayerStateSync = game.player_state
	var known := _known(game)
	known.activate(CAMP)
	_stand_at(_player(game), _stone(game, CAMP))
	state.request_waystone_travel(FOREST_EDGE)
	check(not _player(game).channel.is_channeling(), "destino não ativado: nada")
	known.activate(FOREST_EDGE)
	state.request_waystone_travel(FOREST_EDGE)
	check(_player(game).channel.is_channeling(), "começou a canalizar")
	await physics_frames(roundi(Waystone.CHANNEL_TIME * 60.0) + 4)
	var arrived := _player(game)
	check(Region.of(arrived).region_id == &"forest", "chegou à floresta")
	var stone := _stone(game, FOREST_EDGE)
	check(stone != null and arrived.position.distance_to(stone.arrival_position()) < 2.0,
		"na frente da pedra de destino")


func test_damage_or_walking_interrupts_the_channel() -> void:
	var game := start_game()
	calm_monsters(game)
	var state: PlayerStateSync = game.player_state
	_known(game).activate(CAMP)
	_known(game).activate(FOREST_EDGE)
	var player := _player(game)
	_stand_at(player, _stone(game, CAMP))
	state.request_waystone_travel(FOREST_EDGE)
	await physics_frames(10)
	player.health.apply_damage(DamageInfo.create(1, Vector2.RIGHT, 0.0, 0, 0))
	check(not player.channel.is_channeling(), "apanhou: interrompeu")
	var recovery := maxf(player.stats.hit_stun, player.stats.invulnerability_time)
	await physics_frames(roundi(recovery * 60.0) + 2)
	state.request_waystone_travel(FOREST_EDGE)
	check(player.channel.is_channeling(), "recomeçou")
	player.set_move_intent(Vector2.RIGHT)
	await physics_frames(20)
	player.set_move_intent(Vector2.ZERO)
	check(not player.channel.is_channeling(), "andou: interrompeu")
	await physics_frames(roundi(Waystone.CHANNEL_TIME * 60.0))
	check(Region.of(_player(game)).region_id == &"meadow", "continua na campina")


func test_activated_waystones_are_saved() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var game := start_game(SAVE_PATH)
	_known(game).activate(CAMP)
	check((game.saves as SaveService).save_now() == OK, "grava")
	game.free()
	game = start_game(SAVE_PATH)
	await physics_frames(2)
	check(_known(game).knows(CAMP) and not _known(game).knows(FOREST_EDGE), "volta ativada")
	check(_stone(game, CAMP).is_lit(), "a pedra já aparece acesa")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Coop: o cliente ativa e viaja pelo host; pedidos forjados (destino não ativado, longe de uma
## pedra) não fazem nada; a pedra acende só para quem a ativou.
func test_client_activates_and_travels_through_host() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(connected, "cliente conectou")
	calm_monsters(host)
	var client_id: int = client.local_player_id()
	var host_session := host.session as GameSession
	var requests: PlayerStateSync = client.player_state
	var on_host := host_session.get_player_entity(client_id) as Character
	var on_client := (client.session as GameSession).get_player_entity(client_id) as Character
	var host_stone := _stone(host, CAMP)
	check(await wait_until(func() -> bool: return _stone(client, CAMP) != null, 60),
		"o cliente vê a pedra")

	requests._request(&"_waystone_travel_requested", [String(FOREST_EDGE)])  # forjado: nada ativo
	await physics_frames(10)
	check(not on_host.channel.is_channeling(), "sem pedras ativadas: o host não deixa viajar")

	await glide_to(on_client, host_stone.arrival_position())
	await physics_frames(10)
	requests.request_activate_waystone()
	check(await wait_until(func() -> bool: return _stone(client, CAMP).is_lit(), 60),
		"ativou: a pedra acende no cliente")
	check(host_session.get_waystones(client_id).knows(CAMP), "o host guardou")
	check(not host_stone.is_lit(), "no host, a pedra não acende para o jogador dele")

	host_session.get_waystones(client_id).activate(FOREST_CAVE)
	requests.request_waystone_travel(FOREST_CAVE)
	check(await wait_until(func() -> bool: return on_client.channel.is_channeling(), 30),
		"o cliente vê a barrinha")
	check(await wait_until(func() -> bool:
		var now := (client.session as GameSession).get_player_entity(client_id) as Character
		return now != null and Region.of(now) != null and Region.of(now).region_id == &"forest", 180),
		"chegou à floresta, na pedra da caverna")


func _player(game: Node) -> Character:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) as Character


func _known(game: Node) -> WaystoneLog:
	return (game.session as GameSession).get_waystones(game.local_player_id())


func _stone(game: Node, waystone_id: StringName) -> Waystone:
	var region := game.region as Region
	return region.entities.get_node_or_null("W_%s" % waystone_id) as Waystone if region else null


func _stand_at(player: Character, stone: Waystone) -> void:
	player.position = stone.arrival_position()
	player.reset_physics_interpolation()
