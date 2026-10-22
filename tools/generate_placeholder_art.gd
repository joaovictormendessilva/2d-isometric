extends SceneTree
## Gera a arte PROVISÓRIA da Etapa C (tiles, árvore, pedra, personagem, sombra) como PNG.
## Tudo é desenhado por código (sem assets externos), só para validar escala, leitura e
## ordenação isométrica. Será substituída por arte própria.
##
## Uso: Godot --headless --path . -s res://tools/generate_placeholder_art.gd
## Depois rode --import para a Godot importar os PNGs.

const TerrainAtlas := preload("res://tools/terrain_atlas.gd")

const TILE := Iso.TILE_SIZE
const OUT_DIR := "res://assets/sprites/placeholder/"

# Paletas de 3 tons: [base, sombra, luz].
const GRASS := [Color("4f8a3f"), Color("437a36"), Color("68a24f")]
const DIRT := [Color("8b6b47"), Color("75583a"), Color("a3825a")]
const WATER := [Color("3d6fa8"), Color("335f92"), Color("6a9fd4")]
const LEAVES := [Color("4f8f3e"), Color("356b2f"), Color("7cb85a")]
const STONE := [Color("7f7f93"), Color("5d5d70"), Color("a8a8b8")]
const TRUNK := [Color("6b4a2f"), Color("4e3522")]
const LEAVES_OUTLINE := Color("1c3320")
const STONE_OUTLINE := Color("2a2a36")
const SLIME := [Color("8a5cc7"), Color("6a42a3"), Color("b48ae8")]
const SLIME_OUTLINE := Color("2a1840")
const SLIME_EYES := Color("1b1a26")
const SLASH := Color(1.0, 0.97, 0.85)
const SHADOW := Color(0.05, 0.04, 0.1, 0.35)

const CHARACTER_PALETTE := {
	"o": Color("1b1a26"),  # contorno
	"C": Color("3b4f8f"),  # capa
	"L": Color("5a74c4"),  # capa (luz)
	"D": Color("2a3566"),  # capa (sombra)
	"s": Color("f2c29b"),  # pele
	"S": Color("d19a74"),  # pele (sombra)
	"e": Color("1b1a26"),  # olhos
	"t": Color("8a5a3b"),  # túnica
	"T": Color("6a4430"),  # túnica (sombra)
	"b": Color("4a3020"),  # cinto
	"g": Color("e8c15a"),  # fivela
	"k": Color("3a2a2a"),  # botas
}

# Personagem 16x23 montado por partes; frente e costas compartilham capuz e pernas.
const HOOD_TOP := [
	"......oooo......",
	".....oLLCCo.....",
	"....oLLCCCCo....",
	"...oLCCCCCCDo...",
]
const FRONT_MIDDLE := [
	"...oLCooooCDo...",
	"..oLCossssoCDo..",
	"..oLosesseSoDo..",
	"..oLossssSSoDo..",
	"..oCDoSSSSoDDo..",
	"...oCDooooDDo...",
	"..oLCCtttTCCDo..",
	".oLCCtttttTCCDo.",
	".oLCCtttttTCCDo.",
	".oLCsbbgbbbsCDo.",
	".oLCCtttttTCCDo.",
	".oLCCtttttTCCDo.",
	"..oCCTtttTTCDo..",
	"..oDCCTTTTCDDo..",
]
const BACK_MIDDLE := [
	"...oLCCCCCCDo...",
	"..oLCCCCCCCCDo..",
	"..oLCCCCCCCCDo..",
	"..oLCCCCCCCDDo..",
	"..oCDDCCCCDDDo..",
	"...oCDDDDDDDo...",
	"..oLCCCCCCCCDo..",
	".oLCCCCCCCCCCDo.",
	".oLCCCCCCCCCCDo.",
	".oLCsCCCCCCsCDo.",
	".oLCCCCCCCCCCDo.",
	".oLCCCCCCCCCCDo.",
	"..oCCCCCCCCCDo..",
	"..oDCCCCCCCDDo..",
]
const LEGS := [
	"...oDDDDDDDDo...",
	"....okkookko....",
	"....okkookko....",
	"...okkkookkko...",
	"...oooo..oooo...",
]


func _initialize() -> void:
	_save(_terrain_atlas(), TerrainAtlas.TEXTURE_PATH)
	_save(_character_sheet(), OUT_DIR + "character.png")
	_save(_tree(), OUT_DIR + "tree.png")
	_save(_rock(), OUT_DIR + "rock.png")
	_save(_shadow(), OUT_DIR + "shadow.png")
	_save(_slime(), OUT_DIR + "slime.png")
	_save(_gel(), OUT_DIR + "gel.png")
	_save(_slash(), OUT_DIR + "slash.png")
	quit(0)


func _save(image: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Falha ao salvar %s (%d)" % [path, err])
		quit(1)
	print("[art] %s (%dx%d)" % [path, image.get_width(), image.get_height()])


# --- Formas -----------------------------------------------------------------------------

## Pixel (x, y) pertence ao losango do tile? Teste no centro do pixel: losangos vizinhos
## encaixam sem buracos nem sobreposição (bordas em degraus de 2 px).
static func in_tile(x: int, y: int) -> bool:
	return in_ellipse(x, y, Vector2(TILE) / 2.0, Vector2(TILE) / 2.0, 1)


## Pixel dentro da elipse? `norm` 1 = losango (|dx|+|dy|), 2 = elipse comum.
static func in_ellipse(x: int, y: int, center: Vector2, radii: Vector2, norm: int = 2) -> bool:
	var d := ((Vector2(x, y) + Vector2(0.5, 0.5)) - center) / radii
	if norm == 1:
		return absf(d.x) + absf(d.y) < 1.0
	return d.length_squared() < 1.0


## Tom da paleta [base, sombra, luz] para um pixel, com luz vinda de cima/esquerda.
## `v` < -band = luz, > band = sombra; perto das faixas, pontilhado em xadrez.
static func shade(palette: Array, v: float, band: float, x: int, y: int) -> Color:
	var dither := (x + y) % 2 == 0
	if v < -band or (v < -band + 1.5 and dither):
		return palette[2]
	if v > band or (v > band - 1.5 and dither):
		return palette[1]
	return palette[0]


## Base com pontinhos aleatórios de sombra e luz.
static func speckle(rng: RandomNumberGenerator, palette: Array, dark: float, light: float) -> Color:
	var r := rng.randf()
	if r < dark:
		return palette[1]
	return palette[2] if r < dark + light else palette[0]


## Pinta de `color` todo pixel transparente vizinho (4 direções) de um pixel opaco.
static func outline(img: Image, color: Color) -> void:
	var source := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if source.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if Rect2i(Vector2i.ZERO, img.get_size()).has_point(n) and source.get_pixelv(n).a > 0.0:
					img.set_pixel(x, y, color)
					break


# --- Imagens ----------------------------------------------------------------------------

func _terrain_atlas() -> Image:
	var columns := TerrainAtlas.COLUMNS
	var img := Image.create(TILE.x * columns.size(), TILE.y, false, Image.FORMAT_RGBA8)
	for i in columns.size():
		var tile := columns[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var palette: Array = WATER if tile == &"water" else (DIRT if tile == &"dirt" else GRASS)
		for y in TILE.y:
			for x in TILE.x:
				if in_tile(x, y):
					var color: Color = palette[0] if tile == &"water" else speckle(rng, palette, 0.11, 0.07)
					img.set_pixel(i * TILE.x + x, y, color)
		if tile == &"water":
			_water_waves(img, i * TILE.x, rng)
		elif tile in TerrainAtlas.GRASS:
			_grass_blades(img, i * TILE.x, rng)
	return img


func _grass_blades(img: Image, ox: int, rng: RandomNumberGenerator) -> void:
	for n in 4:
		var x := rng.randi_range(6, TILE.x - 7)
		var y := rng.randi_range(4, TILE.y - 4)
		if in_tile(x, y) and in_tile(x, y - 1):
			img.set_pixel(ox + x, y, GRASS[2])
			img.set_pixel(ox + x, y - 1, GRASS[2])


func _water_waves(img: Image, ox: int, rng: RandomNumberGenerator) -> void:
	for n in 3:
		var x := rng.randi_range(6, TILE.x - 10)
		var y := rng.randi_range(4, TILE.y - 5)
		for dx in 3:
			if in_tile(x + dx, y):
				img.set_pixel(ox + x + dx, y, WATER[2])
		if in_tile(x + 1, y + 1):
			img.set_pixel(ox + x + 1, y + 1, WATER[1])


func _character_sheet() -> Image:
	var frames := [HOOD_TOP + FRONT_MIDDLE + LEGS, HOOD_TOP + BACK_MIDDLE + LEGS]
	var w: int = HOOD_TOP[0].length()
	var h: int = frames[0].size()
	var img := Image.create(w * frames.size(), h, false, Image.FORMAT_RGBA8)
	for f in frames.size():
		for y in h:
			var row: String = frames[f][y]
			for x in w:
				if CHARACTER_PALETTE.has(row[x]):
					img.set_pixel(f * w + x, y, CHARACTER_PALETTE[row[x]])
	return img


## Árvore 32x48: tronco + copa feita de 4 círculos, sombreada e contornada.
func _tree() -> Image:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var blobs := [[Vector2(16, 15), 11.0], [Vector2(9, 21), 8.0], [Vector2(23, 21), 8.0],
		[Vector2(16, 25), 9.0]]
	for y in img.get_height():
		for x in img.get_width():
			var in_trunk := (x >= 14 and x <= 17 and y >= 28 and y <= 45) \
				or (y == 45 and x >= 13 and x <= 18)
			if in_trunk:
				img.set_pixel(x, y, TRUNK[1] if x >= 17 else TRUNK[0])
			for blob: Array in blobs:
				if in_ellipse(x, y, blob[0], Vector2.ONE * blob[1]):
					var v := (x - 16.0) * 0.5 + (y - 18.0) * 0.8
					img.set_pixel(x, y, shade(LEAVES, v, 5.0, x, y))
					break
	outline(img, LEAVES_OUTLINE)
	return img


func _rock() -> Image:
	var img := Image.create(20, 14, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			if in_ellipse(x, y, Vector2(10, 7.5), Vector2(8.5, 5.5)):
				var v := (x - 10.0) * 0.4 + (y - 7.0) * 0.9
				img.set_pixel(x, y, shade(STONE, v, 2.5, x, y))
	outline(img, STONE_OUTLINE)
	return img


func _shadow() -> Image:
	var img := Image.create(12, 5, false, Image.FORMAT_RGBA8)
	var half := Vector2(img.get_size()) / 2.0
	for y in img.get_height():
		for x in img.get_width():
			if in_ellipse(x, y, half, half):
				img.set_pixel(x, y, SHADOW)
	return img


## Gota de gosma sombreada com brilho; usada pelo slime e pelo item que ele derruba.
func _blob(size: Vector2i, center: Vector2, radii: Vector2, band: float) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			if in_ellipse(x, y, center, radii):
				var v := (x - center.x) * 0.5 + (y - center.y) * 0.9
				img.set_pixel(x, y, shade(SLIME, v, band, x, y))
	var shine := Vector2i(center - radii * 0.45)
	img.set_pixelv(shine, Color.WHITE)
	outline(img, SLIME_OUTLINE)
	return img


func _slime() -> Image:
	var img := _blob(Vector2i(16, 12), Vector2(8, 6.5), Vector2(7.5, 5.5), 2.5)
	for eye in [Vector2i(6, 6), Vector2i(10, 6)]:
		img.set_pixelv(eye, SLIME_EYES)
		img.set_pixelv(eye + Vector2i.DOWN, SLIME_EYES)
	return img


func _gel() -> Image:
	return _blob(Vector2i(8, 7), Vector2(4, 3.5), Vector2(3.5, 2.5), 1.0)


## Rastro do golpe: arco em meia-lua apontando para a direita, mais opaco no meio.
func _slash() -> Image:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0
	var half_arc := deg_to_rad(60.0)
	for y in size:
		for x in size:
			var p := Vector2(x, y) + Vector2(0.5, 0.5) - center
			var angle := absf(p.angle())
			if p.length() < 17.0 or p.length() > 24.0 or angle > half_arc:
				continue
			# Mais grosso e opaco no centro do arco, afinando nas pontas.
			var along := 1.0 - angle / half_arc
			if p.length() < 24.0 - 7.0 * along:
				continue
			img.set_pixel(x, y, Color(SLASH, 0.35 + 0.65 * along))
	return img
