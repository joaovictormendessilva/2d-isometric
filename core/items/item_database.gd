class_name ItemDatabase
extends RefCounted
## Catálogo de itens: carrega todos os `ItemData` de `data/items/` e busca por id.

const ITEMS_DIR := "res://data/items/"

var _items: Dictionary[StringName, ItemData] = {}


static func load_all(directory: String = ITEMS_DIR) -> ItemDatabase:
	var db := ItemDatabase.new()
	for file in DirAccess.get_files_at(directory):
		# Em jogos exportados os recursos aparecem como "*.tres.remap".
		var path := directory + file.trim_suffix(".remap")
		if path.ends_with(".tres"):
			var item := load(path) as ItemData
			if item:
				db._items[item.id] = item
	return db


func get_item(id: StringName) -> ItemData:
	return _items.get(id)
