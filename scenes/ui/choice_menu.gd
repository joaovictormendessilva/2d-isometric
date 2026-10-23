class_name ChoiceMenu
extends ContextMenu
## Menu de botão direito com escolhas montadas na hora: uma lista de [texto, ação]. Escolher fecha
## o menu e chama a ação. Ex.: na barra de habilidades, qual habilidade pôr na tecla.

var _column := VBoxContainer.new()


func _ready() -> void:
	super._ready()
	add_child(_column)


## `choices`: [[texto, Callable], ...], na ordem da tela.
func open(choices: Array, at: Vector2) -> void:
	for child in _column.get_children():
		child.free()
	for choice: Array in choices:
		var button := Button.new()
		button.text = choice[0]
		button.pressed.connect(func() -> void:
			hide()
			(choice[1] as Callable).call())
		_column.add_child(button)
	_show_at(at)


## Quantas escolhas o menu mostra (testes).
func choice_count() -> int:
	return _column.get_child_count()
