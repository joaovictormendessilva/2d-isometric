class_name InventoryPanel
extends Control
## Inventário do jogador LOCAL (abre e fecha com I / Tab / botão Y; Esc fecha). Janela livre:
## o jogador a arrasta para onde preferir e anda e luta com ela aberta.
## Itens: um clique pega a pilha (ela segue o ponteiro); clicar num espaço põe, junta ou troca;
## clicar fora da janela joga no chão (estruturas, como a bancada, são colocadas ali); botão
## direito abre um menu: usar (poção), dividir (a parte separada vai para a mão), soltar a
## pilha no chão, equipar ou, com a loja de um NPC aberta, vender (num espaço de equipamento: a
## aparência). Embaixo da grade, as moedas.
## Fechar com algo na mão devolve aos espaços. Ao lado, as colunas de equipamento
## (EquipmentColumn) e de fabricação (CraftingList).
## Cada ação é um pedido ao host (PlayerStateSync).

const COLUMNS := 6
const SLOT_GAP := UiStyle.GAP
const COLUMN_GAP := 8
const SETTINGS_KEY := "inventory"

## Prévia de estruturas no mundo: com uma bancada na mão, clicar fora coloca em vez de jogar.
var placement: PlacementPreview
## Loja aberta (se houver): o menu do botão direito oferece vender para ela.
var shop: ShopPanel

var _inventory: Inventory
var _player_state: PlayerStateSync
var _window := DraggableWindow.new()
var _split := SplitDialog.new()
var _menu := SlotMenu.new()
var _look_menu := ChoiceMenu.new()  # aparência de um espaço de equipamento
var _held := HeldItemCursor.new()
var _slots: Array[InventorySlot] = []
var _grid: GridContainer
var _items: ItemDatabase
var _equipment: Equipment


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # só a janela pega o mouse
	# Na árvore desde já: sem setup (ex.: cliente recusado) nada fica solto.
	add_child(_window)
	add_child(_split)
	add_child(_menu)
	add_child(_look_menu)
	add_child(_held)
	add_to_group(LocalPlayerInput.MOUSE_CAPTURE_GROUP)


func setup(inventory: Inventory, items: ItemDatabase, player_state: PlayerStateSync,
		player_id: int) -> void:
	_inventory = inventory
	_player_state = player_state
	_window.setup(Texts.get_text(&"INVENTORY_TITLE"), SETTINGS_KEY)
	# Equipamento, itens e fabricação, da esquerda para a direita.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", COLUMN_GAP)
	_window.add_content(columns)
	_equipment = player_state.session.get_equipment(player_id)
	var equipment_column := EquipmentColumn.new()
	columns.add_child(equipment_column)
	equipment_column.setup(_equipment, inventory, player_state,
		player_state.session.get_appearances(player_id), _look_menu)
	var items_column := VBoxContainer.new()
	columns.add_child(items_column)
	var crafting := CraftingList.new()
	columns.add_child(crafting)
	crafting.setup(inventory, items, player_state, player_id)
	crafting.toggled.connect(_window.fit_content)
	_items = items
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", SLOT_GAP)
	_grid.add_theme_constant_override(&"v_separation", SLOT_GAP)
	items_column.add_child(_grid)
	_fit_slots()
	inventory.resized.connect(_fit_slots)
	var coins := CoinLabel.new()
	coins.setup(player_state.session.get_wallet(player_id))
	items_column.add_child(coins)
	# Dica na largura da grade.
	items_column.add_child(HintLabel.create(Texts.get_text(&"INVENTORY_HINT"),
		_grid.get_combined_minimum_size().x))
	_split.confirmed.connect(player_state.request_split)
	_menu.split_chosen.connect(_on_split_requested)
	_menu.drop_chosen.connect(player_state.request_drop_slot)
	_menu.use_chosen.connect(player_state.request_use)
	_menu.equip_chosen.connect(player_state.request_equip)
	_menu.sell_chosen.connect(player_state.request_sell)
	_held.setup(inventory, items)
	inventory.slot_changed.connect(func(index: int) -> void: _slots[index].refresh())


## Um quadrado por espaço do inventário: cria ou remove do fim quando a mochila muda o tamanho.
func _fit_slots() -> void:
	while _slots.size() > _inventory.capacity():
		_slots.pop_back().free()
	for index in range(_slots.size(), _inventory.capacity()):
		var slot := InventorySlot.new()
		slot.setup(index, _inventory, _items)
		slot.clicked.connect(_player_state.request_click)
		slot.menu_requested.connect(_on_menu_requested)
		_grid.add_child(slot)
		_slots.append(slot)
	_window.fit_content()


## Com um item na mão, o clique é do inventário (pôr ou jogar fora), não um ataque.
func captures_mouse() -> bool:
	return visible and _inventory != null and _inventory.is_holding()


func set_open(open: bool) -> void:
	visible = open
	_split.hide()
	_menu.hide()
	_look_menu.hide()
	if not open and _inventory.is_holding():
		_player_state.request_return_held()


func _unhandled_input(event: InputEvent) -> void:
	if _inventory == null:
		return
	if event.is_action_pressed(&"inventory") or (visible and event.is_action_pressed(&"ui_cancel")):
		set_open(not visible)
		get_viewport().set_input_as_handled()
		return
	# Clique fora da janela (a janela e os espaços já tratam os cliques sobre eles): coloca a
	# estrutura que está na mão, ou joga o item no chão.
	var button := event as InputEventMouseButton
	if visible and button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT \
			and _inventory.is_holding():
		if placement and placement.is_active():
			if placement.can_place:
				_player_state.request_place(placement.position)
		else:
			_player_state.request_drop_held()
		get_viewport().set_input_as_handled()


func _on_split_requested(index: int) -> void:
	_split.open(index, _inventory.slot_amount(index), get_global_mouse_position())


func _on_menu_requested(index: int) -> void:
	_split.hide()
	var item_id := _inventory.slot_item(index)
	var usable := ConsumableRules.is_usable(_items.get_item(item_id))
	var equippable := _equipment.data_of(item_id) != null
	var price := shop.sell_price_of(item_id) if shop else 0
	_menu.open(index, _inventory.slot_amount(index), usable, equippable, price,
		get_global_mouse_position())
