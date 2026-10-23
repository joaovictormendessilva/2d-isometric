class_name GroundTelegraph
extends Node2D
## Aviso no chão de um ataque em área (salto do chefe, F4; habilidades em área, G2d): contorno do
## círculo atingido (elipse 2:1 na tela) e o miolo enchendo até o impacto, para o jogador ler
## "sai daí". No impacto, uma onda clara se abre e some. Só apresentação: vive na camada
## `Region.ground_effects`. Vermelho = perigo para o jogador; as habilidades dele usam a cor delas.

## Vermelho de perigo, igual em todo aviso de ataque (mesmo significado de UiStyle.DANGER). Forte
## de propósito: a luz ambiente de regiões escuras (floresta) multiplica estas cores.
const OUTLINE_COLOR := Color(1.0, 0.3, 0.25, 1.0)
const FILL_COLOR := Color(1.0, 0.12, 0.1, 0.6)
const WAVE_COLOR := Color(1.0, 0.95, 0.85, 0.9)
const SEGMENTS := 32
## Onda do impacto: cresce até esta fração do raio e some neste tempo.
const WAVE_GROWTH := 1.25
const WAVE_TIME := 0.25
## Miolo menor que isto não vira polígono (pontos repetidos).
const MIN_FILL_RADIUS := 2.0

var _radius := 0.0
var _progress := 0.0
var _wave := -1.0  # < 0: ainda avisando; 0..1: onda do impacto
var _outline_color := OUTLINE_COLOR
var _fill_color := FILL_COLOR


## `radius` no plano do chão (px).
func setup(at: Vector2, radius: float, outline_color := OUTLINE_COLOR,
		fill_color := FILL_COLOR) -> void:
	position = at.round()
	_radius = radius
	_outline_color = outline_color
	_fill_color = fill_color


## Quanto do aviso já passou (0 a 1): o miolo enche junto.
func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


## Impacto: troca o aviso pela onda e se remove quando ela some.
func burst() -> void:
	_wave = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_wave", 1.0, WAVE_TIME).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	tween.finished.connect(queue_free)


func _process(_delta: float) -> void:
	if _wave >= 0.0:
		queue_redraw()


func _draw() -> void:
	if _wave >= 0.0:
		var color := WAVE_COLOR
		color.a *= 1.0 - _wave
		_ring(_radius * lerpf(1.0, WAVE_GROWTH, _wave), color)
		return
	if _radius * _progress >= MIN_FILL_RADIUS:
		draw_colored_polygon(_ellipse(_radius * _progress, false), _fill_color)
	_ring(_radius, _outline_color)


func _ring(radius: float, color: Color) -> void:
	var points := _ellipse(radius)
	points.append(points[0])
	draw_polyline(points, color, 1.0)


## Círculo no chão de raio `radius`, em pontos de tela. `snap`: em pixels inteiros (contornos);
## o miolo não arredonda (pontos repetidos não formam polígono).
static func _ellipse(radius: float, snap: bool = true) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SEGMENTS:
		var point := Iso.ground_to_screen(Vector2.from_angle(TAU * i / SEGMENTS) * radius)
		points.append(point.round() if snap else point)
	return points
