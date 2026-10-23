class_name ActorFeedback
extends Node
## Retorno visual genérico de qualquer ator (só apresentação): flash ao ser atingido, brilho
## verde ao curar, piscar durante invulnerabilidade, tom avermelhado na preparação de ataques lentos
## (telegrafia: o jogador vê o ataque vindo), transparência enquanto imune e desaparecer
## ao morrer.

const FLASH_COLOR := Color(2.5, 2.5, 2.5)
const TELEGRAPH_COLOR := Color(1.9, 0.5, 0.5)
## Ataques com preparação menor que isto não são telegrafados (ex.: a espada).
const TELEGRAPH_MIN_WINDUP := 0.2
const FLASH_TIME := 0.12
## Brilho verde ao curar (poção): mais longo que o flash de dano, para ler como "bom".
const HEAL_COLOR := Color(0.8, 1.7, 0.8)
const HEAL_GLOW_TIME := 0.35
const DEATH_FADE_TIME := 0.5
const BLINK_HZ := 12.0
## Semitransparente enquanto imune (ex.: criatura voltando para casa): golpes não pegam.
const IMMUNE_MODULATE := Color(1, 1, 1, 0.5)
const IMMUNE_FADE_TIME := 0.2

@export var visual: CanvasItem

var _tween: Tween

@onready var _body: Character = get_parent()


func _ready() -> void:
	if _body.health:
		_body.health.damaged.connect(_on_damaged.unbind(1))
		_body.health.healed.connect(_on_healed.unbind(1))
		_body.health.immunity_changed.connect(_on_immunity_changed)
	if _body.attacker:
		_body.attacker.attack_started.connect(_on_attack_started)
		_body.attacker.attack_struck.connect(_on_attack_struck.unbind(2))
	if _body.slammer:  # salto: avermelha durante o aviso, volta ao saltar
		_body.slammer.slam_started.connect(func(_l: Vector2, attack: SlamAttackData) -> void:
			_tween_modulate(Color.WHITE, TELEGRAPH_COLOR, attack.windup))
		_body.slammer.slam_launched.connect(_on_attack_struck)
	_body.died.connect(_on_died.unbind(1))
	_body.revived.connect(_on_revived.unbind(1))


func _process(_delta: float) -> void:
	var blinking := _body.is_alive() and _body.health != null and _body.health.is_invulnerable()
	visual.visible = not blinking or fmod(Time.get_ticks_msec() / 1000.0 * BLINK_HZ, 2.0) < 1.0


func _on_damaged() -> void:
	_tween_modulate(FLASH_COLOR, Color.WHITE, FLASH_TIME)


func _on_healed() -> void:
	_tween_modulate(HEAL_COLOR, Color.WHITE, HEAL_GLOW_TIME)


func _on_immunity_changed(immune: bool) -> void:
	_tween_modulate(visual.modulate, IMMUNE_MODULATE if immune else Color.WHITE, IMMUNE_FADE_TIME)


func _on_attack_started(_direction: Vector2, attack: MeleeAttackData) -> void:
	if attack.windup >= TELEGRAPH_MIN_WINDUP:
		_tween_modulate(Color.WHITE, TELEGRAPH_COLOR, attack.windup)


func _on_attack_struck() -> void:
	if visual.modulate != Color.WHITE:
		_tween_modulate(visual.modulate, Color.WHITE, FLASH_TIME)


func _on_died() -> void:
	_tween_modulate(Color.WHITE, Color(1, 1, 1, 0), DEATH_FADE_TIME)


func _on_revived() -> void:
	_tween_modulate(Color.WHITE, Color.WHITE, 0.0)


func _tween_modulate(from: Color, to: Color, duration: float) -> void:
	if _tween:
		_tween.kill()
	visual.modulate = from
	_tween = create_tween()
	_tween.tween_property(visual, "modulate", to, duration)
