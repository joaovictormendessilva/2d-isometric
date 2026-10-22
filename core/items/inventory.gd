class_name Inventory
extends RefCounted
## Inventário de UM jogador: quantidade por id de item. Só o host altera (`add`); na rede, o
## dono recebe a contagem oficial (`replicate_count`).

signal changed(item_id: StringName, count: int)

var _counts: Dictionary[StringName, int] = {}


func add(item_id: StringName, amount: int) -> void:
	_counts[item_id] = count(item_id) + amount
	changed.emit(item_id, _counts[item_id])


func replicate_count(item_id: StringName, value: int) -> void:
	_counts[item_id] = value
	changed.emit(item_id, value)


func count(item_id: StringName) -> int:
	return _counts.get(item_id, 0)


func get_counts() -> Dictionary[StringName, int]:
	return _counts.duplicate()
