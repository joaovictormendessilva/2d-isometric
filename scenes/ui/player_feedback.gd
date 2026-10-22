class_name PlayerFeedback
extends Node
## Avisos flutuantes do jogador LOCAL: itens ganhos ("+1 Madeira"), nível de coleta subindo e
## por que não dá para coletar ("Precisa de ferramenta nível 2"). Avisos que chegam juntos
## (ex.: minério e pedra da mesma coleta) saem um de cada vez, sem se sobrepor. Só apresentação.

const GAIN_COLOR := Color("e8e0b0")
const LEVEL_COLOR := Color("8fe388")
const REFUSED_COLOR := Color("ff9f6b")
const MESSAGE_TIME := 1.2
## Intervalo entre avisos seguidos.
const MESSAGE_INTERVAL := 0.3
const MAX_QUEUED := 6

var _character: Character
var _items: ItemDatabase
var _skills: DataCatalog
var _numbers: DamageNumbers
var _levels: Dictionary[StringName, int] = {}
var _queue: Array[Array] = []  # [texto, cor]
var _wait := 0.0


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
	_show(GatheringTexts.refusal(node.data, reason), REFUSED_COLOR)


func _show(text: String, color: Color) -> void:
	if _queue.size() >= MAX_QUEUED:
		_queue.pop_front()  # avisos velhos perdem a vez
	_queue.append([text, color])


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or _queue.is_empty():
		return
	var message: Array = _queue.pop_front()
	_numbers.show_text(_character.position, message[0], message[1], MESSAGE_TIME)
	_wait = MESSAGE_INTERVAL
