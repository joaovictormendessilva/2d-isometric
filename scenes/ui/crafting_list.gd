class_name CraftingList
extends VBoxContainer
## Coluna "Fabricar" do inventário: receitas da mão e da bancada (as de NPC ficam com os
## NPCs). As de bancada aparecem sempre, apagadas longe de uma, para o jogador saber que
## existem. Atualiza quando o inventário muda ou quando o jogador chega perto de / se afasta de
## uma estação; clicar numa receita pede ao host para fabricar (PlayerStateSync).

const ROW_GAP := 2
const LISTED_STATIONS: Array[RecipeData.Station] = [RecipeData.Station.HAND,
	RecipeData.Station.WORKBENCH]

var _inventory: Inventory
var _player_state: PlayerStateSync
var _player_id := 0
var _rows: Array[RecipeRow] = []
var _stations: Array[RecipeData.Station] = []
var _refresh_queued := false


func setup(inventory: Inventory, items: ItemDatabase, player_state: PlayerStateSync,
		player_id: int) -> void:
	_inventory = inventory
	_player_state = player_state
	_player_id = player_id
	add_theme_constant_override(&"separation", ROW_GAP)
	var title := Label.new()
	title.text = Texts.get_text(&"CRAFT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	for recipe in player_state.recipes.recipes_at(LISTED_STATIONS):
		var row := RecipeRow.new()
		row.setup(recipe, items)
		row.craft_requested.connect(player_state.request_craft)
		add_child(row)
		_rows.append(row)
	inventory.slot_changed.connect(_queue_refresh.unbind(1))
	_refresh()


## Estações ao alcance mudam com o andar do jogador: confere a cada quadro com a janela aberta
## (poucas estruturas; barato).
func _process(_delta: float) -> void:
	if _player_state and is_visible_in_tree() and _player_state.stations_of(_player_id) != _stations:
		_refresh()


## Uma fabricação muda vários espaços de uma vez: atualiza uma vez só, no fim do quadro.
func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	_stations = _player_state.stations_of(_player_id)
	for row in _rows:
		row.refresh(_inventory, _stations)
