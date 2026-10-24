class_name EventArrow
extends Control
## Seta na borda da tela apontando para o chefe de evento vivo na região do jogador LOCAL, enquanto
## ele estiver fora da tela (ADR-036). Some quando o chefe aparece na tela (aí valem ele e a barra
## do chefe), morre ou vai embora. Pulsa de leve na direção dele. Só apresentação.

## Distância da seta até a borda da tela (px).
const EDGE_MARGIN := 14.0
## Comprimento e meia largura da seta (px).
const LENGTH := 10.0
const HALF_WIDTH := 6.0
const COLOR := UiStyle.ACCENT
const OUTLINE_COLOR := UiStyle.TEXT_OUTLINE
## Vai e volta este tanto (px) na direção do chefe, neste ritmo (rad/s).
const PULSE := 2.0
const PULSE_SPEED := 5.0

var _character: Character
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## A cada personagem do jogador local (recriado numa viagem).
func set_character(character: Character) -> void:
	_character = character


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Ponta da seta e direção para o chefe (tela), ou [] se não há chefe fora da tela.
func arrow() -> Array:
	var boss := _boss()
	if boss == null:
		return []
	var canvas := get_viewport().get_canvas_transform()
	var inside := Rect2(Vector2.ZERO, size).grow(-EDGE_MARGIN)
	var to := canvas * boss.global_position
	if inside.has_point(to):
		return []
	var from := (canvas * _character.global_position).clamp(inside.position, inside.end)
	var direction := (to - from).normalized()
	var pulse := direction * sin(_time * PULSE_SPEED) * PULSE
	var point := _edge_point(from, direction, inside) + pulse
	return [point, direction]


func _draw() -> void:
	var shown := arrow()
	if shown.is_empty():
		return
	var point: Vector2 = shown[0]
	var direction: Vector2 = shown[1]
	var side := direction.orthogonal() * HALF_WIDTH
	var back := point - direction * LENGTH
	var shape := PackedVector2Array([point.round(), (back + side).round(), (back - side).round()])
	draw_colored_polygon(shape, COLOR)
	shape.append(shape[0])
	draw_polyline(shape, OUTLINE_COLOR, 1.0)


## Chefe de evento vivo na região do jogador local, ou null.
func _boss() -> Monster:
	if not is_instance_valid(_character):
		return null
	var region := Region.of(_character)
	for node in get_tree().get_nodes_in_group(BossEvents.BOSS_GROUP):
		var boss := node as Monster
		if boss.is_alive() and Region.of(boss) == region:
			return boss
	return null


## Onde o raio que sai de `from` (dentro de `rect`) na `direction` cruza a borda de `rect`.
static func _edge_point(from: Vector2, direction: Vector2, rect: Rect2) -> Vector2:
	var reach := INF
	if direction.x != 0.0:
		reach = minf(reach, ((rect.end.x if direction.x > 0.0 else rect.position.x) - from.x)
			/ direction.x)
	if direction.y != 0.0:
		reach = minf(reach, ((rect.end.y if direction.y > 0.0 else rect.position.y) - from.y)
			/ direction.y)
	return from + direction * reach
