class_name Hud
extends Control
## HUD do jogador local: barra de vida e itens coletados. Só lê estado via sinais.

const BAR_FULL_COLOR := Color("d94a4a")

var _items: ItemDatabase

@onready var _bar_fill: ColorRect = $HealthBar/Fill
@onready var _health_label: Label = $HealthBar/Value
@onready var _inventory_label: Label = $Inventory


func setup(character: Character, inventory: Inventory, items: ItemDatabase) -> void:
	_items = items
	_bar_fill.color = BAR_FULL_COLOR
	character.health.changed.connect(_on_health_changed)
	_on_health_changed(character.health.current, character.health.max_health)
	inventory.changed.connect(_on_inventory_changed.bind(inventory).unbind(2))
	_on_inventory_changed(inventory)


func _on_health_changed(current: int, maximum: int) -> void:
	_bar_fill.size.x = ($HealthBar as Control).size.x * current / maxf(maximum, 1)
	_health_label.text = "%d / %d" % [current, maximum]


func _on_inventory_changed(inventory: Inventory) -> void:
	var parts := PackedStringArray()
	var counts := inventory.get_counts()
	for id in counts:
		var item := _items.get_item(id)
		parts.append("%s x%d" % [item.display_name if item else String(id), counts[id]])
	_inventory_label.text = "  ".join(parts)
