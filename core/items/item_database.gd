class_name ItemDatabase
extends DataCatalog
## Catálogo de itens: todos os `ItemData` de `data/items/` (inclui ferramentas).

const ITEMS_DIR := "res://data/items/"


static func load_all(directory: String = ITEMS_DIR) -> ItemDatabase:
	return ItemDatabase.new(directory)


func get_item(id: StringName) -> ItemData:
	return get_entry(id) as ItemData


## Algum consumível usa esse grupo de espera? (Confere grupos vindos da rede.)
func has_cooldown_group(group: StringName) -> bool:
	return entries().any(func(entry: Resource) -> bool:
		return entry is ConsumableData and entry.cooldown_group == group)


## Ferramentas entre os itens que o inventário tem.
func tools_in(inventory: Inventory) -> Array[ToolData]:
	var tools: Array[ToolData] = []
	for id in inventory.get_counts():
		var tool := get_entry(id) as ToolData
		if tool and inventory.count(id) > 0:
			tools.append(tool)
	return tools
