class_name Hud
extends Control
## HUD do jogador local: buffs e debuffs (EffectBar), barra de vida, poções (PotionSlot), a tecla
## do inventário, as maestrias em uso e os níveis de coleta. Só lê estado via sinais (os itens
## ficam na tela de inventário).

const BAR_FULL_COLOR := UiStyle.HEALTH

var _skills: DataCatalog
var _progress: SkillProgress
var _equipment: Equipment
var _abilities: AbilityBook

@onready var _bar: ColorRect = $HealthRow/HealthBar
@onready var _bar_fill: ColorRect = $HealthRow/HealthBar/Fill
@onready var _health_label: Label = $HealthRow/Value
@onready var _masteries_label: Label = $Masteries
@onready var _skills_label: Label = $Skills
@onready var _inventory_hint: Label = $InventoryHint


## Uma vez: o que é do jogador (níveis, poções, tecla do inventário). As maestrias mostradas são as
## do que está em uso: a arma vestida e as habilidades nas teclas.
func setup(progress: SkillProgress, skills: DataCatalog, inventory: Inventory,
		items: ItemDatabase, cooldowns: Cooldowns, effects: ActiveEffects, equipment: Equipment,
		abilities: AbilityBook) -> void:
	_skills = skills
	_progress = progress
	_equipment = equipment
	_abilities = abilities
	var effect_bar := EffectBar.new()
	add_child(effect_bar)
	move_child(effect_bar, 0)  # acima da vida
	effect_bar.setup(effects)
	var potions := PotionSlot.new()
	$HealthRow.add_child(potions)
	potions.setup(inventory, items, cooldowns)
	_bar_fill.color = BAR_FULL_COLOR
	progress.changed.connect(_on_skills_changed.unbind(2))
	equipment.slot_changed.connect(_on_skills_changed.unbind(1))
	abilities.changed.connect(_on_skills_changed)
	_on_skills_changed()
	_inventory_hint.text = Texts.format(&"HUD_INVENTORY_KEY", [Texts.action_key(&"inventory")])


## A cada personagem (ele é recriado numa viagem): a vida dele. A ligação com o anterior some
## junto com ele.
func set_character(character: Character) -> void:
	character.health.changed.connect(_on_health_changed)
	_on_health_changed(character.health.current, character.health.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	_bar_fill.size.x = _bar.custom_minimum_size.x * current / maxf(maximum, 1)
	_health_label.text = Texts.format(&"HUD_HEALTH", [current, maximum])


## Maestrias em uso, sem repetir (duas magias arcanas = uma linha "Arcano").
func masteries_in_use() -> Array[MasteryData]:
	var used: Array[MasteryData] = []
	var weapon := _equipment.weapon()
	var sources: Array[MasteryData] = [weapon.attack.mastery if weapon and weapon.attack else null]
	for index in AbilityBook.SLOTS:
		var ability := _abilities.in_slot(index)
		sources.append(ability.mastery if ability else null)
	for mastery in sources:
		if mastery and mastery not in used:
			used.append(mastery)
	return used


## "Espada 3 (40%)  Arcano 1 (5%)" e "Lenhador 2 (35%)  Minerador 1 (0%)": nível e quanto falta
## para o próximo.
func _on_skills_changed() -> void:
	var masteries := PackedStringArray()
	for mastery in masteries_in_use():
		masteries.append(_level_text(mastery))
	_masteries_label.text = "  ".join(masteries)
	_masteries_label.visible = not masteries.is_empty()
	var gathering := PackedStringArray()
	for skill: SkillData in _skills.entries():
		if skill is GatheringSkillData:
			gathering.append(_level_text(skill))
	_skills_label.text = "  ".join(gathering)


func _level_text(skill: SkillData) -> String:
	var level := _progress.level(skill)
	var into_level := _progress.xp(skill.id) - skill.xp_for_level(level)
	var percent := 100 * into_level / maxi(skill.xp_to_next(level), 1)
	return Texts.format(&"HUD_SKILL_LEVEL", [skill.get_display_name(), level, percent])
