extends TestCase
## Entrada do jogador local: um clique que começa na interface (ou com um item na mão) nunca
## vira ataque; com o cursor livre, o clique ataca.

const CLICK_AT := Vector2(600, 300)  # longe da janela do inventário


func test_click_with_item_in_hand_does_not_attack() -> void:
	var game := start_game()
	calm_monsters(game)
	var player := (game.session as GameSession).get_player_entity(game.local_player_id()) as Character
	var input: LocalPlayerInput = game.get_node("LocalInput")
	input.target = player
	var inventory := (game.session as GameSession).get_inventory(game.local_player_id())
	inventory.add(&"wood", 5)
	var panel: InventoryPanel = game.get_node("UI/InventoryPanel")
	panel.set_open(true)
	inventory.click_slot(0)  # item na mão

	_mouse(true)
	await physics_frames(5)
	check(not player.attacker.is_attacking(), "o clique jogou o item fora em vez de atacar")
	await physics_frames(30)
	check(not player.attacker.is_attacking(), "segurar o botão depois disso também não ataca")
	_mouse(false)
	await physics_frames(2)

	_mouse(true)
	await physics_frames(3)
	check(player.attacker.is_attacking(), "com o cursor livre, o clique ataca")
	_mouse(false)


func _mouse(pressed: bool) -> void:
	_send(_button_event(CLICK_AT, pressed))


## Arrastar a janela pelo título: ela acompanha o ponteiro exatamente, mesmo num movimento
## rápido (antes, ela ficava para trás).
func test_window_follows_pointer_exactly() -> void:
	var game := start_game()
	var panel: InventoryPanel = game.get_node("UI/InventoryPanel")
	panel.set_open(true)
	await physics_frames(3)
	var window: DraggableWindow = panel._window
	var title: Label = window._title
	var grab := title.get_global_rect().get_center().round()
	var grab_offset := grab - window.position
	_send(_button_event(grab, true))
	var target := grab + Vector2(-120, 60)
	_send(_motion_event(target, target - grab))
	await physics_frames(1)
	check(window.position == (target - grab_offset).round(),
		"janela em %s, esperado %s" % [window.position, (target - grab_offset).round()])
	_send(_button_event(target, false))
	check(not window.captures_mouse(), "soltou")


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _button_event(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event


func _motion_event(at: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event
