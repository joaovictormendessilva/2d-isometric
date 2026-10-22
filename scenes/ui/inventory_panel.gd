class_name InventoryPanel
extends Control
## Tela de inventário do jogador LOCAL (tecla I / Tab / botão Y). Ocupa a tela toda enquanto
## aberta: soltar um item fora da janela joga o item no chão. Cada ação vira um pedido ao
## host (PlayerStateSync); a tela só mostra o inventário, que muda quando o host decide.

const COLUMNS := 6
const SLOT_GAP := 2

var _inventory: Inventory
var _player_state: PlayerStateSync
var _slots: Array[InventorySlot] = []


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(inventory: Inventory, items: ItemDatabase, player_state: PlayerStateSync) -> void:
	_inventory = inventory
	_player_state = player_state
	var window := PanelContainer.new()
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	window.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(window)
	var column := VBoxContainer.new()
	window.add_child(column)
	column.add_child(_label(Texts.get_text(&"INVENTORY_TITLE")))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", SLOT_GAP)
	grid.add_theme_constant_override(&"v_separation", SLOT_GAP)
	column.add_child(grid)
	for i in inventory.capacity():
		var slot := InventorySlot.new()
		slot.setup(i, inventory, items)
		slot.move_requested.connect(player_state.request_move)
		grid.add_child(slot)
		_slots.append(slot)
	var hint := _label(Texts.get_text(&"INVENTORY_HINT"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a janela fica da largura da grade
	hint.modulate = Color(1, 1, 1, 0.7)
	column.add_child(hint)
	inventory.slot_changed.connect(func(index: int) -> void: _slots[index].refresh())


func _unhandled_input(event: InputEvent) -> void:
	if _inventory and event.is_action_pressed(&"inventory"):
		visible = not visible
		get_viewport().set_input_as_handled()


## O fundo (fora da janela) aceita itens arrastados: soltar aqui joga no chão.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has(InventorySlot.DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_player_state.request_drop(data[InventorySlot.DRAG_KEY])


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
