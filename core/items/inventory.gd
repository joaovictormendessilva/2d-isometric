class_name Inventory
extends RefCounted
## Inventário de UM jogador: quantidade por id de item. Só a autoridade altera.

signal changed(item_id: StringName, count: int)

var _counts: Dictionary[StringName, int] = {}


func add(item_id: StringName, amount: int) -> void:
	_counts[item_id] = count(item_id) + amount
	changed.emit(item_id, _counts[item_id])


func count(item_id: StringName) -> int:
	return _counts.get(item_id, 0)


func get_counts() -> Dictionary[StringName, int]:
	return _counts.duplicate()
