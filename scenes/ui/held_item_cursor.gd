class_name HeldItemCursor
extends Control
## O item que o jogador pegou do inventário, desenhado junto ao ponteiro do mouse.

const SIZE := Vector2(24, 24)
const ICON_SIZE := Vector2(16, 16)
## Deslocamento do ícone em relação à ponta do ponteiro (fica ao lado, sem cobri-la).
const OFFSET := Vector2(4, 4)

var _inventory: Inventory
var _items: ItemDatabase
var _icon: TextureRect
var _amount: Label


func setup(inventory: Inventory, items: ItemDatabase) -> void:
	_inventory = inventory
	_items = items
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = ItemIcon.icon(ICON_SIZE)
	_icon.position = Vector2(2, 2)
	add_child(_icon)
	_amount = ItemIcon.amount_label(SIZE)
	add_child(_amount)
	inventory.held_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if visible:
		position = (get_global_mouse_position() + OFFSET).round()


func _refresh() -> void:
	visible = _inventory.is_holding()
	ItemIcon.show_stack(_icon, _amount, _items.get_item(_inventory.held_item()),
		_inventory.held_amount())
