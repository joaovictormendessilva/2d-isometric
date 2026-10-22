class_name OffHandData
extends EquipmentData
## Item da mão secundária: escudo, tomo ou aljava. Só combina com armas que o aceitam
## (`WeaponData.off_hand_kinds`); de mãos vazias, qualquer um serve.

enum Kind { SHIELD, TOME, QUIVER }

@export var kind: Kind = Kind.SHIELD


func get_slot() -> EquipmentData.Slot:
	return Slot.OFF_HAND
