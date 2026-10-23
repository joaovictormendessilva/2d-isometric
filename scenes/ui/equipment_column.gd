class_name EquipmentColumn
extends VBoxContainer
## Coluna "Equipamento" do inventário: os espaços de `EquipmentLayout` em duas colunas (mãos,
## cabeça e peito, pernas e mochila, acessórios). Atualiza quando o equipamento, a aparência ou a
## mão mudam (o destaque dourado depende do item na mão). Botão direito num espaço: menu de
## aparências (a do item vestido, as colecionadas do tipo do espaço, esconder).

const COLUMNS := 2

var _equipment: Equipment
var _collection: AppearanceCollection
var _player_state: PlayerStateSync
var _menu: ChoiceMenu


## `menu`: onde as aparências são escolhidas (fica fora da coluna, por cima da tela).
func setup(equipment: Equipment, inventory: Inventory, player_state: PlayerStateSync,
		collection: AppearanceCollection, menu: ChoiceMenu) -> void:
	_equipment = equipment
	_collection = collection
	_player_state = player_state
	_menu = menu
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
		slot.menu_requested.connect(_open_look_menu)
		grid.add_child(slot)
		slots.append(slot)
	var refresh_all := func() -> void:
		for slot in slots:
			slot.refresh()
	equipment.slot_changed.connect(refresh_all.unbind(1))
	equipment.look_changed.connect(refresh_all.unbind(1))
	inventory.held_changed.connect(refresh_all)


## Aparências que o espaço pode mostrar agora, menos a atual: [[texto, id], ...].
func look_choices(index: int) -> Array:
	var choices := []
	var current := _equipment.look(index)
	if current != Equipment.OWN_LOOK:
		choices.append([Texts.get_text(&"LOOK_MENU_OWN"), Equipment.OWN_LOOK])
	for item_id in _collection.all():
		var item := _equipment.data_of(item_id)
		if item_id != current and EquipmentRules.is_valid_look(_equipment, index, item_id):
			choices.append([item.get_display_name(), item_id])
	if current != Equipment.HIDDEN_LOOK:
		choices.append([Texts.get_text(&"LOOK_MENU_HIDE"), Equipment.HIDDEN_LOOK])
	return choices


func _open_look_menu(index: int) -> void:
	var choices := []
	for choice: Array in look_choices(index):
		choices.append([choice[0], _player_state.request_set_look.bind(index, choice[1])])
	_menu.open(choices, get_viewport().get_mouse_position())
