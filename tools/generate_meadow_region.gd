extends SceneTree
## Gera o TileSet isométrico provisório e a região de teste "meadow" (Prado) da Etapa C.
## O mapa é procedural com semente fixa: rodar de novo produz o mesmo resultado.
## ATENÇÃO: rodar de novo SOBRESCREVE meadow.tscn (edições manuais nele seriam perdidas).
##
## Uso (depois de generate_placeholder_art.gd e --import):
##   Godot --headless --path . -s res://tools/generate_meadow_region.gd

const TerrainAtlas := preload("res://tools/terrain_atlas.gd")

const REGION_SCRIPT := "res://scenes/regions/region.gd"
const REGION_PATH := "res://scenes/regions/meadow/meadow.tscn"
const TREE_SCENE := "res://scenes/props/tree.tscn"
const ROCK_SCENE := "res://scenes/props/rock.tscn"
const SLIME_SCENE := "res://scenes/actors/monsters/slime.tscn"
const SPAWN_POINT_SCRIPT := "res://scenes/regions/monster_spawn_point.gd"

const SEED := 7
## Área retangular da região em pixels de tela (2,5 x 2,7 telas de 640x360).
const REGION_RECT := Rect2(0, 0, 1600, 960)
## Largura mínima do anel de água na borda, no plano do chão.
const SHORE_WIDTH := 56.0
## Raio livre (sem água, árvores ou pedras) ao redor do ponto de entrada, no plano do chão.
const SPAWN_CLEAR_RADIUS := 140.0
const MIN_PROP_DISTANCE := 22.0
## Chance de uma célula de grama receber árvore / pedra.
const TREE_CHANCE := 0.05
const ROCK_CHANCE := 0.025
## Pontos de criaturas: quantidade, faixa de distância do ponto de entrada e espaçamento (chão).
const MONSTER_SPAWN_COUNT := 8
const MONSTER_SPAWN_DISTANCE := Vector2(220.0, 900.0)
const MONSTER_SPAWN_SPACING := 150.0
## Os primeiros pontos ficam perto da entrada, para o combate começar sem longas caminhadas.
const NEAR_MONSTER_SPAWNS := 2
const NEAR_MONSTER_DISTANCE := Vector2(150.0, 260.0)
## Pontos de coleta: [cena, quantidade, quantos perto da entrada].
const RESOURCE_NODES := [
	["res://scenes/gathering/lumber_tree.tscn", 12, 2],
	["res://scenes/gathering/copper_vein.tscn", 8, 1],
	["res://scenes/gathering/old_oak.tscn", 3, 0],
]
const NEAR_RESOURCE_DISTANCE := Vector2(90.0, 220.0)
const RESOURCE_DISTANCE := Vector2(200.0, 900.0)
const RESOURCE_SPACING := 60.0


func _initialize() -> void:
	var tile_set := _build_tile_set()
	_check(ResourceSaver.save(tile_set, TerrainAtlas.TILESET_PATH), TerrainAtlas.TILESET_PATH)
	# Recarrega para que a região referencie o arquivo .tres (e não uma cópia embutida).
	tile_set = load(TerrainAtlas.TILESET_PATH)
	var region := _build_region(tile_set)
	var packed := PackedScene.new()
	_check(packed.pack(region), "pack")
	_check(ResourceSaver.save(packed, REGION_PATH), REGION_PATH)
	region.free()
	quit(0)


func _check(err: Error, what: String) -> void:
	if err != OK:
		push_error("Falha em %s (%d)" % [what, err])
		quit(1)
	else:
		print("[gen] ok: %s" % what)


func _build_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Iso.TILE_SIZE
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, PhysicsLayers.WORLD)
	ts.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = load(TerrainAtlas.TEXTURE_PATH)
	source.texture_region_size = Iso.TILE_SIZE
	ts.add_source(source, TerrainAtlas.SOURCE_ID)

	var half := Vector2(Iso.TILE_SIZE) / 2.0
	var diamond := PackedVector2Array([
		Vector2(0, -half.y), Vector2(half.x, 0), Vector2(0, half.y), Vector2(-half.x, 0)])
	for tile in TerrainAtlas.COLUMNS:
		source.create_tile(TerrainAtlas.coords(tile))
		if tile in TerrainAtlas.BLOCKING:
			var data := source.get_tile_data(TerrainAtlas.coords(tile), 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, diamond)
	return ts


func _build_region(tile_set: TileSet) -> Node2D:
	var region := Node2D.new()
	region.name = "Meadow"
	region.set_script(load(REGION_SCRIPT))
	region.set(&"region_id", &"meadow")
	region.set(&"camera_bounds", REGION_RECT)

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tile_set
	_add_owned(region, ground, region)

	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	_add_owned(region, entities, region)

	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = REGION_RECT.get_center()
	_add_owned(region, spawn, region)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var grass_cells := _paint_ground(ground, spawn.position, rng)
	var props := _place_props(region, ground, entities, grass_cells, spawn.position, rng)
	# Semente própria: mudar as criaturas não muda o resto do mapa.
	var monster_rng := RandomNumberGenerator.new()
	monster_rng.seed = SEED + 2
	var monsters := _place_monster_spawns(region, ground, grass_cells, spawn.position, props, monster_rng)
	var resource_rng := RandomNumberGenerator.new()
	resource_rng.seed = SEED + 3
	_place_resource_nodes(entities, region, ground, grass_cells, spawn.position, props + monsters,
		resource_rng)
	return region


func _add_owned(parent: Node, child: Node, scene_owner: Node) -> void:
	parent.add_child(child, true)
	child.owner = scene_owner


## Pinta todas as células cujo centro cai no retângulo da região. Retorna as de grama.
func _paint_ground(ground: TileMapLayer, spawn: Vector2, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var lakes := FastNoiseLite.new()
	lakes.seed = SEED
	lakes.frequency = 0.004
	var paths := FastNoiseLite.new()
	paths.seed = SEED + 1
	paths.frequency = 0.0018

	var grass_cells: Array[Vector2i] = []
	var half := Vector2(Iso.TILE_SIZE) / 2.0
	var bounds := REGION_RECT.grow_individual(half.x, half.y, half.x, half.y)
	# A grade em losango (DIAMOND_DOWN) é girada; varremos uma janela folgada de células.
	var span := ceili(REGION_RECT.size.x / half.x) + ceili(REGION_RECT.size.y / half.y)
	for y in range(-span, span):
		for x in range(-span, span):
			var cell := Vector2i(x, y)
			var p := ground.map_to_local(cell)
			if not bounds.has_point(p):
				continue
			var tile := _pick_tile(p, spawn, lakes, paths, rng)
			ground.set_cell(cell, TerrainAtlas.SOURCE_ID, TerrainAtlas.coords(tile))
			if tile in TerrainAtlas.GRASS:
				grass_cells.append(cell)
	return grass_cells


func _pick_tile(p: Vector2, spawn: Vector2, lakes: FastNoiseLite, paths: FastNoiseLite,
		rng: RandomNumberGenerator) -> StringName:
	var g := Iso.screen_to_ground(p)
	var edge := minf(minf(p.x - REGION_RECT.position.x, REGION_RECT.end.x - p.x),
		minf(p.y - REGION_RECT.position.y, REGION_RECT.end.y - p.y) * Iso.Y_SCALE)
	var wobble := (lakes.get_noise_2d(g.x * 3.0, g.y * 3.0) + 1.0) * 14.0
	if edge < SHORE_WIDTH + wobble:
		return &"water"
	var near_spawn := Iso.ground_distance(p, spawn) < SPAWN_CLEAR_RADIUS
	if not near_spawn and lakes.get_noise_2d(g.x, g.y) > 0.42:
		return &"water"
	if absf(paths.get_noise_2d(g.x, g.y)) < 0.06:
		return &"dirt"
	var r := rng.randf()
	if r < 0.6:
		return TerrainAtlas.GRASS[0]
	return TerrainAtlas.GRASS[1] if r < 0.85 else TerrainAtlas.GRASS[2]


func _place_props(region: Node2D, ground: TileMapLayer, entities: Node2D,
		grass_cells: Array[Vector2i], spawn: Vector2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var tree_scene: PackedScene = load(TREE_SCENE)
	var rock_scene: PackedScene = load(ROCK_SCENE)
	var placed: Array[Vector2] = []
	var counts := {"trees": 0, "rocks": 0}
	for cell in grass_cells:
		var r := rng.randf()
		if r >= TREE_CHANCE + ROCK_CHANCE or not _surrounded_by_land(ground, cell):
			continue
		var p := (ground.map_to_local(cell) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-3, 3))).round()
		if Iso.ground_distance(p, spawn) < SPAWN_CLEAR_RADIUS:
			continue
		if placed.any(func(q: Vector2) -> bool: return Iso.ground_distance(p, q) < MIN_PROP_DISTANCE):
			continue
		var is_tree := r < TREE_CHANCE
		var prop: Node2D = (tree_scene if is_tree else rock_scene).instantiate()
		prop.position = p
		_add_owned(entities, prop, region)
		placed.append(p)
		counts["trees" if is_tree else "rocks"] += 1
	print("[gen] props: %s" % counts)
	return placed


## A célula e as 8 vizinhas são terreno pisável e existente?
func _surrounded_by_land(ground: TileMapLayer, cell: Vector2i) -> bool:
	var blocked: Array[Vector2i] = [Vector2i(-1, -1)]  # (-1, -1) = célula vazia
	for tile in TerrainAtlas.BLOCKING:
		blocked.append(TerrainAtlas.coords(tile))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if ground.get_cell_atlas_coords(cell + Vector2i(dx, dy)) in blocked:
				return false
	return true


## Pontos de criaturas em grama firme, longe do ponto de entrada, dos objetos e entre si.
## Retorna as posições.
func _place_monster_spawns(region: Node2D, ground: TileMapLayer, grass_cells: Array[Vector2i],
		spawn: Vector2, props: Array[Vector2], rng: RandomNumberGenerator) -> Array[Vector2]:
	var container := Node2D.new()
	container.name = "MonsterSpawns"
	_add_owned(region, container, region)
	var placed := _pick_spots(ground, _shuffled(grass_cells, rng), spawn, props, MONSTER_SPAWN_COUNT,
		NEAR_MONSTER_SPAWNS, NEAR_MONSTER_DISTANCE, MONSTER_SPAWN_DISTANCE, MONSTER_SPAWN_SPACING)
	for p in placed:
		var point := Marker2D.new()
		point.set_script(load(SPAWN_POINT_SCRIPT))
		point.position = p
		point.set(&"monster_scene", load(SLIME_SCENE))
		point.set(&"respawn_time", rng.randf_range(15.0, 25.0))
		_add_owned(container, point, region)
	print("[gen] monster spawns: %d" % placed.size())
	return placed


## Pontos de coleta (`RESOURCE_NODES`) em grama firme, longe de objetos, criaturas e entre si;
## alguns de cada tipo perto da entrada, para a coleta começar logo.
func _place_resource_nodes(entities: Node2D, region: Node2D, ground: TileMapLayer,
		grass_cells: Array[Vector2i], spawn: Vector2, avoid: Array[Vector2],
		rng: RandomNumberGenerator) -> void:
	var candidates := _shuffled(grass_cells, rng)
	var taken := avoid.duplicate()
	for entry: Array in RESOURCE_NODES:
		var scene: PackedScene = load(entry[0])
		var placed := _pick_spots(ground, candidates, spawn, taken, entry[1], entry[2],
			NEAR_RESOURCE_DISTANCE, RESOURCE_DISTANCE, RESOURCE_SPACING)
		for p in placed:
			var node: Node2D = scene.instantiate()
			node.position = p
			_add_owned(entities, node, region)
		taken.append_array(placed)
		print("[gen] %s: %d" % [String(entry[0]).get_file(), placed.size()])


## Até `count` posições de células da lista (na ordem dada) em grama firme, longe de `avoid`
## e entre si (`spacing`, no chão). As `near_count` primeiras ficam a `near_limits` do ponto
## de entrada; as outras, a `far_limits`. Não sorteia nada: a ordem vem de quem chama.
func _pick_spots(ground: TileMapLayer, cells: Array[Vector2i], spawn: Vector2,
		avoid: Array[Vector2], count: int, near_count: int, near_limits: Vector2,
		far_limits: Vector2, spacing: float) -> Array[Vector2]:
	var placed: Array[Vector2] = []
	for cell: Vector2i in cells + cells:  # 1ª passada: perto; 2ª: o resto
		if placed.size() >= count:
			break
		var p := ground.map_to_local(cell)
		var limits := near_limits if placed.size() < near_count else far_limits
		var from_spawn := Iso.ground_distance(p, spawn)
		if from_spawn < limits.x or from_spawn > limits.y:
			continue
		if not _surrounded_by_land(ground, cell):
			continue
		if avoid.any(func(q: Vector2) -> bool: return Iso.ground_distance(p, q) < MIN_PROP_DISTANCE):
			continue
		if placed.any(func(q: Vector2) -> bool: return Iso.ground_distance(p, q) < spacing):
			continue
		placed.append(p)
	return placed


## Cópia embaralhada com a semente dada (`Array.shuffle` usa o sorteio global, não determinístico).
func _shuffled(cells: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = cells.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result
