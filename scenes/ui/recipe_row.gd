class_name RecipeRow
extends PanelContainer
## Uma receita na lista de fabricação: ícone e nome do resultado e, embaixo, cada ingrediente
## com a quantidade pedida (vermelha se faltar). Clique pede para fabricar; quem decide é o host.
## Apagada quando não dá para fazer agora (o motivo aparece ao passar o mouse).

signal craft_requested(recipe_id: StringName)

const ICON_SIZE := Vector2(16, 16)
const MISSING_COLOR := Color(1.0, 0.45, 0.4)
const UNAVAILABLE_ALPHA := 0.45
## Motivo de não poder fabricar → chave de texto.
const CHECK_TEXTS := {
	CraftingRules.Check.NEEDS_STATION: &"CRAFT_NEEDS_STATION",
	CraftingRules.Check.MISSING_INGREDIENTS: &"CRAFT_MISSING_INGREDIENTS",
	CraftingRules.Check.INVENTORY_FULL: &"CRAFT_INVENTORY_FULL",
}

var recipe: RecipeData

var _items: ItemDatabase
var _style := StyleBoxFlat.new()
var _amounts: Dictionary[StringName, Label] = {}
var _chips: Dictionary[StringName, Control] = {}
var _available := false


func setup(p_recipe: RecipeData, items: ItemDatabase) -> void:
	recipe = p_recipe
	_items = items
	_style.bg_color = InventorySlot.BACK_COLOR
	_style.border_color = InventorySlot.BORDER_COLOR
	_style.set_border_width_all(1)
	_style.set_content_margin_all(2)
	add_theme_stylebox_override(&"panel", _style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon := ItemIcon.icon(ICON_SIZE)
	icon.custom_minimum_size = ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.texture = recipe.result.icon
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_label := Label.new()
	name_label.text = recipe.result.get_display_name()
	column.add_child(name_label)
	var ingredients := HBoxContainer.new()
	ingredients.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(ingredients)
	for item_id in recipe.ingredients:
		ingredients.add_child(_ingredient_chip(item_id, recipe.ingredients[item_id]))
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


## Mostra o que falta e se dá para fabricar com este inventário e estes lugares.
func refresh(inventory: Inventory, stations: Array[RecipeData.Station]) -> void:
	var state := CraftingRules.check(recipe, inventory, stations)
	_available = state == CraftingRules.Check.OK
	modulate.a = 1.0 if _available else UNAVAILABLE_ALPHA
	for item_id in recipe.ingredients:
		var have := inventory.count(item_id)
		var need: int = recipe.ingredients[item_id]
		_amounts[item_id].modulate = Color.WHITE if have >= need else MISSING_COLOR
		_chips[item_id].tooltip_text = Texts.format(&"CRAFT_INGREDIENT",
			[_items.get_item(item_id).get_display_name(), have, need])
	tooltip_text = recipe.result.get_display_name()
	if not _available:
		tooltip_text += "\n" + Texts.get_text(CHECK_TEXTS[state])


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		if _available:
			craft_requested.emit(recipe.id)
		accept_event()  # mesmo indisponível: o clique é da janela, não do mundo


func _ingredient_chip(item_id: StringName, need: int) -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override(&"separation", 0)
	var icon := ItemIcon.icon(ICON_SIZE)
	icon.custom_minimum_size = ICON_SIZE
	icon.texture = _items.get_item(item_id).icon
	chip.add_child(icon)
	var amount := Label.new()
	amount.text = str(need)
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(amount)
	_amounts[item_id] = amount
	_chips[item_id] = chip
	return chip


func _set_hovered(value: bool) -> void:
	_style.border_color = InventorySlot.HOVER_COLOR if value else InventorySlot.BORDER_COLOR
	queue_redraw()
