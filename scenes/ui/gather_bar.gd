class_name GatherBar
extends Node2D
## Barrinha de progresso acima da cabeça do personagem: coleta, subida na montaria ou canalização
## (pedra de portal). Só LÊ o Gatherer, o Rider e o Channel.

const SIZE := Vector2(14, 2)
const HEIGHT_ABOVE_FEET := 28.0
const BACK_COLOR := UiStyle.SLOT_BACK
const FILL_COLOR := UiStyle.ACCENT

@export var gatherer: Gatherer
@export var rider: Rider
@export var channel: Channel


func _ready() -> void:
	position = Vector2(-SIZE.x / 2.0, -HEIGHT_ABOVE_FEET)
	visible = false


func _process(_delta: float) -> void:
	visible = _progress() >= 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-1, -1), SIZE + Vector2(2, 2)), BACK_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE.x * _progress(), SIZE.y)), FILL_COLOR)


## Progresso da ação em andamento (0 a 1), ou -1 sem nenhuma.
func _progress() -> float:
	if channel and channel.is_channeling():
		return channel.progress()
	if rider and rider.state.phase == RideState.Phase.MOUNTING:
		return rider.state.progress()
	return gatherer.progress() if gatherer.is_gathering() else -1.0
