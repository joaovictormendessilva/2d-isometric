extends SceneTree
## Gera o TileSet isométrico provisório e as regiões (`REGIONS`): campina e floresta. Cada mapa
## é procedural com semente fixa: rodar de novo produz o mesmo resultado (os nomes dos pontos
## de coleta são a chave deles no save — mudar a semente ou a ordem muda o mapa salvo).
## ATENÇÃO: rodar de novo SOBRESCREVE as cenas (edições manuais nelas seriam perdidas).
##
## Uso (depois de generate_placeholder_art.gd e --import):
##   Godot --headless --path . -s res://tools/generate_regions.gd

const TerrainAtlas := preload("res://tools/terrain_atlas.gd")

const REGION_SCRIPT := "res://scenes/regions/region.gd"
const TREE_SCENE := "res://scenes/props/tree.tscn"
const ROCK_SCENE := "res://scenes/props/rock.tscn"
const SLIME_SCENE := "res://scenes/actors/monsters/slime.tscn"
const SPAWN_POINT_SCRIPT := "res://scenes/regions/monster_spawn_point.gd"
const PASSAGE_SCENE := "res://scenes/regions/passage.tscn"
const LUMBER_TREE := "res://scenes/gathering/lumber_tree.tscn"
const COPPER_VEIN := "res://scenes/gathering/copper_vein.tscn"
const OLD_OAK := "res://scenes/gathering/old_oak.tscn"
const MERCHANT := "res://scenes/npc/merchant.tscn"

enum Side { EAST, WEST }

## Área de cada região em pixels de tela (2,5 x 2,7 telas de 640x360).
const REGION_RECT := Rect2(0, 0, 1600, 960)
## Largura mínima do anel de água na borda, no plano do chão.
const SHORE_WIDTH := 56.0
## Raio livre (sem água, árvores ou pedras) ao redor do ponto de entrada, no plano do chão.
const SPAWN_CLEAR_RADIUS := 140.0
const MIN_PROP_DISTANCE := 22.0
const MONSTER_SPAWN_SPACING := 150.0
## Os primeiros pontos ficam perto da entrada, para o combate começar sem longas caminhadas.
const NEAR_MONSTER_SPAWNS := 2
const NEAR_MONSTER_DISTANCE := Vector2(150.0, 260.0)
const NEAR_RESOURCE_DISTANCE := Vector2(90.0, 220.0)
const RESOURCE_SPACING := 60.0
## Caminho de terra até a passagem: comprimento (da borda para dentro, px de tela) e meia altura.
const CORRIDOR_LENGTH := 130.0
const CORRIDOR_HALF_HEIGHT := 24.0
## Gatilho da passagem: distância da borda (a parede dela fica entre o gatilho e a borda).
const PASSAGE_INSET := 22.0

## Receita de cada região. `spawn`: ponto de entrada (null = centro). `resources`: [cena,
## quantidade, quantos perto da entrada]. `far`: distância máxima (chão) da entrada para
## criaturas e pontos de coleta. `passages`: [id, lado, y, região destino, passagem destino].
## `npcs`: [cena, posição em relação à entrada (px de tela)], dentro da área livre da entrada.
var REGIONS := [
	{
		"id": &"meadow", "node": "Meadow", "path": "res://scenes/regions/meadow/meadow.tscn",
		"seed": 7, "spawn": null, "ambient": Color.WHITE,
		"tree_chance": 0.05, "rock_chance": 0.025, "lake_threshold": 0.42,
		"monsters": 8, "far": 900.0,
		"resources": [[LUMBER_TREE, 12, 2], [COPPER_VEIN, 8, 1], [OLD_OAK, 3, 0]],
		"passages": [[&"to_forest", Side.EAST, 480.0, &"forest", &"to_meadow"]],
		"npcs": [[MERCHANT, Vector2(-72, -20)]],
	},
	{
		# Floresta densa (João, F2): mata fechada e mais escura, mais carvalhos antigos.
		"id": &"forest", "node": "Forest", "path": "res://scenes/regions/forest/forest.tscn",
		"seed": 11, "spawn": Vector2(160, 480), "ambient": Color(0.68, 0.8, 0.72),
		"tree_chance": 0.13, "rock_chance": 0.02, "lake_threshold": 0.5,
		"monsters": 10, "far": 1500.0,
		"resources": [[OLD_OAK, 8, 1], [LUMBER_TREE, 8, 1], [COPPER_VEIN, 3, 0]],
		"passages": [[&"to_meadow", Side.WEST, 480.0, &"meadow", &"to_forest"]],
	},
]

## Receita da região sendo gerada.
var _r: Dictionary


func _initialize() -> void:
	var tile_set := _build_tile_set()
	_check(ResourceSaver.save(tile_set, TerrainAtlas.TILESET_PATH), TerrainAtlas.TILESET_PATH)
	# Recarrega para que a região referencie o arquivo .tres (e não uma cópia embutida).
	tile_set = load(TerrainAtlas.TILESET_PATH)
	for recipe: Dictionary in REGIONS:
		_r = recipe
		var region := _build_region(tile_set)
		var packed := PackedScene.new()
		_check(packed.pack(region), "pack %s" % recipe["id"])
		DirAccess.make_dir_recursive_absolute(String(recipe["path"]).get_base_dir())
		_check(ResourceSaver.save(packed, recipe["path"]), recipe["path"])
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
	region.name = _r["node"]
	region.set_script(load(REGION_SCRIPT))
	region.set(&"region_id", _r["id"])
	region.set(&"camera_bounds", REGION_RECT)
	region.set(&"ambient", _r["ambient"])

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
	spawn.position = _r["spawn"] if _r["spawn"] != null else REGION_RECT.get_center()
	_add_owned(region, spawn, region)

	var seed_value: int = _r["seed"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var grass_cells := _paint_ground(ground, spawn.position, rng)
	var props := _place_props(region, ground, entities, grass_cells, spawn.position, rng)
	# Semente própria: mudar as criaturas não muda o resto do mapa.
	var monster_rng := RandomNumberGenerator.new()
	monster_rng.seed = seed_value + 2
	var monsters := _place_monster_spawns(region, ground, grass_cells, spawn.position, props, monster_rng)
	var resource_rng := RandomNumberGenerator.new()
	resource_rng.seed = seed_value + 3
	_place_resource_nodes(entities, region, ground, grass_cells, spawn.position, props + monsters,
		resource_rng)
	# Por último: abrir caminho não mexe no sorteio do resto do mapa.
	_carve_passages(region, ground)
	_place_npcs(entities, region, spawn.position)
	return region


func _add_owned(parent: Node, child: Node, scene_owner: Node) -> void:
	parent.add_child(child, true)
	child.owner = scene_owner


## Pinta todas as células cujo centro cai no retângulo da região. Retorna as de grama.
func _paint_ground(ground: TileMapLayer, spawn: Vector2, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var seed_value: int = _r["seed"]
	var lakes := FastNoiseLite.new()
	lakes.seed = seed_value
	lakes.frequency = 0.004
	var paths := FastNoiseLite.new()
	paths.seed = seed_value + 1
	paths.frequency = 0.0018

	var grass_cells: Array[Vector2i] = []
	for cell in _region_cells(ground):
		var tile := _pick_tile(ground.map_to_local(cell), spawn, lakes, paths, rng)
		ground.set_cell(cell, TerrainAtlas.SOURCE_ID, TerrainAtlas.coords(tile))
		if tile in TerrainAtlas.GRASS:
			grass_cells.append(cell)
	return grass_cells


## Células cujo centro cai no retângulo da região (com meia célula de folga), em ordem fixa.
func _region_cells(ground: TileMapLayer) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var half := Vector2(Iso.TILE_SIZE) / 2.0
	var bounds := REGION_RECT.grow_individual(half.x, half.y, half.x, half.y)
	# A grade em losango (DIAMOND_DOWN) é girada; varremos uma janela folgada de células.
	var span := ceili(REGION_RECT.size.x / half.x) + ceili(REGION_RECT.size.y / half.y)
	for y in range(-span, span):
		for x in range(-span, span):
			if bounds.has_point(ground.map_to_local(Vector2i(x, y))):
				cells.append(Vector2i(x, y))
	return cells


func _pick_tile(p: Vector2, spawn: Vector2, lakes: FastNoiseLite, paths: FastNoiseLite,
		rng: RandomNumberGenerator) -> StringName:
	var g := Iso.screen_to_ground(p)
	var edge := minf(minf(p.x - REGION_RECT.position.x, REGION_RECT.end.x - p.x),
		minf(p.y - REGION_RECT.position.y, REGION_RECT.end.y - p.y) * Iso.Y_SCALE)
	var wobble := (lakes.get_noise_2d(g.x * 3.0, g.y * 3.0) + 1.0) * 14.0
	if edge < SHORE_WIDTH + wobble:
		return &"water"
	var near_spawn := Iso.ground_distance(p, spawn) < SPAWN_CLEAR_RADIUS
	if not near_spawn and lakes.get_noise_2d(g.x, g.y) > _r["lake_threshold"]:
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
	var tree_chance: float = _r["tree_chance"]
	var rock_chance: float = _r["rock_chance"]
	var placed: Array[Vector2] = []
	var counts := {"trees": 0, "rocks": 0}
	for cell in grass_cells:
		var r := rng.randf()
		if r >= tree_chance + rock_chance or not _surrounded_by_land(ground, cell):
			continue
		var p := (ground.map_to_local(cell) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-3, 3))).round()
		if Iso.ground_distance(p, spawn) < SPAWN_CLEAR_RADIUS:
			continue
		if placed.any(func(q: Vector2) -> bool: return Iso.ground_distance(p, q) < MIN_PROP_DISTANCE):
			continue
		var is_tree := r < tree_chance
		var prop: Node2D = (tree_scene if is_tree else rock_scene).instantiate()
		prop.position = p
		_add_owned(entities, prop, region)
		placed.append(p)
		counts["trees" if is_tree else "rocks"] += 1
	print("[gen] %s props: %s" % [_r["id"], counts])
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
	var placed := _pick_spots(ground, _shuffled(grass_cells, rng), spawn, props, _r["monsters"],
		NEAR_MONSTER_SPAWNS, NEAR_MONSTER_DISTANCE, Vector2(220.0, _r["far"]), MONSTER_SPAWN_SPACING)
	for p in placed:
		var point := Marker2D.new()
		point.set_script(load(SPAWN_POINT_SCRIPT))
		point.position = p
		point.set(&"monster_scene", load(SLIME_SCENE))
		point.set(&"respawn_time", rng.randf_range(15.0, 25.0))
		_add_owned(container, point, region)
	print("[gen] %s monster spawns: %d" % [_r["id"], placed.size()])
	return placed


## Pontos de coleta (`resources` da receita) em grama firme, longe de objetos, criaturas e entre
## si; alguns de cada tipo perto da entrada, para a coleta começar logo.
func _place_resource_nodes(entities: Node2D, region: Node2D, ground: TileMapLayer,
		grass_cells: Array[Vector2i], spawn: Vector2, avoid: Array[Vector2],
		rng: RandomNumberGenerator) -> void:
	var candidates := _shuffled(grass_cells, rng)
	var taken := avoid.duplicate()
	for entry: Array in _r["resources"]:
		var scene: PackedScene = load(entry[0])
		var placed := _pick_spots(ground, candidates, spawn, taken, entry[1], entry[2],
			NEAR_RESOURCE_DISTANCE, Vector2(200.0, _r["far"]), RESOURCE_SPACING)
		for p in placed:
			var node: Node2D = scene.instantiate()
			node.position = p
			_add_owned(entities, node, region)
		taken.append_array(placed)
		print("[gen] %s %s: %d" % [_r["id"], String(entry[0]).get_file(), placed.size()])


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


## Cada passagem: caminho de terra da borda para dentro (atravessa o anel de água) e a cena da
## passagem no fim dele. Tira do caminho o que tiver caído nele (objetos, pontos, criaturas).
func _carve_passages(region: Node2D, ground: TileMapLayer) -> void:
	var container := Node2D.new()
	container.name = "Passages"
	_add_owned(region, container, region)
	for entry: Array in _r["passages"]:
		var side: Side = entry[1]
		var y: float = entry[2]
		var corridor := Rect2(REGION_RECT.end.x - CORRIDOR_LENGTH if side == Side.EAST
			else REGION_RECT.position.x - CORRIDOR_HALF_HEIGHT, y - CORRIDOR_HALF_HEIGHT,
			CORRIDOR_LENGTH + CORRIDOR_HALF_HEIGHT, CORRIDOR_HALF_HEIGHT * 2.0)
		for cell in _region_cells(ground):
			if corridor.has_point(ground.map_to_local(cell)):
				ground.set_cell(cell, TerrainAtlas.SOURCE_ID, TerrainAtlas.coords(&"dirt"))
		for holder: Node in [region.get_node("Entities"), region.get_node("MonsterSpawns")]:
			for node: Node2D in holder.get_children():
				if corridor.grow(MIN_PROP_DISTANCE).has_point(node.position):
					print("[gen] %s: %s tirado do caminho" % [_r["id"], node.name])
					holder.remove_child(node)
					node.free()
		var passage: Area2D = load(PASSAGE_SCENE).instantiate()
		passage.name = String(entry[0]).to_pascal_case()
		passage.set(&"passage_id", entry[0])
		passage.set(&"target_region", entry[3])
		passage.set(&"target_passage", entry[4])
		passage.position = Vector2(REGION_RECT.end.x - PASSAGE_INSET if side == Side.EAST
			else REGION_RECT.position.x + PASSAGE_INSET, y)
		passage.rotation = 0.0 if side == Side.EAST else PI
		_add_owned(container, passage, region)


## Cópia embaralhada com a semente dada (`Array.shuffle` usa o sorteio global, não determinístico).
func _shuffled(cells: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = cells.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result


## NPCs fixos (F3), na área livre em volta da entrada: nada sorteado, nada tirado do lugar.
func _place_npcs(entities: Node2D, region: Node2D, spawn: Vector2) -> void:
	for entry: Array in _r.get("npcs", []):
		var npc: Node2D = load(entry[0]).instantiate()
		npc.position = spawn + entry[1]
		_add_owned(entities, npc, region)
		print("[gen] %s npc: %s em %s" % [_r["id"], npc.name, npc.position])
