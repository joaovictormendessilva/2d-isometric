class_name DataCatalog
extends RefCounted
## Catálogo de recursos de dados com `id` (itens, tipos de coleta...): carrega todos os
## `.tres` de uma pasta de `data/` e busca por id.

var _entries: Dictionary[StringName, Resource] = {}


func _init(directory: String) -> void:
	for file in DirAccess.get_files_at(directory):
		# Em jogos exportados os recursos aparecem como "*.tres.remap".
		var path := directory.path_join(file.trim_suffix(".remap"))
		if path.ends_with(".tres"):
			var entry := load(path)
			if entry and &"id" in entry:
				_entries[entry.id] = entry


func get_entry(id: StringName) -> Resource:
	return _entries.get(id)


func has(id: StringName) -> bool:
	return _entries.has(id)


func entries() -> Array[Resource]:
	var result: Array[Resource] = []
	result.assign(_entries.values())
	return result
