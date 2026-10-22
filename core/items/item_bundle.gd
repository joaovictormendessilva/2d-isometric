class_name ItemBundle
extends Resource
## Um conjunto fixo de itens: id do item → quantidade (ex.: o kit de testes).

@export var items: Dictionary[StringName, int] = {}


## Guarda tudo no inventário (o que não couber fica de fora).
func give_to(inventory: Inventory) -> void:
	for item_id in items:
		inventory.add(item_id, items[item_id])
