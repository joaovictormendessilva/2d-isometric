class_name EffectDatabase
extends DataCatalog
## Catálogo de efeitos: todos os `StatusEffectData` de `data/effects/`. Um só por execução
## (`shared`): a rede e o save conferem cada id recebido contra ele.

const EFFECTS_DIR := "res://data/effects/"

static var _shared: EffectDatabase


static func shared() -> EffectDatabase:
	if _shared == null:
		_shared = EffectDatabase.new(EFFECTS_DIR)
	return _shared


func get_effect(id: StringName) -> StatusEffectData:
	return get_entry(id) as StatusEffectData
