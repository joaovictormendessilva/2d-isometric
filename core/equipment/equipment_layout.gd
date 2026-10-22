class_name EquipmentLayout
extends Resource
## Quais espaços de equipamento o personagem tem, na ordem da tela (ADR-018). Em dados para
## poder abrir espaços (ex.: mais acessórios) sem mexer no código.

const DEFAULT_PATH := "res://data/balance/equipment_layout.tres"

@export var slots: Array[EquipmentData.Slot] = []


static func load_default() -> EquipmentLayout:
	return load(DEFAULT_PATH)
