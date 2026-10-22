class_name InventorySlot
extends SlotView
## Um espaço da tela de inventário: ícone, quantidade e o item (nome e bônus) ao passar o
## mouse. Clique esquerdo: pegar / pôr / juntar / trocar com a mão. Botão direito: menu de
## opções (dividir, soltar, equipar; só com a mão vazia). Quem decide é o host.

var _inventory: Inventory
var _items: ItemDatabase


func setup(p_index: int, inventory: Inventory, items: ItemDatabase) -> void:
	_inventory = inventory
	_items = items
	_build(p_index)
	refresh()


func refresh() -> void:
	var item := _items.get_item(_inventory.slot_item(index))
	show_item(item, _inventory.slot_amount(index), ItemTexts.describe(item))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT and _inventory.slot_amount(index) > 0 \
			and not _inventory.is_holding():
		menu_requested.emit(index)
		accept_event()
