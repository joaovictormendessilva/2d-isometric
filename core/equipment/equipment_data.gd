class_name EquipmentData
extends ItemData
## Item que se veste num espaço de equipamento (armadura, mochila, acessório...). Armas e itens
## da mão secundária têm classes próprias (WeaponData, OffHandData). Um arquivo por item em
## `data/items/` (ADR-018).

## Tipos de espaço. Quantos de cada o personagem tem: `EquipmentLayout` (dados).
enum Slot { MAIN_HAND, OFF_HAND, HEAD, CHEST, LEGS, BACKPACK, ACCESSORY }

## Espaço deste item (armas e itens secundários definem o próprio; ver `get_slot`).
@export var slot: Slot = Slot.ACCESSORY
@export var bonuses: StatBonuses


func _init() -> void:
	max_stack = 1


func get_slot() -> Slot:
	return slot
