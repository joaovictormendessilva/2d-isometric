class_name CraftingRules
extends RefCounted
## Regras da fabricação (sem nós): se o jogador pode fazer uma receita e a troca em si. Usadas
## pelo host para decidir e por todos para mostrar.

enum Check { OK, NEEDS_STATION, MISSING_INGREDIENTS, INVENTORY_FULL }


## `stations`: lugares de fabricação ao alcance do jogador (a mão sempre está).
static func check(recipe: RecipeData, inventory: Inventory,
		stations: Array[RecipeData.Station]) -> Check:
	if recipe.station not in stations:
		return Check.NEEDS_STATION
	for item_id in recipe.ingredients:
		if inventory.count(item_id) < recipe.ingredients[item_id]:
			return Check.MISSING_INGREDIENTS
	if not inventory.can_exchange(recipe.ingredients, recipe.get_output()):
		return Check.INVENTORY_FULL
	return Check.OK


## Faz a receita uma vez, se puder: tira os ingredientes e guarda o resultado.
static func craft(recipe: RecipeData, inventory: Inventory,
		stations: Array[RecipeData.Station]) -> bool:
	if check(recipe, inventory, stations) != Check.OK:
		return false
	for item_id in recipe.ingredients:
		inventory.remove(item_id, recipe.ingredients[item_id])
	inventory.add(recipe.result.id, recipe.result_amount)
	return true
