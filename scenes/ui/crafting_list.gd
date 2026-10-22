class_name CraftingList
extends VBoxContainer
## Coluna "Fabricar" do inventário: as receitas que o jogador local pode fazer onde está
## (por enquanto, as feitas na mão). Atualiza quando o inventário muda; clicar numa receita
## pede ao host para fabricar (PlayerStateSync).

const ROW_GAP := 2

var _inventory: Inventory
var _player_state: PlayerStateSync
var _player_id := 0
var _rows: Array[RecipeRow] = []
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
	for recipe in player_state.recipes.recipes_at(player_state.stations_of(player_id)):
		var row := RecipeRow.new()
		row.setup(recipe, items)
		row.craft_requested.connect(player_state.request_craft)
		add_child(row)
		_rows.append(row)
	inventory.slot_changed.connect(_queue_refresh.unbind(1))
	_refresh()


## Uma fabricação muda vários espaços de uma vez: atualiza uma vez só, no fim do quadro.
func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	var stations := _player_state.stations_of(_player_id)
	for row in _rows:
		row.refresh(_inventory, stations)
