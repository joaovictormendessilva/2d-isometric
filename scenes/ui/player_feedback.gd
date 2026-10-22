class_name PlayerFeedback
extends Node
## Avisos flutuantes do jogador LOCAL: itens ganhos ("+1 Madeira"), nível de coleta subindo e
## por que não dá para coletar ("Precisa de ferramenta nível 2"). Só apresentação.

const GAIN_COLOR := Color("e8e0b0")
const LEVEL_COLOR := Color("8fe388")
const REFUSED_COLOR := Color("ff9f6b")
const MESSAGE_TIME := 1.2

var _character: Character
var _items: ItemDatabase
var _skills: DataCatalog
var _numbers: DamageNumbers
var _levels: Dictionary[StringName, int] = {}


func setup(character: Character, inventory: Inventory, progress: SkillProgress,
		items: ItemDatabase, skills: DataCatalog, numbers: DamageNumbers) -> void:
	_character = character
	_items = items
	_skills = skills
	_numbers = numbers
	inventory.added.connect(_on_item_added)
	for skill: GatheringSkillData in skills.entries():
		_levels[skill.id] = progress.level(skill)
	progress.changed.connect(_on_xp_changed.bind(progress).unbind(1))
	if character.gatherer:
		character.gatherer.refused.connect(_on_gather_refused)


func _on_item_added(item_id: StringName, amount: int) -> void:
	var item := _items.get_item(item_id)
	_show("+%d %s" % [amount, item.display_name if item else String(item_id)], GAIN_COLOR)


func _on_xp_changed(skill_id: StringName, progress: SkillProgress) -> void:
	var skill := _skills.get_entry(skill_id) as GatheringSkillData
	if skill == null:
		return
	var level := progress.level(skill)
	if level > _levels.get(skill_id, 1):
		_show("%s nível %d!" % [skill.display_name, level], LEVEL_COLOR)
	_levels[skill_id] = level


func _on_gather_refused(node: ResourceNode, reason: GatheringRules.Check) -> void:
	var data := node.data
	match reason:
		GatheringRules.Check.NEEDS_TOOL:
			_show("Precisa de ferramenta nível %d" % data.min_tool_tier, REFUSED_COLOR)
		GatheringRules.Check.NEEDS_LEVEL:
			_show("Precisa de %s nível %d" % [data.skill.display_name, data.min_skill_level],
				REFUSED_COLOR)


func _show(text: String, color: Color) -> void:
	_numbers.show_text(_character.position, text, color, MESSAGE_TIME)
