class_name SplitDialog
extends PanelContainer
## Janelinha para dividir uma pilha: o jogador escolhe quanto separar (1 até a pilha − 1).
## Enter confirma, Esc cancela.

signal confirmed(index: int, amount: int)

var _index := 0
var _slider := HSlider.new()
var _label := Label.new()


func _ready() -> void:
	visible = false
	var column := VBoxContainer.new()
	add_child(column)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_label)
	_slider.custom_minimum_size = Vector2(90, 12)
	_slider.value_changed.connect(_on_value_changed.unbind(1))
	column.add_child(_slider)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	buttons.add_child(_button(&"SPLIT_CONFIRM", _confirm))
	buttons.add_child(_button(&"SPLIT_CANCEL", hide))


## Abre para a pilha de `amount` itens do espaço `index`, perto de `at` (tela).
func open(index: int, amount: int, at: Vector2) -> void:
	_index = index
	_slider.min_value = 1
	_slider.max_value = amount - 1
	_slider.value = amount / 2
	_on_value_changed()
	visible = true
	reset_size()
	var limit := get_viewport_rect().size - size
	position = Vector2(clampf(at.x, 0.0, limit.x), clampf(at.y, 0.0, limit.y)).round()
	_slider.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_accept"):
		_confirm()
	elif event.is_action_pressed(&"ui_cancel"):
		hide()
	else:
		return
	get_viewport().set_input_as_handled()


func _confirm() -> void:
	hide()
	confirmed.emit(_index, int(_slider.value))


func _on_value_changed() -> void:
	_label.text = Texts.format(&"SPLIT_AMOUNT", [int(_slider.value)])


func _button(key: StringName, action: Callable) -> Button:
	var button := Button.new()
	button.text = Texts.get_text(key)
	button.pressed.connect(action)
	return button
