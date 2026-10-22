class_name EquipmentSlot
extends SlotView
## Um espaço de equipamento na tela: o item vestido (dica com nome e bônus) ou, vazio, o nome
## do espaço ("Cabeça"). Com um equipamento na mão, fica dourado se ele cabe aqui. Clique:
## veste o item da mão ou tira o vestido para a mão (pedido ao host).

var _equipment: Equipment
var _inventory: Inventory


func setup(p_index: int, equipment: Equipment, inventory: Inventory) -> void:
	_equipment = equipment
	_inventory = inventory
	_build(p_index)
	refresh()


func refresh() -> void:
	var item := _equipment.item(index)
	var slot_name := EquipmentData.Slot.keys()[_equipment.slot_type(index)] as String
	show_item(item, 1, ItemTexts.describe(item) if item \
		else Texts.get_text(StringName("EQUIP_SLOT_" + slot_name)))
	var held := _equipment.data_of(_inventory.held_item())
	highlighted = held != null and EquipmentRules.fits(_equipment, index, held)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
		accept_event()
