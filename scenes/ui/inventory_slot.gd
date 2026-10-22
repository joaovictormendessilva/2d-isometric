class_name InventorySlot
extends Control
## Um espaço da tela de inventário: fundo, ícone, quantidade e o nome do item ao passar o
## mouse. Arrastar o conteúdo para outro espaço pede a troca (quem decide é o host).

signal move_requested(from: int, to: int)

const SIZE := Vector2(24, 24)
const ICON_SIZE := Vector2(16, 16)  # ícones 8x8 em escala 2, ainda em pixels inteiros
const BACK_COLOR := Color(0.1, 0.08, 0.14, 0.92)
const BORDER_COLOR := Color(0.32, 0.28, 0.42)
const HOVER_COLOR := Color(0.62, 0.56, 0.78)
## Chave dos dados de arrastar: só aceitamos o que veio de um espaço do inventário.
const DRAG_KEY := "inventory_slot"

var index := 0

var _inventory: Inventory
var _items: ItemDatabase
var _icon := TextureRect.new()
var _amount := Label.new()
var _hovered := false


func setup(p_index: int, inventory: Inventory, items: ItemDatabase) -> void:
	index = p_index
	_inventory = inventory
	_items = items
	custom_minimum_size = SIZE
	_icon.size = ICON_SIZE
	_icon.position = Vector2(2, 2)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_amount.size = SIZE
	_amount.position = Vector2(-1, 8)  # dígitos no canto de baixo à direita
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_amount)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	refresh()


func refresh() -> void:
	var item := _items.get_item(_inventory.slot_item(index))
	var amount := _inventory.slot_amount(index)
	_icon.texture = item.icon if item else null
	_amount.text = str(amount) if amount > 1 else ""
	tooltip_text = item.get_display_name() if item else ""


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BACK_COLOR)
	draw_rect(Rect2(Vector2.ZERO, SIZE), HOVER_COLOR if _hovered else BORDER_COLOR, false, 1.0)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _inventory.slot_item(index) == Inventory.EMPTY:
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.size = ICON_SIZE
	preview.position = -ICON_SIZE / 2.0
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var holder := Control.new()  # centraliza o ícone no ponteiro
	holder.add_child(preview)
	set_drag_preview(holder)
	return {DRAG_KEY: index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has(DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	move_requested.emit(data[DRAG_KEY], index)


func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()
