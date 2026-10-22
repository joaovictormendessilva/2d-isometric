class_name EquipmentColumn
extends VBoxContainer
## Coluna "Equipamento" do inventário: os espaços de `EquipmentLayout` em duas colunas (mãos,
## cabeça e peito, pernas e mochila, acessórios). Atualiza quando o equipamento ou a mão
## mudam (o destaque dourado depende do item na mão).

const COLUMNS := 2


func setup(equipment: Equipment, inventory: Inventory, player_state: PlayerStateSync) -> void:
	var title := Label.new()
	title.text = Texts.get_text(&"EQUIPMENT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", UiStyle.GAP)
	grid.add_theme_constant_override(&"v_separation", UiStyle.GAP)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(grid)
	var slots: Array[EquipmentSlot] = []
	for index in equipment.size():
		var slot := EquipmentSlot.new()
		slot.setup(index, equipment, inventory)
		slot.clicked.connect(player_state.request_click_equipment)
		grid.add_child(slot)
		slots.append(slot)
	var refresh_all := func() -> void:
		for slot in slots:
			slot.refresh()
	equipment.slot_changed.connect(refresh_all.unbind(1))
	inventory.held_changed.connect(refresh_all)
