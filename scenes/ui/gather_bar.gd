class_name GatherBar
extends Node2D
## Barrinha de progresso da coleta acima da cabeça do personagem. Só LÊ o Gatherer.

const SIZE := Vector2(14, 2)
const HEIGHT_ABOVE_FEET := 28.0
const BACK_COLOR := UiStyle.SLOT_BACK
const FILL_COLOR := UiStyle.ACCENT

@export var gatherer: Gatherer


func _ready() -> void:
	position = Vector2(-SIZE.x / 2.0, -HEIGHT_ABOVE_FEET)
	visible = false


func _process(_delta: float) -> void:
	visible = gatherer.is_gathering()
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-1, -1), SIZE + Vector2(2, 2)), BACK_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE.x * gatherer.progress(), SIZE.y)), FILL_COLOR)
