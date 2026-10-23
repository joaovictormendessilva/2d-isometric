class_name EquipmentSlot
extends SlotView
## Um espaço de equipamento na tela: o item vestido (dica com nome e bônus) ou, vazio, o nome
## do espaço ("Cabeça"). Com um equipamento na mão, fica dourado se ele cabe aqui. Clique:
## veste o item da mão ou tira o vestido para a mão (pedido ao host). Botão direito: escolher a
## aparência (transmog, ADR-030); outra aparência ou escondida aparece num selo no canto.

var _equipment: Equipment
var _inventory: Inventory
var _badge := LookBadge.new()


func setup(p_index: int, equipment: Equipment, inventory: Inventory) -> void:
	_equipment = equipment
	_inventory = inventory
	_build(p_index)
	_badge.position = SIZE - LookBadge.SIZE
	add_child(_badge)
	refresh()


func refresh() -> void:
	var item := _equipment.item(index)
	var slot_name := EquipmentData.Slot.keys()[_equipment.slot_type(index)] as String
	var lines: Array[String] = [ItemTexts.describe(item) if item \
		else Texts.get_text(StringName("EQUIP_SLOT_" + slot_name))]
	var look := _equipment.look(index)
	if look == Equipment.HIDDEN_LOOK:
		lines.append(Texts.get_text(&"EQUIP_LOOK_HIDDEN"))
	elif look != Equipment.OWN_LOOK:
		lines.append(Texts.format(&"EQUIP_LOOK_SHOWN", [_equipment.shown(index).get_display_name()]))
	lines.append(Texts.get_text(&"EQUIP_LOOK_HINT"))
	show_item(item, 1, "\n".join(lines))
	_badge.show_look(_equipment.shown(index) if look != Equipment.OWN_LOOK else null,
		look == Equipment.HIDDEN_LOOK)
	var held := _equipment.data_of(_inventory.held_item())
	highlighted = held != null and EquipmentRules.fits(_equipment, index, held)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT and not _inventory.is_holding():
		menu_requested.emit(index)
		accept_event()


## Selo no canto: o ícone da aparência escolhida, ou um traço se escondida. Some com a própria.
class LookBadge:
	extends Control

	const SIZE := Vector2(10, 10)
	const ICON_RECT := Rect2(1, 1, 8, 8)  # ícones 8x8 em escala 1

	var _icon: Texture2D
	var _hidden := false

	func _init() -> void:
		size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func show_look(look: EquipmentData, hidden: bool) -> void:
		_icon = look.icon if look else null
		_hidden = hidden
		visible = _icon != null or hidden
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), UiStyle.SLOT_BACK)
		draw_rect(Rect2(Vector2.ZERO, SIZE), UiStyle.BORDER_HOVER, false, 1.0)
		if _icon:
			draw_texture_rect(_icon, ICON_RECT, false)
		elif _hidden:
			draw_line(Vector2(2, 7), Vector2(7, 2), UiStyle.BORDER_HOVER, 1.0)
