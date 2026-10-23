class_name RecipeRow
extends ListRow
## Uma receita na lista de fabricação: ícone e nome do resultado e, embaixo, cada ingrediente
## com a quantidade pedida (vermelha se faltar). Clique pede para fabricar; quem decide é o host.
## Apagada quando não dá para fazer agora (o motivo aparece ao passar o mouse).

signal craft_requested(recipe_id: StringName)

const MISSING_COLOR := UiStyle.DANGER
## Motivo de não poder fabricar → chave de texto.
const CHECK_TEXTS := {
	CraftingRules.Check.NOT_LEARNED: &"CRAFT_NOT_LEARNED",
	CraftingRules.Check.NEEDS_STATION: &"CRAFT_NEEDS_STATION",
	CraftingRules.Check.MISSING_INGREDIENTS: &"CRAFT_MISSING_INGREDIENTS",
	CraftingRules.Check.INVENTORY_FULL: &"CRAFT_INVENTORY_FULL",
}

var recipe: RecipeData

var _items: ItemDatabase
var _chips: Dictionary[StringName, HBoxContainer] = {}


func setup(p_recipe: RecipeData, items: ItemDatabase) -> void:
	recipe = p_recipe
	_items = items
	build(recipe.result)
	for item_id in recipe.ingredients:
		var ingredient := ListRow.chip(items.get_item(item_id).icon, recipe.ingredients[item_id])
		details.add_child(ingredient)
		_chips[item_id] = ingredient
	activated.connect(func() -> void: craft_requested.emit(recipe.id))


## Mostra o que falta e se dá para fabricar com este inventário, estes lugares e estas receitas
## aprendidas.
func refresh(inventory: Inventory, stations: Array[RecipeData.Station], book: RecipeBook) -> void:
	var state := CraftingRules.check(recipe, inventory, stations, book)
	for item_id in recipe.ingredients:
		var have := inventory.count(item_id)
		var need: int = recipe.ingredients[item_id]
		# Quantidade = rótulo do chip (ver ListRow.chip).
		_chips[item_id].get_child(1).modulate = Color.WHITE if have >= need else MISSING_COLOR
		_chips[item_id].tooltip_text = Texts.format(&"CRAFT_INGREDIENT",
			[_items.get_item(item_id).get_display_name(), have, need])
	var tooltip := ItemTexts.describe(recipe.result)
	if state != CraftingRules.Check.OK:
		tooltip += "\n" + Texts.get_text(CHECK_TEXTS[state])
	set_available(state == CraftingRules.Check.OK, tooltip)
