class_name AuraRingImage
extends RefCounted
## Imagem de uma metade do anel de uma aura (ADR-029), compartilhada por todos os atores com a
## mesma aura: o anel só depende da aura, da metade e do passo do relógio, então é pintado uma vez
## por passo e cada `AuraRing` só desenha a textura. Pintar pixel a pixel em cada ator custava
## ~60 µs por anel a cada passo (60 auras: picos de 7,5 ms, G3d). Pixel a pixel e em cor cheia
## (somar luz desbotava o anel e as runas sobre a grama).

## Espaço livre no anel de cada lado de uma runa, em pixels.
const RUNE_GAP := 3.0
## Runas 3×3, alternadas pelo anel ('#' = pixel aceso).
const RUNE_GLYPHS := [
	[".#.", "###", ".#."],
	["#.#", ".#.", "#.#"],
	["#.#", "###", "#.#"],
]
## Folga em volta da elipse para as runas, que passam 1 pixel do anel.
const MARGIN := 1

## Uma por (aura, metade), criada na primeira vez que aparece.
static var _shared := {}

## Pixel da imagem que fica no centro do anel (os pés do ator).
var offset: Vector2i
var texture: ImageTexture
## O que foi pintado no último passo (a textura é a cópia que a placa de vídeo desenha).
var image: Image

var _aura: AuraData
var _half := AuraRing.Half.BACK
## Pontos do anel (pixels inteiros, relativos ao centro) e o ângulo de cada um, calculados uma vez.
var _points: Array[Vector2i] = []
var _angles: PackedFloat32Array = []
var _step := -1


static func shared(aura: AuraData, half: AuraRing.Half) -> AuraRingImage:
	var key := [aura, half]
	if not _shared.has(key):
		_shared[key] = AuraRingImage.new(aura, half)
	return _shared[key]


func _init(aura: AuraData, half: AuraRing.Half) -> void:
	_aura = aura
	_half = half
	var extent := Iso.ground_to_screen(Vector2.ONE * aura.radius)
	offset = Vector2i(ceili(extent.x), ceili(extent.y)) + Vector2i.ONE * MARGIN
	image = Image.create_empty(offset.x * 2 + 1, offset.y * 2 + 1, false, Image.FORMAT_RGBA8)
	_trace_ellipse()
	texture = ImageTexture.create_from_image(image)


## Pinta o passo pedido, se ainda não foi pintado (o primeiro anel de cada passo paga; os outros
## só desenham a mesma textura).
func show_step(step: int) -> void:
	if step == _step:
		return
	_step = step
	_paint(step / AuraRing.STEPS_PER_SECOND)
	texture.update(image)


func _paint(time: float) -> void:
	image.fill(Color.TRANSPARENT)
	var pulse := 0.5 + 0.5 * sin(TAU * time / _aura.pulse_period)
	var light := _aura.pulse_light * pulse
	var phase := TAU * _aura.turns_per_second * time
	var rune_angles := PackedFloat32Array()
	for index in _aura.rune_count:
		rune_angles.append(phase + TAU * index / _aura.rune_count)
	if _half == AuraRing.Half.BACK:
		_paint_glow(Color(_aura.ring_color, _aura.glow_alpha * (0.5 + 0.5 * pulse)))
	var gap := RUNE_GAP / _aura.radius
	var ring := _aura.ring_color.lightened(light)
	for index in _points.size():
		var point := _points[index]
		if _in_half(point) and not _near_any(_angles[index], rune_angles, gap):
			image.set_pixelv(offset + point, ring)
	var rune := _aura.rune_color.lightened(light)
	for index in rune_angles.size():
		var center := _on_ellipse(rune_angles[index])
		if _in_half(center):
			_paint_glyph(RUNE_GLYPHS[index % RUNE_GLYPHS.size()], center, rune)


## Luz no chão: a elipse inteira, preenchida linha a linha (fica toda atrás do corpo, que pisa
## nela), sem tocar o anel.
func _paint_glow(color: Color) -> void:
	if color.a <= 0.0:
		return
	var size := Iso.ground_to_screen(Vector2.ONE * _aura.radius)
	for row in range(-ceili(size.y) + 1, ceili(size.y)):
		var half_width := floori(size.x * sqrt(maxf(0.0, 1.0 - (row / size.y) ** 2))) - 1
		if half_width > 0:
			image.fill_rect(Rect2i(offset + Vector2i(-half_width, row), Vector2i(half_width * 2 + 1, 1)),
				color)


func _paint_glyph(glyph: Array, center: Vector2i, color: Color) -> void:
	var origin := offset + center - Vector2i(glyph[0].length() / 2, glyph.size() / 2)
	for row in glyph.size():
		var line: String = glyph[row]
		for column in line.length():
			if line[column] == "#":
				image.set_pixelv(origin + Vector2i(column, row), color)


## Pontos de cima (y < 0) ficam atrás dos pés; os de baixo, na frente.
func _in_half(point: Vector2i) -> bool:
	return (point.y < 0) == (_half == AuraRing.Half.BACK)


func _on_ellipse(angle: float) -> Vector2i:
	var screen := Iso.ground_to_screen(Vector2.from_angle(angle) * _aura.radius)
	return Vector2i(roundi(screen.x), roundi(screen.y))


## Contorno da elipse sem buracos nem pixels repetidos: amostra fina pelo ângulo e guarda cada
## pixel uma vez só.
func _trace_ellipse() -> void:
	var seen := {}
	var samples := ceili(TAU * _aura.radius * 4.0)
	for sample in samples:
		var angle := TAU * sample / samples
		var point := _on_ellipse(angle)
		if not seen.has(point):
			seen[point] = true
			_points.append(point)
			_angles.append(angle)


static func _near_any(angle: float, others: PackedFloat32Array, gap: float) -> bool:
	for other in others:
		if absf(angle_difference(angle, other)) < gap:
			return true
	return false
