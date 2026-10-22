extends TestCase
## Fabricação: receitas em dados, ingredientes, lugar e espaço no inventário (ADR-017).

const HAND: Array[RecipeData.Station] = [RecipeData.Station.HAND]
const EVERYWHERE: Array[RecipeData.Station] = [RecipeData.Station.HAND,
	RecipeData.Station.WORKBENCH, RecipeData.Station.NPC]


func test_recipe_data_is_consistent() -> void:
	var items := ItemDatabase.load_all()
	var recipes := RecipeDatabase.load_all()
	check(not recipes.entries().is_empty(), "há receitas em data/recipes/")
	for entry in recipes.entries():
		var recipe := entry as RecipeData
		check(recipe.result != null and items.has(recipe.result.id) and recipe.result_amount > 0,
			"%s produz um item conhecido" % recipe.id)
		check(not recipe.ingredients.is_empty(), "%s pede ingredientes" % recipe.id)
		for item_id in recipe.ingredients:
			check(items.has(item_id) and recipe.ingredients[item_id] > 0,
				"%s: ingrediente %s existe, quantidade positiva" % [recipe.id, item_id])


func test_craft_consumes_ingredients_and_gives_the_result() -> void:
	var recipe := RecipeDatabase.load_all().get_recipe(&"stone_axe")
	var inventory := Inventory.new(6, ItemDatabase.load_all())
	inventory.add(&"wood", 10)
	inventory.add(&"stone", 10)
	check(CraftingRules.craft(recipe, inventory, HAND), "fez o machado")
	check(inventory.count(&"stone_axe") == 1, "machado no inventário")
	check(inventory.count(&"wood") == 10 - recipe.ingredients[&"wood"]
		and inventory.count(&"stone") == 10 - recipe.ingredients[&"stone"], "gastou só a receita")


func test_missing_ingredients_change_nothing() -> void:
	var recipe := RecipeDatabase.load_all().get_recipe(&"stone_axe")
	var inventory := Inventory.new(6, ItemDatabase.load_all())
	inventory.add(&"wood", 10)
	check(CraftingRules.check(recipe, inventory, HAND) == CraftingRules.Check.MISSING_INGREDIENTS,
		"falta pedra")
	check(not CraftingRules.craft(recipe, inventory, HAND), "não fez")
	check(inventory.count(&"wood") == 10 and inventory.count(&"stone_axe") == 0, "nada mudou")


func test_station_recipes_need_the_station() -> void:
	var recipes := RecipeDatabase.load_all()
	var recipe := recipes.get_recipe(&"copper_axe")
	var inventory := Inventory.new(6, ItemDatabase.load_all())
	inventory.add(&"wood", 20)
	inventory.add(&"copper_ore", 20)
	check(CraftingRules.check(recipe, inventory, HAND) == CraftingRules.Check.NEEDS_STATION,
		"machado de cobre pede bancada")
	check(CraftingRules.check(recipe, inventory, EVERYWHERE) == CraftingRules.Check.OK,
		"com bancada, pode")
	check(recipe not in recipes.recipes_at(HAND) and recipe in recipes.recipes_at(EVERYWHERE),
		"a lista da mão não mostra receitas de bancada")


## Coluna "Fabricar" do inventário: só receitas da mão; apagada sem material; clicar fabrica e
## a lista se atualiza.
func test_crafting_list_shows_hand_recipes_and_crafts_on_click() -> void:
	var game := start_game()
	var inventory := (game.session as GameSession).get_inventory(game.local_player_id())
	var panel: InventoryPanel = game.get_node("UI/InventoryPanel")
	panel.set_open(true)
	var rows: Array[RecipeRow] = []
	rows.assign(panel.find_children("*", "RecipeRow", true, false))
	var ids := rows.map(func(row: RecipeRow) -> StringName: return row.recipe.id)
	check(&"stone_axe" in ids and &"copper_axe" in ids, "receitas da mão e da bancada")
	check(not rows[ids.find(&"copper_axe")]._available, "longe de bancada: a de bancada fica apagada")
	var axe: RecipeRow = rows[ids.find(&"stone_axe")]
	check(not axe._available and axe.modulate.a < 1.0, "sem material: apagada")
	axe._gui_input(_left_click())
	check(inventory.count(&"stone_axe") == 0, "clicar apagada não faz nada")

	inventory.add(&"wood", 10)
	inventory.add(&"stone", 10)
	await physics_frames(1)
	check(axe._available and axe.modulate.a == 1.0, "com material: acesa")
	axe._gui_input(_left_click())
	check(inventory.count(&"stone_axe") == 1, "clicar fabricou")


## Clicar no título recolhe/abre as receitas; a escolha vale na próxima vez que o jogo abrir.
func test_crafting_list_collapses_and_remembers() -> void:
	var game := start_game()
	var panel: InventoryPanel = game.get_node("UI/InventoryPanel")
	panel.set_open(true)
	var list: CraftingList = panel.find_children("*", "CraftingList", true, false)[0]
	check(list.is_open(), "começa aberta")
	list._on_title_input(_left_click())
	check(not list.is_open() and not list._scroll.visible, "clique no título recolheu")
	cleanup()
	game = start_game()
	panel = game.get_node("UI/InventoryPanel")
	list = panel.find_children("*", "CraftingList", true, false)[0]
	check(not list.is_open(), "lembrou: continua recolhida")
	list.set_open(true)


## Os ingredientes liberam espaço: com o inventário cheio, ainda dá para fabricar se uma pilha
## de ingrediente acabar. Se nada liberar espaço, não fabrica (nada se perde).
func test_full_inventory_counts_the_space_ingredients_free() -> void:
	var recipe := RecipeDatabase.load_all().get_recipe(&"stone_axe")
	var inventory := Inventory.new(2, ItemDatabase.load_all())
	inventory.add(&"wood", 10)
	inventory.add(&"stone", recipe.ingredients[&"stone"])
	check(CraftingRules.craft(recipe, inventory, HAND), "as pedras acabaram e o machado ocupou o espaço")
	inventory = Inventory.new(2, ItemDatabase.load_all())
	inventory.add(&"wood", 10)
	inventory.add(&"stone", 10)
	check(CraftingRules.check(recipe, inventory, HAND) == CraftingRules.Check.INVENTORY_FULL,
		"sem espaço para o machado")
	check(inventory.count(&"wood") == 10 and inventory.count(&"stone") == 10, "nada foi gasto")


func _left_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click
