class_name Hud
extends Control
## HUD do jogador local: barra de vida, itens e níveis de coleta. Só lê estado via sinais.

const BAR_FULL_COLOR := Color("d94a4a")

var _items: ItemDatabase
var _skills: DataCatalog

@onready var _bar: ColorRect = $HealthRow/HealthBar
@onready var _bar_fill: ColorRect = $HealthRow/HealthBar/Fill
@onready var _health_label: Label = $HealthRow/Value
@onready var _inventory_label: Label = $Inventory
@onready var _skills_label: Label = $Skills


func setup(character: Character, inventory: Inventory, items: ItemDatabase,
		progress: SkillProgress, skills: DataCatalog) -> void:
	_items = items
	_skills = skills
	_bar_fill.color = BAR_FULL_COLOR
	character.health.changed.connect(_on_health_changed)
	_on_health_changed(character.health.current, character.health.max_health)
	inventory.changed.connect(_on_inventory_changed.bind(inventory).unbind(2))
	_on_inventory_changed(inventory)
	progress.changed.connect(_on_skills_changed.bind(progress).unbind(2))
	_on_skills_changed(progress)


func _on_health_changed(current: int, maximum: int) -> void:
	_bar_fill.size.x = _bar.custom_minimum_size.x * current / maxf(maximum, 1)
	_health_label.text = Texts.format(&"HUD_HEALTH", [current, maximum])


func _on_inventory_changed(inventory: Inventory) -> void:
	var parts := PackedStringArray()
	var counts := inventory.get_counts()
	for id in counts:
		var item := _items.get_item(id)
		var item_name := item.get_display_name() if item else String(id)
		parts.append(Texts.format(&"HUD_ITEM_COUNT", [item_name, counts[id]]))
	_inventory_label.text = "  ".join(parts)


## "Lenhador 2 (35%)  Minerador 1 (0%)": nível e quanto falta para o próximo.
func _on_skills_changed(progress: SkillProgress) -> void:
	var parts := PackedStringArray()
	for skill: GatheringSkillData in _skills.entries():
		var level := progress.level(skill)
		var into_level := progress.xp(skill.id) - skill.xp_for_level(level)
		var percent := 100 * into_level / maxi(skill.xp_to_next(level), 1)
		parts.append(Texts.format(&"HUD_SKILL_LEVEL", [skill.get_display_name(), level, percent]))
	_skills_label.text = "  ".join(parts)
