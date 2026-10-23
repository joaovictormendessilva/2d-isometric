class_name Hud
extends Control
## HUD do jogador local: buffs e debuffs (EffectBar), barra de vida, poções (PotionSlot), níveis
## de coleta e a tecla do
## inventário. Só lê estado
## via sinais (os itens ficam na tela de inventário).

const BAR_FULL_COLOR := UiStyle.HEALTH

var _skills: DataCatalog

@onready var _bar: ColorRect = $HealthRow/HealthBar
@onready var _bar_fill: ColorRect = $HealthRow/HealthBar/Fill
@onready var _health_label: Label = $HealthRow/Value
@onready var _skills_label: Label = $Skills
@onready var _inventory_hint: Label = $InventoryHint


## Uma vez: o que é do jogador (níveis de coleta, poções, tecla do inventário).
func setup(progress: SkillProgress, skills: DataCatalog, inventory: Inventory,
		items: ItemDatabase, cooldowns: Cooldowns, effects: ActiveEffects) -> void:
	_skills = skills
	var effect_bar := EffectBar.new()
	add_child(effect_bar)
	move_child(effect_bar, 0)  # acima da vida
	effect_bar.setup(effects)
	var potions := PotionSlot.new()
	$HealthRow.add_child(potions)
	potions.setup(inventory, items, cooldowns)
	_bar_fill.color = BAR_FULL_COLOR
	progress.changed.connect(_on_skills_changed.bind(progress).unbind(2))
	_on_skills_changed(progress)
	_inventory_hint.text = Texts.format(&"HUD_INVENTORY_KEY", [Texts.action_key(&"inventory")])


## A cada personagem (ele é recriado numa viagem): a vida dele. A ligação com o anterior some
## junto com ele.
func set_character(character: Character) -> void:
	character.health.changed.connect(_on_health_changed)
	_on_health_changed(character.health.current, character.health.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	_bar_fill.size.x = _bar.custom_minimum_size.x * current / maxf(maximum, 1)
	_health_label.text = Texts.format(&"HUD_HEALTH", [current, maximum])


## "Lenhador 2 (35%)  Minerador 1 (0%)": nível e quanto falta para o próximo.
func _on_skills_changed(progress: SkillProgress) -> void:
	var parts := PackedStringArray()
	for skill: GatheringSkillData in _skills.entries():
		var level := progress.level(skill)
		var into_level := progress.xp(skill.id) - skill.xp_for_level(level)
		var percent := 100 * into_level / maxi(skill.xp_to_next(level), 1)
		parts.append(Texts.format(&"HUD_SKILL_LEVEL", [skill.get_display_name(), level, percent]))
	_skills_label.text = "  ".join(parts)
