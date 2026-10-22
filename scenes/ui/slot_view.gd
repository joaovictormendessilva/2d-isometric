class_name SlotView
extends Control
## Quadrado de item da interface (base de InventorySlot e EquipmentSlot): fundo, ícone,
## quantidade, borda ao passar o mouse e destaque dourado ("este item cabe aqui"). Quem herda
## decide o conteúdo (`show_item`) e o que os cliques fazem; quem decide de verdade é o host.

signal clicked(index: int)
signal menu_requested(index: int)

const SIZE := Vector2(24, 24)
const ICON_SIZE := Vector2(16, 16)  # ícones 8x8 em escala 2, ainda em pixels inteiros

var index := 0
## Destaque dourado (ex.: espaço de equipamento onde o item da mão cabe).
var highlighted := false:
	set(value):
		if highlighted != value:
			highlighted = value
			queue_redraw()

var _icon: TextureRect
var _amount: Label
var _hovered := false


func _build(p_index: int) -> void:
	index = p_index
	custom_minimum_size = SIZE
	_icon = ItemIcon.icon(ICON_SIZE)
	_icon.position = Vector2(2, 2)
	add_child(_icon)
	_amount = ItemIcon.amount_label(SIZE)
	add_child(_amount)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


## Mostra `amount` de `item` (null = vazio) e a dica ao passar o mouse.
func show_item(item: ItemData, amount: int, tooltip: String) -> void:
	ItemIcon.show_stack(_icon, _amount, item, amount)
	tooltip_text = tooltip


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), UiStyle.SLOT_BACK)
	var border := UiStyle.BORDER
	if _hovered:
		border = UiStyle.BORDER_HOVER
	elif highlighted:
		border = UiStyle.ACCENT
	draw_rect(Rect2(Vector2.ZERO, SIZE), border, false, 1.0)


func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()
