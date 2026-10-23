class_name CraftingRules
extends RefCounted
## Regras da fabricação (sem nós): se o jogador pode fazer uma receita e a troca em si. Usadas
## pelo host para decidir e por todos para mostrar.

enum Check { OK, NOT_LEARNED, NEEDS_STATION, MISSING_INGREDIENTS, INVENTORY_FULL }


## `stations`: lugares de fabricação ao alcance do jogador (a mão sempre está). `book`: receitas
## que ele aprendeu.
static func check(recipe: RecipeData, inventory: Inventory,
		stations: Array[RecipeData.Station], book: RecipeBook) -> Check:
	if not book.knows(recipe):
		return Check.NOT_LEARNED
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
		stations: Array[RecipeData.Station], book: RecipeBook) -> bool:
	if check(recipe, inventory, stations, book) != Check.OK:
		return false
	for item_id in recipe.ingredients:
		inventory.remove(item_id, recipe.ingredients[item_id])
	inventory.add(recipe.result.id, recipe.result_amount)
	return true
