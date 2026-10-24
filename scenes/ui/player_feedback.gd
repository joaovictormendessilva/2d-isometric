class_name PlayerFeedback
extends Node
## Avisos flutuantes do jogador LOCAL: itens e moedas ganhos ("+1 Madeira"), receita aprendida,
## nível de coleta subindo, pedra de portal ativada, por que não dá para coletar ("Precisa de ferramenta nível 2") ou beber
## uma poção ("Vida cheia"), efeitos ganhos ("Veneno", "Rapidez") e aparências colecionadas.
## Avisos que chegam juntos (ex.: minério e pedra da mesma coleta) saem um de cada vez, sem se
## sobrepor. Só apresentação.

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
	ConsumableRules.Check.ALREADY_KNOWN: &"USE_ALREADY_KNOWN",
}
const CAST_REFUSALS := {
	AbilityRules.Check.EMPTY_SLOT: &"CAST_EMPTY_SLOT",
	AbilityRules.Check.COOLING_DOWN: &"CAST_COOLING_DOWN",
}

var _character: Character
var _items: ItemDatabase
var _skills: DataCatalog
var _numbers: DamageNumbers
var _levels: Dictionary[StringName, int] = {}
## Efeitos já anunciados: renovar um efeito ativo não repete o aviso.
var _known_effects: Dictionary[StringName, bool] = {}
## Desligado até o estado do jogador chegar (`start_announcing`): até lá, os acompanhamentos só
## anotam o que ele já tem (habilidades, níveis, efeitos), sem avisar.
var _announcing := false
var _queue: Array[Array] = []  # [texto, cor]
var _wait := 0.0
var _last_refusal := ""
var _last_refusal_time := -INF


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
	for skill: SkillData in skills.entries():
		_levels[skill.id] = progress.level(skill)
	progress.changed.connect(_on_xp_changed.bind(progress).unbind(1))


## Uma vez: habilidade nova aprendida vira aviso (com a tecla, se já foi para um espaço).
func watch_abilities(book: AbilityBook) -> void:
	var known: Dictionary[StringName, bool] = {}
	for ability in book.learned():
		known[ability.id] = true
	book.changed.connect(func() -> void:
		for ability in book.learned():
			if not known.has(ability.id):
				known[ability.id] = true
				_show(Texts.format(&"FEEDBACK_ABILITY_LEARNED", [ability.get_display_name()]),
					LEVEL_COLOR))


## Uma vez: aparência nova colecionada vira aviso (transmog, ADR-030).
func watch_appearances(collection: AppearanceCollection, items: ItemDatabase) -> void:
	collection.collected.connect(func(item_id: StringName) -> void:
		_show(Texts.format(&"FEEDBACK_LOOK_COLLECTED", [items.get_item(item_id).get_display_name()]),
			LEVEL_COLOR))


## Uma vez: pedra de portal ativada agora vira aviso (as do save ou do host, não).
func watch_waystones(known: WaystoneLog, atlas: WaystoneAtlas) -> void:
	known.activated.connect(func(waystone_id: StringName, is_new: bool) -> void:
		if is_new:
			_show(Texts.format(&"FEEDBACK_WAYSTONE_ACTIVATED",
				[atlas.get_stone(waystone_id).get_display_name()]), LEVEL_COLOR))


## Sem outra pedra ativada para viajar: diz o que falta.
func show_no_destination() -> void:
	_show_refusal(Texts.get_text(&"WAYSTONE_NO_DESTINATION"))


## Uma vez: efeitos novos no jogador viram aviso (debuff em vermelho, buff em verde).
func watch_effects(effects: ActiveEffects) -> void:
	effects.changed.connect(_on_effects_changed.bind(effects))


func _on_effects_changed(effects: ActiveEffects) -> void:
	var current: Dictionary[StringName, bool] = {}
	for entry in effects.entries():
		current[entry.data.id] = true
		if not _known_effects.has(entry.data.id):
			_show(entry.data.get_display_name(),
				UiStyle.DANGER if entry.data.harmful else LEVEL_COLOR)
	_known_effects = current


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
	var skill := _skills.get_entry(skill_id) as SkillData
	if skill == null:
		return
	var level := progress.level(skill)
	if level > _levels.get(skill_id, 1):
		var mastery := skill as MasteryData
		if mastery:  # maestria: diz o ganho, senão o nível novo não se percebe
			_show(Texts.format(&"FEEDBACK_MASTERY_LEVEL_UP", [skill.get_display_name(), level,
				mastery.damage_bonus_percent(level)]), LEVEL_COLOR)
		else:
			_show(Texts.format(&"FEEDBACK_LEVEL_UP", [skill.get_display_name(), level]),
				LEVEL_COLOR)
	_levels[skill_id] = level


## Usar um item foi recusado antes de pedir ao host (vida cheia, poção esperando, sem poções).
func show_use_refusal(reason: ConsumableRules.Check) -> void:
	var key: StringName = USE_REFUSALS.get(reason, &"")
	if not key.is_empty():
		_show_refusal(Texts.get_text(key))


## Recusa ao lançar → aviso (ocupado atacando ou atordoado: sem aviso, é o normal do combate).
func show_cast_refusal(reason: AbilityRules.Check) -> void:
	var key: StringName = CAST_REFUSALS.get(reason, &"")
	if not key.is_empty():
		_show_refusal(Texts.get_text(key))


func _on_gather_refused(node: ResourceNode, reason: GatheringRules.Check) -> void:
	_show_refusal(GatheringTexts.refusal(node.data, reason))


## O estado do jogador local chegou (save no host, estado completo vindo do host no cliente): daqui
## em diante, o que mudar é novidade.
func start_announcing() -> void:
	_announcing = true


func _show(text: String, color: Color) -> void:
	if not _announcing:
		return
	if _queue.size() >= MAX_QUEUED:
		_queue.pop_front()  # avisos velhos perdem a vez
	_queue.append([text, color])


## Recusas ("Habilidade recarregando"...): apertar de novo não empilha o mesmo aviso enquanto ele
## está na fila ou ainda na tela.
func _show_refusal(text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _queue.any(func(message: Array) -> bool: return message[0] == text) \
			or (text == _last_refusal and now - _last_refusal_time < MESSAGE_TIME):
		return
	_last_refusal = text
	_last_refusal_time = now
	_show(text, REFUSED_COLOR)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or _queue.is_empty():
		return
	var message: Array = _queue.pop_front()
	_numbers.show_text(_character.position, message[0], message[1], MESSAGE_TIME)
	_wait = MESSAGE_INTERVAL
