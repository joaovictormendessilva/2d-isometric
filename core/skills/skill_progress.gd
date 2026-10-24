class_name SkillProgress
extends RefCounted
## Experiência de UM jogador em cada `SkillData` (coleta e maestrias). Só o host altera
## (`add_xp`); na rede, o dono recebe o valor oficial (`replicate_xp`). Mesmo padrão do Inventory.

signal changed(skill_id: StringName, xp: int)

var _xp: Dictionary[StringName, int] = {}


func xp(skill_id: StringName) -> int:
	return _xp.get(skill_id, 0)


## Tipos com alguma experiência (save do mundo).
func all_xp() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_xp.keys())
	return ids


func level(skill: SkillData) -> int:
	return skill.level_for_xp(xp(skill.id))


func add_xp(skill_id: StringName, amount: int) -> void:
	_xp[skill_id] = xp(skill_id) + amount
	changed.emit(skill_id, _xp[skill_id])


## Cliente (valor oficial do host) e host ao carregar o save (CharacterRecord).
func replicate_xp(skill_id: StringName, value: int) -> void:
	_xp[skill_id] = value
	changed.emit(skill_id, value)
