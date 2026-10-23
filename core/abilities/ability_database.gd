class_name AbilityDatabase
extends DataCatalog
## Catálogo de habilidades: todos os `AbilityData` de `data/abilities/`. Um só por execução
## (`shared`): a rede e o save conferem cada id recebido contra ele.

const ABILITIES_DIR := "res://data/abilities/"

static var _shared: AbilityDatabase


static func shared() -> AbilityDatabase:
	if _shared == null:
		_shared = AbilityDatabase.new(ABILITIES_DIR)
	return _shared


func get_ability(id: StringName) -> AbilityData:
	return get_entry(id) as AbilityData
