class_name ContextMenu
extends PanelContainer
## Base dos menus de botão direito (SlotMenu do inventário, ChoiceMenu da barra de habilidades):
## abre perto do ponteiro sem sair da tela e fecha com Esc ou com um clique fora; esse clique não
## vira ataque (o menu está no grupo que segura o mouse enquanto aberto).


func _ready() -> void:
	visible = false
	add_to_group(LocalPlayerInput.MOUSE_CAPTURE_GROUP)


func captures_mouse() -> bool:
	return visible


## Mostra o menu perto de `at` (tela), dentro da janela.
func _show_at(at: Vector2) -> void:
	visible = true
	reset_size()
	var limit := get_viewport_rect().size - size
	position = Vector2(clampf(at.x, 0.0, limit.x), clampf(at.y, 0.0, limit.y)).round()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var button := event as InputEventMouseButton
	if button and button.pressed and not get_global_rect().has_point(button.position):
		# Adiado: neste mesmo clique o menu ainda conta como aberto (não ataca).
		hide.call_deferred()
	elif event.is_action_pressed(&"ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
