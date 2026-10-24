extends TestCase
## Evento de chefe errante (J4a, ADR-036): surge numa região aberta com jogadores, avisa todos,
## vai embora se ninguém o derrota e, derrotado, deixa um baú só para quem o feriu.

const PORT := 24840
const EVENT := &"wandering_king_slime"
const REGIONS_DIR := "res://data/regions/"


func test_event_data_is_consistent() -> void:
	var event := DataCatalog.new(EntitySpawner.BOSS_EVENTS_DIR).get_entry(EVENT) as BossEventData
	check(event != null and event.monster_scene != null and event.boss_data().is_boss,
		"o evento existe e o chefe dele é chefe")
	var regions := DataCatalog.new(REGIONS_DIR)
	for region_id in event.regions:
		var region := regions.get_entry(region_id) as RegionData
		check(region != null and not region.temporary, "%s: região aberta conhecida" % region_id)
	check(event.reward_chest != null and not event.reward_chest.drops.is_empty(), "tem baú")
	check(0.0 < event.interval_min and event.interval_min <= event.interval_max
		and event.stay_time > 0.0, "tempos coerentes")


func test_boss_appears_in_the_players_region_with_a_warning() -> void:
	var game := start_game()
	calm_monsters(game)
	var events: BossEvents = game.boss_events
	var heard := []
	events.announced.connect(func(kind: int, _e: BossEventData, region_id: StringName) -> void:
		heard.append([kind, region_id]))
	events.start(0.0)
	await physics_frames(2)
	var boss := events.active_boss()
	check(boss != null and Region.of(boss) == game.region, "o chefe surgiu na região do jogador")
	_calm(boss)  # parado: a seta depende só de onde o jogador está
	check(heard == [[BossEvents.Announcement.APPEARED, &"meadow"]], "avisou: apareceu na campina")
	check(not (game._event_banner as EventBanner).current_text().is_empty(), "o aviso está na tela")
	await physics_frames(5)
	check(events.active_boss() == boss, "um evento por vez")
	var arrow := game._event_arrow as EventArrow
	var player := (game.session as GameSession).get_player_entity(1) as Character
	boss.position = player.position + Iso.ground_to_screen(Vector2(400, 0))  # jogador no meio do mapa: câmera livre
	boss.reset_physics_interpolation()
	await physics_frames(3)
	check(not arrow.arrow().is_empty() and (arrow.arrow()[1] as Vector2).x > 0.9,
		"chefe fora da tela, à direita: a seta aponta para ele")
	boss.position = player.position + Iso.ground_to_screen(Vector2(60, 0))
	boss.reset_physics_interpolation()
	await physics_frames(3)
	check(arrow.arrow().is_empty(), "chefe na tela: sem seta")


func test_no_event_while_everyone_is_in_a_dungeon() -> void:
	var game := start_game()
	game._travel(1, &"slime_cave", &"to_forest")
	await physics_frames(2)
	var events: BossEvents = game.boss_events
	events.start(0.0)
	await physics_frames(2)
	check(events.active_boss() == null, "sem região aberta com jogadores: nada surge")


func test_boss_leaves_when_time_is_up_and_nobody_fights() -> void:
	var game := start_game()
	calm_monsters(game)
	var events: BossEvents = game.boss_events
	events.start(0.0)
	await physics_frames(2)
	var boss := events.active_boss()
	_calm(boss)
	var heard := []
	events.announced.connect(func(kind: int, _e: BossEventData, _r: StringName) -> void:
		heard.append(kind))
	events._stay_left = 0.0
	await physics_frames(2)
	check(not is_instance_valid(boss) or boss.is_queued_for_deletion(), "foi embora")
	check(heard == [BossEvents.Announcement.LEFT], "avisou que foi embora")
	check(events.active_boss() == null, "o evento acabou")


func test_defeated_boss_leaves_a_chest_only_for_who_hurt_it() -> void:
	var game := start_game()
	calm_monsters(game)
	var events: BossEvents = game.boss_events
	events.start(0.0)
	await physics_frames(2)
	var boss := events.active_boss()
	_calm(boss)
	var heard := []
	events.announced.connect(func(kind: int, _e: BossEventData, _r: StringName) -> void:
		heard.append(kind))
	boss.health.apply_damage(DamageInfo.create(boss.health.current, Vector2.RIGHT, 0.0, 0, 1))
	check(heard == [BossEvents.Announcement.DEFEATED], "avisou a vitória")
	var chest := await _chest(game)
	check(chest != null, "o baú surgiu onde o chefe caiu")
	check(chest.can_open(1) and not chest.can_open(2), "só quem feriu o chefe abre")


## Coop: o aviso chega ao cliente; quem não feriu o chefe não abre o baú (nem forjando o pedido).
func test_client_hears_the_event_and_only_helpers_open_the_chest() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(connected, "cliente conectou")
	calm_monsters(host)
	var client_id: int = client.local_player_id()
	var heard := []
	(client.boss_events as BossEvents).announced.connect(
		func(kind: int, event: BossEventData, region_id: StringName) -> void:
			heard.append([kind, event.id, region_id]))
	var events: BossEvents = host.boss_events
	events.start(0.0)
	check(await wait_until(func() -> bool: return not heard.is_empty(), 60),
		"o aviso chegou ao cliente")
	check(heard[0] == [BossEvents.Announcement.APPEARED, EVENT, &"meadow"], "com o chefe e a região")

	var boss := events.active_boss()
	_calm(boss)
	boss.health.apply_damage(DamageInfo.create(boss.health.current, Vector2.RIGHT, 0.0, 0, 1))
	var chest := await _chest(host)
	check(chest != null and chest.allowed == PackedInt32Array([1]), "baú só do host (quem feriu)")
	var seen: Array = []
	check(await wait_until(func() -> bool:
		seen.assign((client.region as Region).entities.get_children().filter(func(n: Node) -> bool:
			return n is RewardChest))
		return not seen.is_empty(), 60), "o cliente vê o baú")
	var copy := seen[0] as RewardChest
	check(copy.allowed == PackedInt32Array([1]) and not copy.can_open(client_id),
		"no cliente, o baú não é dele")
	# No host, mesmo encostado no baú (posto ali neste quadro), o cliente não pode abri-lo.
	var on_host := (host.session as GameSession).get_player_entity(client_id) as Character
	on_host.position = chest.position + Iso.ground_to_screen(Vector2(10, 0))
	check((host.player_state as PlayerStateSync).chest_near(client_id) == null,
		"o host não oferece o baú a quem não feriu")
	(client.player_state as PlayerStateSync)._request(&"_open_chest_requested", [])  # forjado
	await physics_frames(10)
	check(not chest.was_opened_by(client_id), "pedido forjado: o host recusa")


func _calm(boss: Monster) -> void:
	boss.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED


## Espera o baú do evento surgir (depois que o corpo some) e o devolve.
func _chest(game: Node) -> RewardChest:
	await physics_frames(roundi(EntitySpawner.CORPSE_TIME * 60.0) + 4)
	for node in (game.region as Region).entities.get_children():
		if node is RewardChest:
			return node
	return null
