class_name InventorySlot
extends Control
## Um espaço da tela de inventário: fundo, ícone, quantidade e o nome do item ao passar o
## mouse. Clique esquerdo: pegar / pôr / juntar / trocar com a mão. Botão direito: dividir a
## pilha (só com a mão vazia). Quem decide é o host; o espaço só mostra.

signal clicked(index: int)
signal split_requested(index: int)

const SIZE := Vector2(24, 24)
const ICON_SIZE := Vector2(16, 16)  # ícones 8x8 em escala 2, ainda em pixels inteiros
const BACK_COLOR := Color(0.1, 0.08, 0.14, 0.92)
const BORDER_COLOR := Color(0.32, 0.28, 0.42)
const HOVER_COLOR := Color(0.62, 0.56, 0.78)

var index := 0

var _inventory: Inventory
var _items: ItemDatabase
var _icon: TextureRect
var _amount: Label
var _hovered := false


func setup(p_index: int, inventory: Inventory, items: ItemDatabase) -> void:
	index = p_index
	_inventory = inventory
	_items = items
	custom_minimum_size = SIZE
	_icon = ItemIcon.icon(ICON_SIZE)
	_icon.position = Vector2(2, 2)
	add_child(_icon)
	_amount = ItemIcon.amount_label(SIZE)
	add_child(_amount)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	refresh()


func refresh() -> void:
	var item := _items.get_item(_inventory.slot_item(index))
	ItemIcon.show_stack(_icon, _amount, item, _inventory.slot_amount(index))
	tooltip_text = item.get_display_name() if item else ""


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BACK_COLOR)
	draw_rect(Rect2(Vector2.ZERO, SIZE), HOVER_COLOR if _hovered else BORDER_COLOR, false, 1.0)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT and _inventory.slot_amount(index) > 1 \
			and not _inventory.is_holding():
		split_requested.emit(index)
		accept_event()


func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()
