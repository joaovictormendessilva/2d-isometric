extends TestCase
## Drops no chão: pousam só em chão andável e alcançável, e o dono precisa ir até eles.

const TerrainAtlas := preload("res://tools/terrain_atlas.gd")
const SAMPLES := 400
## Pegada típica de criatura (o slime usa 6).
const CREATURE_RADIUS := 6.0


func test_walkable_query_sees_water_and_props() -> void:
	var game := start_game()
	var region: Region = game.region
	var space := region.get_world_2d().direct_space_state
	await physics_frames(2)
	var water := _first_water_tile(region)
	check(not GroundQuery.is_walkable(space, water, 2.0), "água não é andável")
	var tree := _first_child_named(region, "Tree")
	check(tree != null and not GroundQuery.is_walkable(space, tree.position, 2.0),
		"o pé da árvore não é andável")
	check(GroundQuery.is_walkable(space, region.get_spawn_position(), 2.0),
		"o ponto de entrada é andável")


## Centenas de mortes em pontos sorteados pelo mapa (muitos perto de água, árvores e pedras):
## nenhum drop pousa em lugar proibido ou inalcançável.
func test_drop_spots_are_always_walkable_and_reachable() -> void:
	var game := start_game()
	var region: Region = game.region
	var space := region.get_world_2d().direct_space_state
	await physics_frames(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bounds := region.camera_bounds
	var tested := 0
	var bad := PackedStringArray()
	while tested < SAMPLES:
		var origin := Vector2(rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y))
		if not GroundQuery.is_walkable(space, origin, CREATURE_RADIUS):
			continue  # criaturas só morrem onde conseguem estar
		tested += 1
		var spot := GroundQuery.find_drop_spot(space, origin, rng, EntitySpawner.DROP_DISTANCE_MIN,
			EntitySpawner.DROP_DISTANCE_MAX, EntitySpawner.DROP_CLEARANCE)
		if not GroundQuery.is_walkable(space, spot, EntitySpawner.DROP_CLEARANCE) \
				or not GroundQuery.is_reachable(space, origin, spot) \
				or Iso.ground_distance(origin, spot) > EntitySpawner.DROP_DISTANCE_MAX + 0.01:
			bad.append("%s -> %s" % [origin, spot])
	check(bad.is_empty(), "%d de %d drops em lugar ruim: %s" % [bad.size(), SAMPLES, bad.slice(0, 3)])


## O item cai no chão: não vai direto para o inventário, e o dono precisa chegar perto.
func test_drop_waits_on_the_ground_for_its_owner() -> void:
	var game := start_game()
	var session: GameSession = game.session
	var player := session.get_player_entity(game.local_player_id()) as Character
	var monster := first_monster(game)
	monster.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED
	player.position = monster.position  # bem em cima de onde a criatura morre
	monster.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, game.local_player_id()))
	await physics_frames(2)
	var pickup: Pickup = pickups(game)[0]
	check(pickup.position.distance_to(monster.position) > 1.0, "o item saltou para longe da criatura")
	check(session.get_inventory(game.local_player_id()).count(&"gel") == 0, "não foi direto para o inventário")

	player.position = pickup.position + Iso.ground_to_screen(Vector2(player.stats.pickup_radius + 10.0, 0))
	await physics_frames(60)
	check(is_instance_valid(pickup), "parado longe, o jogador não pega o item")

	player.position = pickup.position
	await physics_frames(3)
	check(not is_instance_valid(pickup), "ao passar por cima, pega")
	check(session.get_inventory(game.local_player_id()).count(&"gel") > 0, "item no inventário")


## Pousado, o item balança de pixel inteiro em pixel inteiro (com a câmera em meio pixel, alturas
## quebradas como 4,49 e 4,51 caíam no mesmo pixel da tela e o item parecia parado).
func test_landed_drop_bobs_by_whole_pixels() -> void:
	var game := start_game()
	var player := (game.session as GameSession).get_player_entity(game.local_player_id()) as Character
	var monster := first_monster(game)
	monster.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED
	monster.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, game.local_player_id()))
	await physics_frames(2)
	var pickup: Pickup = pickups(game)[0]
	pickup.position += Vector2(0.37, 0.37)  # meio do pixel: o caso que travava
	player.position = pickup.position + Iso.ground_to_screen(Vector2(player.pickup_radius() + 40.0, 0))
	await physics_frames(roundi(Pickup.POP_TIME * 60) + 1)
	var heights := {}
	var whole := true
	for i in roundi(60.0 / Pickup.BOB_HZ):
		var y := pickup.position.y + pickup._sprite.position.y
		whole = whole and is_equal_approx(y, roundf(y))
		heights[roundi(y)] = true
		await tree.physics_frame
	check(whole, "a imagem fica sempre num pixel inteiro do mundo")
	check(heights.size() >= 2, "o item balança (%d alturas num ciclo)" % heights.size())


## O ímã vem dos atributos do jogador: um raio maior (futuros equipamentos) puxa de mais longe.
func test_larger_pickup_radius_pulls_from_farther() -> void:
	var game := start_game()
	var session: GameSession = game.session
	var player := session.get_player_entity(game.local_player_id()) as Character
	player.stats = player.stats.duplicate()  # só este jogador, sem mexer no recurso compartilhado
	player.stats.pickup_radius = 60.0
	var monster := first_monster(game)
	monster.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED
	monster.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, game.local_player_id()))
	await physics_frames(2)
	var pickup: Pickup = pickups(game)[0]
	player.position = pickup.position + Iso.ground_to_screen(Vector2(40.0, 0))
	await physics_frames(90)
	check(not is_instance_valid(pickup), "a 40 px, um ímã de 60 px trouxe o item")


func _first_water_tile(region: Region) -> Vector2:
	var water := TerrainAtlas.coords(&"water")
	for cell in region.ground.get_used_cells():
		if region.ground.get_cell_atlas_coords(cell) == water:
			return region.ground.map_to_local(cell)
	return Vector2.INF


func _first_child_named(region: Region, prefix: String) -> Node2D:
	for node in region.entities.get_children():
		if node.name.begins_with(prefix):
			return node
	return null
