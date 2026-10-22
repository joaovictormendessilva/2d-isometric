extends TestCase
## Região inicial: ponto de entrada livre, objetos em terra firme e bordas fechadas.

const TerrainAtlas := preload("res://tools/terrain_atlas.gd")


func test_spawn_is_on_walkable_ground() -> void:
	var game := start_game()
	var region: Region = game.region
	var tile := _tile_at(region, region.get_spawn_position())
	check(tile != Vector2i(-1, -1), "há chão no ponto de entrada")
	check(not _is_blocking(tile), "ponto de entrada não é água")


func test_props_stand_on_land() -> void:
	var game := start_game()
	var region: Region = game.region
	var props := region.entities.get_children().filter(func(n: Node) -> bool: return n is StaticBody2D)
	check(props.size() > 20, "região tem árvores e pedras (%d)" % props.size())
	for prop: Node2D in props:
		check(not _is_blocking(_tile_at(region, prop.position)), "%s fora da água" % prop.name)


func test_player_cannot_leave_region() -> void:
	var game := start_game()
	var region: Region = game.region
	var player := (game.session as GameSession).get_player_entity(game.LOCAL_PLAYER_ID) as Character
	var bounds := region.camera_bounds
	for angle_step in 8:
		player.position = region.get_spawn_position()
		player.reset_physics_interpolation()
		player.set_move_intent(Vector2.from_angle(TAU * angle_step / 8.0))
		await physics_frames(600)  # 10 s andando: mais que o suficiente para chegar à borda
		check(bounds.has_point(player.position),
			"jogador ficou dentro da região indo na direção %d (pos %s)" % [angle_step, player.position])


func _tile_at(region: Region, screen_position: Vector2) -> Vector2i:
	return region.ground.get_cell_atlas_coords(region.ground.local_to_map(screen_position))


func _is_blocking(atlas_coords: Vector2i) -> bool:
	return TerrainAtlas.BLOCKING.any(func(t: StringName) -> bool: return TerrainAtlas.coords(t) == atlas_coords)
