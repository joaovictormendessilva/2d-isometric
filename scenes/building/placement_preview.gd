class_name PlacementPreview
extends Sprite2D
## Prévia da estrutura que o jogador LOCAL tem na mão (ex.: bancada): segue o ponteiro no
## chão, verde onde pode colocar e vermelha onde não pode (mesma regra do host,
## PlacementRules). O clique é tratado pelo inventário (InventoryPanel).

const VALID_COLOR := Color(0.55, 1.0, 0.55, 0.65)
const INVALID_COLOR := Color(1.0, 0.4, 0.4, 0.65)

## O ponto atual vale? (Só uma previsão: o host confere de novo.)
var can_place := false

var _inventory: Inventory
var _items: ItemDatabase
var _character: Character
var _structure: StructureData


func _ready() -> void:
	visible = false
	centered = false


func setup(inventory: Inventory, items: ItemDatabase, character: Character) -> void:
	_inventory = inventory
	_items = items
	_character = character
	if not inventory.held_changed.is_connected(_on_held_changed):
		inventory.held_changed.connect(_on_held_changed)
	_on_held_changed()


## Há uma estrutura na mão (o clique fora do inventário coloca em vez de jogar no chão)?
func is_active() -> bool:
	return _structure != null


func _process(_delta: float) -> void:
	if not is_active():
		return
	position = get_global_mouse_position().round()
	can_place = is_instance_valid(_character) and _character.is_alive() \
		and Region.of(_character).can_place(_structure, _character.position, position)
	modulate = VALID_COLOR if can_place else INVALID_COLOR


func _on_held_changed() -> void:
	var placeable := _items.get_item(_inventory.held_item()) as PlaceableData
	_structure = placeable.structure if placeable else null
	visible = is_active()
	can_place = false
	if _structure:
		texture = _structure.texture
		offset = _structure.sprite_offset
