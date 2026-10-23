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
