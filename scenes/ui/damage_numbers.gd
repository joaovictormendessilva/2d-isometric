class_name DamageNumbers
extends Node2D
## Números de dano (e avisos curtos, como "Imune") flutuantes. Usa um conjunto fixo de
## Labels reaproveitados (pooling): nenhuma criação de nós durante o combate.

const POOL_SIZE := 32
const RISE := 14.0
const LIFETIME := 0.6
const HEIGHT_ABOVE_FEET := 30.0
const LABEL_SIZE := Vector2(40, 12)

var _pool: Array[Label] = []
var _tweens: Array[Tween] = []
var _next := 0


func _ready() -> void:
	var settings := LabelSettings.new()
	settings.font_size = 8
	settings.outline_size = 3
	settings.outline_color = Color.BLACK
	for i in POOL_SIZE:
		var label := Label.new()
		label.label_settings = settings
		label.size = LABEL_SIZE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.visible = false
		add_child(label)
		_pool.append(label)
		_tweens.append(null)


func show_number(feet_position: Vector2, amount: int, color: Color) -> void:
	show_text(feet_position, str(amount), color)


func show_text(feet_position: Vector2, text: String, color: Color) -> void:
	var i := _next
	_next = (_next + 1) % POOL_SIZE
	var label := _pool[i]
	if _tweens[i]:
		_tweens[i].kill()
	label.text = text
	label.modulate = color
	label.position = feet_position - Vector2(LABEL_SIZE.x / 2.0, HEIGHT_ABOVE_FEET)
	label.visible = true
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - RISE, LIFETIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.hide)
	_tweens[i] = tween
