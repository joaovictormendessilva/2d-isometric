class_name GatherBar
extends Node2D
## Barrinha de progresso acima da cabeça do personagem: coleta ou subida na montaria. Só LÊ o
## Gatherer e o Rider.

const SIZE := Vector2(14, 2)
const HEIGHT_ABOVE_FEET := 28.0
const BACK_COLOR := UiStyle.SLOT_BACK
const FILL_COLOR := UiStyle.ACCENT

@export var gatherer: Gatherer
@export var rider: Rider


func _ready() -> void:
	position = Vector2(-SIZE.x / 2.0, -HEIGHT_ABOVE_FEET)
	visible = false


func _process(_delta: float) -> void:
	visible = gatherer.is_gathering() or _mounting()
	if visible:
		queue_redraw()


func _draw() -> void:
	var progress := rider.state.progress() if _mounting() else gatherer.progress()
	draw_rect(Rect2(Vector2(-1, -1), SIZE + Vector2(2, 2)), BACK_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE.x * progress, SIZE.y)), FILL_COLOR)


func _mounting() -> bool:
	return rider != null and rider.state.phase == RideState.Phase.MOUNTING
