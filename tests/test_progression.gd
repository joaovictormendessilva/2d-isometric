extends TestCase
## Ciclo de progressão (F5): o drop especial do chefe vira ingrediente de equipamento melhor.

const MONSTERS_DIR := "res://data/monsters/"
const HAND: Array[RecipeData.Station] = [RecipeData.Station.HAND]
const WORKBENCH: Array[RecipeData.Station] = [RecipeData.Station.HAND,
	RecipeData.Station.WORKBENCH]


## Todo item que só chefes deixam cair serve para alguma receita (senão o chefe não libera nada).
func test_boss_only_drops_are_used_by_recipes() -> void:
	var boss_items: Dictionary[StringName, bool] = {}
	var common_items: Dictionary[StringName, bool] = {}
	for file in DirAccess.get_files_at(MONSTERS_DIR):
		var monster := load(MONSTERS_DIR + file.trim_suffix(".remap")) as MonsterData
		if monster == null:
			continue
		for entry in monster.drops:
			(boss_items if monster.is_boss else common_items)[entry.item.id] = true
	var used: Dictionary[StringName, bool] = {}
	for entry in RecipeDatabase.load_all().entries():
		for item_id in (entry as RecipeData).ingredients:
			used[item_id] = true
	check(not boss_items.is_empty(), "há chefes com drops em data/monsters/")
	for item_id in boss_items:
		if not common_items.has(item_id):
			check(used.has(item_id), "o drop de chefe %s é ingrediente de uma receita" % item_id)


func test_king_slime_core_crafts_a_crown_better_than_the_copper_helmet() -> void:
	var items := ItemDatabase.load_all()
	var recipe := RecipeDatabase.load_all().get_recipe(&"king_slime_crown")
	check(recipe != null and recipe.ingredients.has(&"king_slime_core"), "a coroa pede o núcleo")
	var inventory := Inventory.new(6, items)
	for item_id in recipe.ingredients:
		inventory.add(item_id, recipe.ingredients[item_id])
	check(CraftingRules.check(recipe, inventory, HAND, RecipeBook.new())
			== CraftingRules.Check.NEEDS_STATION,
		"a coroa é feita na bancada")
	check(CraftingRules.craft(recipe, inventory, WORKBENCH, RecipeBook.new()), "fez a coroa")
	check(inventory.count(&"king_slime_crown") == 1 and inventory.count(&"king_slime_core") == 0,
		"gastou o núcleo e deu a coroa")
	var crown := items.get_item(&"king_slime_crown") as EquipmentData
	var helmet := items.get_item(&"copper_helmet") as EquipmentData
	check(crown.get_slot() == helmet.get_slot(), "a coroa ocupa a cabeça, como o elmo")
	check(crown.bonuses.max_health > helmet.bonuses.max_health
			and crown.bonuses.defense > helmet.bonuses.defense,
		"a coroa é melhor que o elmo de cobre")
