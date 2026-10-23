class_name CraftingList
extends VBoxContainer
## Coluna "Fabricar" do inventário: receitas da mão e da bancada. As de bancada aparecem sempre,
## apagadas longe de uma, e as que se aprendem com um NPC também, apagadas até aprender, para o
## jogador saber que existem. Atualiza quando o inventário muda, quando aprende uma receita ou
## quando chega perto de / se afasta de uma estação; clicar numa receita pede ao host para
## fabricar (PlayerStateSync).
## Recolhível (pedido do João): clicar no título mostra/esconde as receitas; a escolha fica
## guardada neste computador (UserSettings).

## Mudou de aberta para recolhida ou vice-versa (a janela ajusta o tamanho).
signal toggled

const ROW_GAP := UiStyle.GAP
## Altura da lista de receitas (rola quando há mais): cabe na tela com a janela inteira.
const LIST_HEIGHT := 150.0
const LISTED_STATIONS: Array[RecipeData.Station] = [RecipeData.Station.HAND,
	RecipeData.Station.WORKBENCH]
const SETTINGS_SECTION := "inventory"
const SETTINGS_KEY := "crafting_open"
const OPEN_MARK := "[-]"
const CLOSED_MARK := "[+]"
const HOVER_COLOR := UiStyle.ACCENT

var _inventory: Inventory
var _book: RecipeBook
var _player_state: PlayerStateSync
var _player_id := 0
var _title := Label.new()
var _list := VBoxContainer.new()
## Altura fixa com rolagem: a lista cresce com as receitas, a janela não.
var _scroll := ScrollContainer.new()
var _rows: Array[RecipeRow] = []
var _stations: Array[RecipeData.Station] = []
var _refresh_queued := false


func setup(inventory: Inventory, items: ItemDatabase, player_state: PlayerStateSync,
		player_id: int) -> void:
	_inventory = inventory
	_book = player_state.session.get_recipe_book(player_id)
	_player_state = player_state
	_player_id = player_id
	add_theme_constant_override(&"separation", ROW_GAP)
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_title.gui_input.connect(_on_title_input)
	_title.mouse_entered.connect(func() -> void: _title.modulate = HOVER_COLOR)
	_title.mouse_exited.connect(func() -> void: _title.modulate = Color.WHITE)
	add_child(_title)
	_list.add_theme_constant_override(&"separation", ROW_GAP)
	_scroll.custom_minimum_size.y = LIST_HEIGHT
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	add_child(_scroll)
	for recipe in player_state.recipes.recipes_at(LISTED_STATIONS):
		var row := RecipeRow.new()
		row.setup(recipe, items)
		row.craft_requested.connect(player_state.request_craft)
		_list.add_child(row)
		_rows.append(row)
	inventory.slot_changed.connect(_queue_refresh.unbind(1))
	_book.learned.connect(_queue_refresh.unbind(2))
	_apply_open(UserSettings.get_value(SETTINGS_SECTION, SETTINGS_KEY, true))


func is_open() -> bool:
	return _scroll.visible


func set_open(open: bool) -> void:
	UserSettings.set_value(SETTINGS_SECTION, SETTINGS_KEY, open)
	_apply_open(open)
	toggled.emit()


## Estações ao alcance mudam com o andar do jogador: confere a cada quadro com a lista à vista
## (poucas estruturas; barato).
func _process(_delta: float) -> void:
	if _player_state and _list.is_visible_in_tree() \
			and _player_state.stations_of(_player_id) != _stations:
		_refresh()


func _apply_open(open: bool) -> void:
	_scroll.visible = open
	_title.text = "%s %s" % [OPEN_MARK if open else CLOSED_MARK, Texts.get_text(&"CRAFT_TITLE")]
	if open:
		_refresh()


func _on_title_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		set_open(not is_open())
		_title.accept_event()


## Uma fabricação muda vários espaços de uma vez: atualiza uma vez só, no fim do quadro.
func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	_stations = _player_state.stations_of(_player_id)
	for row in _rows:
		row.refresh(_inventory, _stations, _book)
