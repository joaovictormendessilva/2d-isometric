class_name PlayerFeedback
extends Node
## Avisos flutuantes do jogador LOCAL: itens e moedas ganhos ("+1 Madeira"), receita aprendida,
## nível de coleta subindo, por que não dá para coletar ("Precisa de ferramenta nível 2") ou beber
## uma poção ("Vida cheia"). Avisos que chegam juntos (ex.: minério e pedra da mesma coleta) saem
## um de cada vez, sem se sobrepor. Só apresentação.

const GAIN_COLOR := UiStyle.TEXT_SOFT
const LEVEL_COLOR := UiStyle.POSITIVE
const REFUSED_COLOR := UiStyle.WARNING
const MESSAGE_TIME := 1.2
## Intervalo entre avisos seguidos.
const MESSAGE_INTERVAL := 0.3
const MAX_QUEUED := 6
## Recusa ao usar um item → texto (morto ou item que não se usa: sem aviso).
const USE_REFUSALS := {
	ConsumableRules.Check.FULL_HEALTH: &"USE_FULL_HEALTH",
	ConsumableRules.Check.COOLING_DOWN: &"USE_COOLING_DOWN",
	ConsumableRules.Check.NO_POTION: &"USE_NO_POTION",
}

var _character: Character
var _items: ItemDatabase
var _skills: DataCatalog
var _numbers: DamageNumbers
var _levels: Dictionary[StringName, int] = {}
var _queue: Array[Array] = []  # [texto, cor]
var _wait := 0.0


## Uma vez: o que é do jogador (itens e moedas ganhos, receitas, experiência).
func setup(inventory: Inventory, wallet: Wallet, book: RecipeBook, recipes: RecipeDatabase,
		progress: SkillProgress, items: ItemDatabase, skills: DataCatalog,
		numbers: DamageNumbers) -> void:
	_items = items
	_skills = skills
	_numbers = numbers
	inventory.added.connect(_on_item_added)
	wallet.earned.connect(func(amount: int) -> void:
		_show(Texts.format(&"FEEDBACK_COINS_GAINED", [amount]), GAIN_COLOR))
	book.learned.connect(func(recipe_id: StringName, is_new: bool) -> void:
		if is_new:
			_show(Texts.format(&"FEEDBACK_RECIPE_LEARNED",
				[recipes.get_recipe(recipe_id).result.get_display_name()]), LEVEL_COLOR))
	for skill: GatheringSkillData in skills.entries():
		_levels[skill.id] = progress.level(skill)
	progress.changed.connect(_on_xp_changed.bind(progress).unbind(1))


## A cada personagem (recriado numa viagem): onde os avisos aparecem e as coletas recusadas.
func set_character(character: Character) -> void:
	_character = character
	if character.gatherer:
		character.gatherer.refused.connect(_on_gather_refused)


func _on_item_added(item_id: StringName, amount: int) -> void:
	var item := _items.get_item(item_id)
	var item_name := item.get_display_name() if item else String(item_id)
	_show(Texts.format(&"FEEDBACK_ITEM_GAINED", [amount, item_name]), GAIN_COLOR)


func _on_xp_changed(skill_id: StringName, progress: SkillProgress) -> void:
	var skill := _skills.get_entry(skill_id) as GatheringSkillData
	if skill == null:
		return
	var level := progress.level(skill)
	if level > _levels.get(skill_id, 1):
		_show(Texts.format(&"FEEDBACK_LEVEL_UP", [skill.get_display_name(), level]), LEVEL_COLOR)
	_levels[skill_id] = level


## Usar um item foi recusado antes de pedir ao host (vida cheia, poção esperando, sem poções).
func show_use_refusal(reason: ConsumableRules.Check) -> void:
	var key: StringName = USE_REFUSALS.get(reason, &"")
	if not key.is_empty():
		_show(Texts.get_text(key), REFUSED_COLOR)


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
