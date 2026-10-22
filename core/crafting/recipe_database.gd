class_name RecipeDatabase
extends DataCatalog
## Catálogo de receitas: todos os `RecipeData` de `data/recipes/`.

const RECIPES_DIR := "res://data/recipes/"


static func load_all(directory: String = RECIPES_DIR) -> RecipeDatabase:
	return RecipeDatabase.new(directory)


func get_recipe(id: StringName) -> RecipeData:
	return get_entry(id) as RecipeData


## Receitas feitas num destes lugares: primeiro as da mão, depois as da bancada...; dentro de
## cada lugar, na ordem dos ids (lista estável para a tela).
func recipes_at(stations: Array[RecipeData.Station]) -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	for entry in entries():
		var recipe := entry as RecipeData
		if recipe and recipe.station in stations:
			result.append(recipe)
	result.sort_custom(func(a: RecipeData, b: RecipeData) -> bool:
		return a.id < b.id if a.station == b.station else a.station < b.station)
	return result
