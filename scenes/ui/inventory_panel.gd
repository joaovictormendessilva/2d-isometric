class_name InventoryPanel
extends Control
## Inventário do jogador LOCAL (abre e fecha com I / Tab / botão Y; Esc fecha). Janela livre:
## o jogador a arrasta para onde preferir e anda e luta com ela aberta.
## Itens: um clique pega a pilha (ela segue o ponteiro); clicar num espaço põe, junta ou troca;
## clicar fora da janela joga no chão (estruturas, como a bancada, são colocadas ali); botão
## direito abre um menu: dividir (a parte separada vai para a mão) ou soltar a pilha no chão.
## Fechar com algo na mão devolve aos espaços. Ao lado, a coluna de fabricação (CraftingList).
## Cada ação é um pedido ao host (PlayerStateSync).

const COLUMNS := 6
const SLOT_GAP := UiStyle.GAP
const COLUMN_GAP := 8
const SETTINGS_KEY := "inventory"
const HINT_ALPHA := UiStyle.HINT_ALPHA

## Prévia de estruturas no mundo: com uma bancada na mão, clicar fora coloca em vez de jogar.
var placement: PlacementPreview

var _inventory: Inventory
var _player_state: PlayerStateSync
var _window := DraggableWindow.new()
var _split := SplitDialog.new()
var _menu := SlotMenu.new()
var _held := HeldItemCursor.new()
var _slots: Array[InventorySlot] = []
var _grid: GridContainer
var _items: ItemDatabase


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # só a janela pega o mouse
	# Na árvore desde já: sem setup (ex.: cliente recusado) nada fica solto.
	add_child(_window)
	add_child(_split)
	add_child(_menu)
	add_child(_held)
	add_to_group(LocalPlayerInput.MOUSE_CAPTURE_GROUP)


func setup(inventory: Inventory, items: ItemDatabase, player_state: PlayerStateSync,
		player_id: int) -> void:
	_inventory = inventory
	_player_state = player_state
	_window.setup(Texts.get_text(&"INVENTORY_TITLE"), SETTINGS_KEY)
	# Itens à esquerda, fabricação à direita.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", COLUMN_GAP)
	_window.add_content(columns)
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
	var hint := Label.new()
	# Quebra de linha na largura da grade (sem largura fixa, o texto mede uma palavra por linha).
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = _grid.get_combined_minimum_size().x
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, HINT_ALPHA)
	hint.text = Texts.get_text(&"INVENTORY_HINT")
	items_column.add_child(hint)
	_split.confirmed.connect(player_state.request_split)
	_menu.split_chosen.connect(_on_split_requested)
	_menu.drop_chosen.connect(player_state.request_drop_slot)
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
	_menu.open(index, _inventory.slot_amount(index), get_global_mouse_position())
