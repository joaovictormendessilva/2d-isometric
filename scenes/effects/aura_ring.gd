class_name AuraRing
extends Node2D
## Uma metade (a de trás ou a da frente) do anel de uma aura no chão (ADR-029). As duas metades
## ficam em lados opostos do corpo para dar volume na perspectiva isométrica (ADR-007): a de trás
## é desenhada antes do sprite, a da frente depois. Pixel a pixel, sem suavização e em cor cheia
## (somar luz desbotava o anel e as runas sobre a grama); o giro e o brilho andam em passos
## (`STEPS_PER_SECOND`), como animação de pixel art. As duas metades usam o mesmo relógio, então
## ficam sempre em fase.

enum Half { BACK, FRONT }

const STEPS_PER_SECOND := 12.0
## Espaço livre no anel de cada lado de uma runa, em pixels.
const RUNE_GAP := 3.0
## Runas 3×3, alternadas pelo anel ('#' = pixel aceso).
const RUNE_GLYPHS := [
	[".#.", "###", ".#."],
	["#.#", ".#.", "#.#"],
	["#.#", "###", "#.#"],
]

var _aura: AuraData
var _half := Half.BACK
## Pontos do anel (pixels inteiros) e o ângulo de cada um, calculados uma vez.
var _points: Array[Vector2i] = []
var _angles: PackedFloat32Array = []
var _step := -1


func setup(aura: AuraData, half: Half) -> void:
	_aura = aura
	_half = half
	_trace_ellipse()



## Tempo da animação de todas as auras (mesmo relógio para as duas metades).
static func clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	var step := floori(AuraRing.clock() * STEPS_PER_SECOND)
	if step != _step:
		_step = step
		queue_redraw()


func _draw() -> void:
	var time := _step / STEPS_PER_SECOND
	var pulse := 0.5 + 0.5 * sin(TAU * time / _aura.pulse_period)
	var light := _aura.pulse_light * pulse
	var phase := TAU * _aura.turns_per_second * time
	var rune_angles := PackedFloat32Array()
	for index in _aura.rune_count:
		rune_angles.append(phase + TAU * index / _aura.rune_count)
	if _half == Half.BACK:
		_draw_glow(Color(_aura.ring_color, _aura.glow_alpha * (0.5 + 0.5 * pulse)))
	var gap := RUNE_GAP / _aura.radius
	var ring := _aura.ring_color.lightened(light)
	for index in _points.size():
		var point := _points[index]
		if _in_half(point) and not _near_any(_angles[index], rune_angles, gap):
			draw_rect(Rect2(point, Vector2.ONE), ring)
	var rune := _aura.rune_color.lightened(light)
	for index in rune_angles.size():
		var center := _on_ellipse(rune_angles[index])
		if _in_half(center):
			_draw_glyph(RUNE_GLYPHS[index % RUNE_GLYPHS.size()], center, rune)


## Luz no chão: a elipse inteira, preenchida linha a linha (fica toda atrás do corpo, que pisa
## nela), sem tocar o anel.
func _draw_glow(color: Color) -> void:
	if color.a <= 0.0:
		return
	var size := Iso.ground_to_screen(Vector2.ONE * _aura.radius)
	for row in range(-ceili(size.y) + 1, ceili(size.y)):
		var half_width := floori(size.x * sqrt(maxf(0.0, 1.0 - (row / size.y) ** 2))) - 1
		if half_width > 0:
			draw_rect(Rect2(-half_width, row, half_width * 2 + 1, 1), color)


func _draw_glyph(glyph: Array, center: Vector2i, color: Color) -> void:
	var origin := center - Vector2i(glyph[0].length() / 2, glyph.size() / 2)
	for row in glyph.size():
		var line: String = glyph[row]
		for column in line.length():
			if line[column] == "#":
				draw_rect(Rect2(origin + Vector2i(column, row), Vector2.ONE), color)


## Pontos de cima (y < 0) ficam atrás dos pés; os de baixo, na frente.
func _in_half(point: Vector2i) -> bool:
	return (point.y < 0) == (_half == Half.BACK)


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
