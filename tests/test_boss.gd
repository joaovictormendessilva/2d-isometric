extends TestCase
## Mini boss (F4, ADR-024): o Rei Slime numa clareira da floresta salta em quem está a meia
## distância, com aviso no chão; quem sai do círculo não toma dano. Barra de vida no alto da tela
## e drop especial. No coop, o host decide e os clientes veem o salto.

const PORT := 24750
const FOREST_PATH := "res://scenes/regions/forest/forest.tscn"
## Onde o jogador fica para provocar o salto: meia distância do chefe (chão).
const SLAM_OFFSET := Vector2(100, 0)


func test_forest_has_the_boss_in_a_clearing() -> void:
	var forest: Region = add_to_tree(load(FOREST_PATH).instantiate())
	var points := forest.get_monster_spawn_points()
	var boss_point: MonsterSpawnPoint = points[-1]
	check(boss_point.name == "Boss", "o último ponto da floresta é o do chefe")
	var boss := boss_point.monster_scene.instantiate() as Monster
	check(boss.data.is_boss and boss.data.slam != null and boss.has_node("SlamAttacker"),
		"o Rei Slime é chefe e salta")
	check(boss.data.drops.any(func(entry: DropEntry) -> bool:
		return entry.item.id == &"king_slime_core" and entry.chance >= 1.0),
		"o núcleo cai sempre")
	check(boss_point.respawn_time >= 120.0, "o chefe demora a voltar (%.0f s)" % boss_point.respawn_time)
	boss.free()
	await physics_frames(1)
	var space := forest.get_world_2d().direct_space_state
	for angle in 8:
		var spot := boss_point.position + Iso.ground_to_screen(Vector2.from_angle(TAU * angle / 8.0) * 90.0)
		check(GroundQuery.is_walkable(space, spot, 14.0), "a clareira é livre em volta (%s)" % spot)


## Quem sai do círculo de aviso antes da queda não toma dano; o chefe cai onde o aviso mostrou.
func test_leaving_the_warning_circle_avoids_the_slam() -> void:
	var game := await _game_at_the_boss()
	var boss := _boss(game)
	var player := _player(game)
	var landing := player.position
	check(await wait_until(func() -> bool: return boss.slammer.is_slamming(), 120),
		"o chefe começou o salto")
	check(boss.slammer.landing().distance_to(landing) < 1.0, "vai cair onde o jogador estava")
	var region := game.region as Region
	check(region.ground_effects.get_children().any(func(n: Node) -> bool: return n is GroundTelegraph),
		"há um aviso no chão")
	player.position = landing + Iso.ground_to_screen(Vector2(0, 70))
	player.reset_physics_interpolation()
	check(await wait_until(func() -> bool:
		return not boss.slammer.is_airborne() and boss.position.distance_to(landing) < 1.0, 120),
		"caiu no ponto do aviso")
	await physics_frames(2)
	check(player.health.current == player.health.max_health, "fora do círculo: sem dano")


func test_staying_in_the_circle_takes_the_slam() -> void:
	var game := await _game_at_the_boss()
	var boss := _boss(game)
	var player := _player(game)
	var landing := player.position
	check(await wait_until(func() -> bool: return boss.slammer.is_slamming(), 120), "saltou")
	var damage := boss.data.slam.damage
	check(await wait_until(func() -> bool: return player.health.current < player.health.max_health,
		150), "ficou no círculo e tomou o golpe")
	check(player.health.current == player.health.max_health - damage,
		"dano do salto (%d)" % (player.health.max_health - player.health.current))
	await physics_frames(10)
	check(player.position.distance_to(landing) > 4.0, "foi empurrado para fora")


## Barra no alto da tela perto do chefe; ao morrer, ela some e cai o núcleo do jogador.
func test_boss_bar_and_special_drop() -> void:
	var game := start_game()
	game._travel(1, &"forest", &"to_meadow")
	await physics_frames(2)
	var bar: BossBar = game.find_children("*", "BossBar", true, false)[0]
	await physics_frames(1)
	check(not bar.visible, "longe do chefe: sem barra")
	var boss := _boss(game)
	var player := _player(game)
	player.position = boss.position + Iso.ground_to_screen(Vector2(160, 0))
	player.reset_physics_interpolation()
	await physics_frames(1)
	check(bar.visible and bar._name.text == boss.data.get_display_name(), "perto: barra com o nome")
	boss.health.apply_damage(DamageInfo.create(boss.health.max_health / 2, Vector2.RIGHT, 0.0,
		player.entity_id, 1))
	await physics_frames(1)
	check_near(bar._fill.size.x, BossBar.BAR_SIZE.x / 2.0, 1.0, "metade da vida, metade da barra")
	boss.health.apply_damage(DamageInfo.create(boss.health.max_health, Vector2.RIGHT, 0.0,
		player.entity_id, 1))
	await physics_frames(2)
	check(not bar.visible, "morto: a barra some")
	check(pickups(game).any(func(p: Pickup) -> bool:
		return p.item.id == &"king_slime_core" and p.owner_player_id == 1), "caiu o núcleo")


## Coop: o host simula o chefe; o cliente na floresta vê o salto (aviso e pulo) do mesmo ponto.
func test_client_sees_the_slam() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	check(await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null),
		"cliente conectou")
	var client_id: int = client.local_player_id()
	host._travel(client_id, &"forest", &"to_meadow")
	host._travel(1, &"forest", &"to_meadow")
	check(await wait_until(func() -> bool:
		return client.region and client.region.region_id == &"forest" and _boss(client) != null),
		"o cliente está na floresta e vê o chefe")
	calm_monsters(host)
	var host_boss := _boss(host)
	host_boss.get_node("Brain").process_mode = Node.PROCESS_MODE_INHERIT
	var player := _player(host)
	player.position = host_boss.position + Iso.ground_to_screen(SLAM_OFFSET)
	player.reset_physics_interpolation()
	check(await wait_until(func() -> bool: return host_boss.slammer.is_slamming(), 120),
		"o chefe saltou no host")
	var client_boss := _boss(client)
	check(await wait_until(func() -> bool: return client_boss.slammer.is_slamming(), 60),
		"o cliente recebeu o salto")
	check(client_boss.slammer.landing().distance_to(host_boss.slammer.landing()) < 1.0,
		"mesmo ponto de queda")
	check((client.region as Region).ground_effects.get_child_count() > 0, "aviso no chão do cliente")


## Metade da vida: o chefe se enfurece (salto mais rápido, barra laranja); curado, volta ao normal.
func test_boss_enrages_at_half_health() -> void:
	var game := await _game_at_the_boss()
	var boss := _boss(game)
	boss.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED
	var bar: BossBar = game.find_children("*", "BossBar", true, false)[0]
	check(boss.phase == 1 and boss.slammer.attack == boss.data.slam, "começa na fase 1")
	_hurt(boss, boss.health.max_health / 2)
	await physics_frames(1)
	check(boss.phase == 2 and boss.slammer.attack == boss.data.phase_two_slam,
		"metade da vida: fase 2, salto da fúria")
	check(boss.data.phase_two_slam.windup < boss.data.slam.windup, "o salto da fúria é mais rápido")
	check(bar._fill.color == UiStyle.ENRAGED, "a barra fica laranja")
	boss.health.restore_full()
	check(boss.phase == 1 and boss.slammer.attack == boss.data.slam, "curado (voltou para casa): fase 1")


## Na fase 2, cada queda solta filhotes (no máximo 4 vivos); eles somem quando o chefe morre.
func test_enraged_slam_spawns_minions_that_vanish_with_the_boss() -> void:
	var game := await _game_at_the_boss()
	var boss := _boss(game)
	var spawner := game._spawner as EntitySpawner
	_hurt(boss, boss.health.max_health / 2)
	var before := _monsters(game)
	check(await wait_until(func() -> bool: return _monsters(game) > before, 240),
		"a queda soltou filhotes")
	await physics_frames(1)
	check(_monsters(game) == before + boss.data.minions_per_slam,
		"%d filhotes" % (_monsters(game) - before))
	boss.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED
	for i in 3:
		spawner._on_boss_landed(boss, game.region, boss.position)
	check(_monsters(game) == before + boss.data.max_minions, "no máximo %d vivos" % boss.data.max_minions)
	var drops_before := pickups(game).size()
	var minion: Monster = spawner._minions[boss.entity_id][0]
	_hurt(minion, minion.health.max_health)
	await physics_frames(2)
	check(pickups(game).size() == drops_before, "filhote não deixa drops")
	_hurt(boss, boss.health.max_health)
	check(await wait_until(func() -> bool: return _monsters(game) == before - 1, 120),
		"o chefe morreu e os filhotes sumiram")


## Filhotes seguem o chefe: perseguem o alvo dele mesmo além do raio de percepção de um slime
## comum (antes, quem corria um pouco deixava os filhotes parados e lutava com o chefe sozinho).
func test_minions_chase_the_boss_target() -> void:
	var game := await _game_at_the_boss()
	var boss := _boss(game)
	var boss_brain: MonsterBrain = boss.get_node("Brain")
	boss_brain.process_mode = Node.PROCESS_MODE_DISABLED
	_hurt(boss, boss.health.max_health / 2)
	var spawner := game._spawner as EntitySpawner
	spawner._on_boss_landed(boss, game.region, boss.position)
	var minion: Monster = spawner._minions[boss.entity_id][0]
	var player := _player(game)
	player.position = minion.position + Iso.ground_to_screen(Vector2(minion.data.aggro_radius + 40.0, 0))
	player.reset_physics_interpolation()
	boss_brain._target = player  # o chefe persegue o jogador
	var start := Iso.ground_distance(minion.position, player.position)
	await physics_frames(90)
	check(Iso.ground_distance(minion.position, player.position) < start - 30.0,
		"o filhote foi atrás do alvo do chefe (%.0f → %.0f)" % [start,
		Iso.ground_distance(minion.position, player.position)])


## Coop: os filhotes chegam ao cliente; dados de filhote forjados (chefe que não existe ou que
## não tem filhotes) são recusados.
func test_client_gets_minions_and_refuses_forged_ones() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT + 1)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT + 1)
	check(await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null),
		"cliente conectou")
	host._travel(client.local_player_id(), &"forest", &"to_meadow")
	host._travel(1, &"forest", &"to_meadow")
	check(await wait_until(func() -> bool:
		return client.region and client.region.region_id == &"forest" and _boss(client) != null),
		"o cliente está na floresta")
	calm_monsters(host)
	var boss := _boss(host)
	_hurt(boss, boss.health.max_health / 2)
	var before := _monsters(client)
	(host._spawner as EntitySpawner)._on_boss_landed(boss, host.region, boss.position)
	check(await wait_until(func() -> bool:
		return _monsters(client) == before + boss.data.minions_per_slam, 60), "filhotes no cliente")
	var spawner := client._spawner as EntitySpawner
	var region := client.region as Region
	var slime := first_monster(client)
	for forged: Dictionary in [
			{"summoner": 999999}, {"summoner": slime.entity_id}, {"summoner": _boss(client).entity_id,
			"position": Vector2(INF, 0)}]:
		var data := {"kind": EntitySpawner.Kind.MINION, "entity_id": 777777,
			"summoner": _boss(client).entity_id, "position": Vector2(10, 10), "health_multiplier": 1.0}
		data.merge(forged, true)
		check(spawner._valid_kind(data, region) == -1, "filhote forjado recusado (%s)" % [forged])


func _hurt(target: Character, amount: int) -> void:
	target.health.apply_damage(DamageInfo.create(amount, Vector2.RIGHT, 0.0, 0, 1))


func _monsters(game: Node) -> int:
	return (game.region as Region).entities.get_children().filter(func(n: Node) -> bool:
		return n is Monster and n.is_alive() and not n.is_queued_for_deletion()).size()


## Jogo offline na floresta, com o jogador a meia distância do chefe e as outras criaturas paradas.
func _game_at_the_boss() -> Node:
	var game := start_game()
	game._travel(1, &"forest", &"to_meadow")
	await physics_frames(2)
	calm_monsters(game)
	var boss := _boss(game)
	boss.get_node("Brain").process_mode = Node.PROCESS_MODE_INHERIT
	var player := _player(game)
	player.position = boss.position + Iso.ground_to_screen(SLAM_OFFSET)
	player.reset_physics_interpolation()
	return game


func _boss(game: Node) -> Monster:
	for node in (game.region as Region).entities.get_children():
		if node is Monster and node.data.is_boss:
			return node
	return null


func _player(game: Node) -> Character:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) as Character
