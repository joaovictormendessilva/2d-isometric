class_name InventoryPanel
extends Control
## Inventário do jogador LOCAL (abre e fecha com I / Tab / botão Y; Esc fecha). É uma janela
## livre: o jogador a arrasta para onde preferir e pode andar e lutar com ela aberta (fora
## dela, o mouse segue para o mundo). Cada ação vira um pedido ao host (PlayerStateSync); a
## tela só mostra o inventário, que muda quando o host decide.

const COLUMNS := 6
const SLOT_GAP := 2
const SETTINGS_KEY := "inventory"
## Por quanto tempo um aviso (ex.: falta espaço para dividir) fica no lugar da dica.
const MESSAGE_TIME := 2.5
const MESSAGE_COLOR := Color("ff9f6b")
const HINT_ALPHA := 0.7

var _inventory: Inventory
var _player_state: PlayerStateSync
var _window := DraggableWindow.new()
var _split := SplitDialog.new()
var _hint: Label
var _slots: Array[InventorySlot] = []
var _message_left := 0.0


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # só a janela pega o mouse
	add_child(_window)  # na árvore desde já: sem setup (cliente recusado) nada fica solto
	add_child(_split)


func setup(inventory: Inventory, items: ItemDatabase, player_state: PlayerStateSync) -> void:
	_inventory = inventory
	_player_state = player_state
	_window.setup(Texts.get_text(&"INVENTORY_TITLE"), SETTINGS_KEY)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", SLOT_GAP)
	grid.add_theme_constant_override(&"v_separation", SLOT_GAP)
	_window.add_content(grid)
	for i in inventory.capacity():
		var slot := InventorySlot.new()
		slot.setup(i, inventory, items)
		slot.move_requested.connect(player_state.request_move)
		slot.dropped_nowhere.connect(_on_dropped_nowhere)
		slot.split_requested.connect(_on_split_requested)
		grid.add_child(slot)
		_slots.append(slot)
	_hint = Label.new()
	# Quebra de linha na largura da grade (sem largura fixa, o texto mede uma palavra por linha).
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = grid.get_combined_minimum_size().x
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_window.add_content(_hint)
	_show_hint()
	_split.confirmed.connect(player_state.request_split)
	inventory.slot_changed.connect(func(index: int) -> void: _slots[index].refresh())


func _unhandled_input(event: InputEvent) -> void:
	if _inventory == null:
		return
	if event.is_action_pressed(&"inventory") or (visible and event.is_action_pressed(&"ui_cancel")):
		visible = not visible
		_split.hide()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_show_hint()


func _on_dropped_nowhere(index: int) -> void:
	drop_if_outside(index, get_global_mouse_position())


## Item arrastado e solto fora de qualquer espaço: se foi fora da janela, cai no chão.
func drop_if_outside(index: int, screen_point: Vector2) -> void:
	if not _window.contains_screen_point(screen_point):
		_player_state.request_drop(index)


func _on_split_requested(index: int) -> void:
	var target := Inventory.split_target(index)
	if not _inventory.is_valid_slot(target) or _inventory.slot_item(target) != Inventory.EMPTY:
		_show_message(Texts.get_text(&"SPLIT_NEEDS_FREE_SLOT"))
		return
	_split.open(index, _inventory.slot_amount(index), get_global_mouse_position())


func _show_message(text: String) -> void:
	_hint.text = text
	_hint.modulate = MESSAGE_COLOR
	_message_left = MESSAGE_TIME
	_window.fit_content()


func _show_hint() -> void:
	_hint.text = Texts.get_text(&"INVENTORY_HINT")
	_hint.modulate = Color(1, 1, 1, HINT_ALPHA)
	_window.fit_content()
