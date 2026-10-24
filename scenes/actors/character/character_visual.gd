class_name CharacterVisual
extends Node2D
## Apresentação do personagem do jogador: quadro frente/costas, espelhamento, balanço ao
## andar, o rastro do golpe de espada, o puxar e soltar do arco e a montaria (desenho embaixo,
## cavaleiro mais alto, poeira ao subir e descer). Só LÊ o estado do Character pai.

const FRAME_FRONT := 0
const FRAME_BACK := 1
const BOB_STEPS_PER_SECOND := 8.0
const MOVING_SPEED := 5.0
## Varredura do rastro do golpe (radianos para cada lado) e duração (s).
const SLASH_SWEEP := 0.45
const SLASH_TIME := 0.16
## Arma à distância: na preparação o corpo recua (px, contra a mira; puxar a corda) e volta no
## disparo, com um sopro de faíscas na boca da arma (distância à frente, px de tela).
const DRAW_BACK := 1.0
const RELEASE_AHEAD := 7.0
const RELEASE_PARTICLES := 4
const RELEASE_SPEED := 30.0
const RELEASE_LIFETIME := 0.15
## Poeira ao subir na montaria e ao descer dela.
const DUST_COLOR := Color(0.78, 0.7, 0.55)
const DUST_PARTICLES := 10
const DUST_SPEED := 45.0
const DUST_LIFETIME := 0.35

var _walk_time := 0.0
var _slash_tween: Tween
var _draw_back := Vector2.ZERO
var _mount := Sprite2D.new()
var _was_mounted := false

@onready var _character: Character = get_parent()
@onready var _body: Sprite2D = $Body
@onready var _slash: Sprite2D = $SlashPivot/Slash


func _ready() -> void:
	_slash.modulate.a = 0.0
	_mount.centered = false
	_mount.visible = false
	add_child(_mount)
	move_child(_mount, 0)  # embaixo do corpo
	if _character.attacker:
		_character.attacker.attack_started.connect(_on_attack_started)
		_character.attacker.attack_struck.connect(_on_attack_struck)
		_character.attacker.attack_finished.connect(func() -> void: _draw_back = Vector2.ZERO)


## Cor de identificação (ex.: outros jogadores no coop). Fica no sprite, não no Visual,
## para não brigar com o flash e o piscar do ActorFeedback.
func set_tint(color: Color) -> void:
	_body.self_modulate = color


func _process(delta: float) -> void:
	var facing := _character.facing
	_body.frame = FRAME_BACK if facing.y < -0.1 else FRAME_FRONT
	if absf(facing.x) > 0.1:
		_body.flip_h = facing.x < 0.0

	var moving := _character.ground_velocity.length() > MOVING_SPEED
	_walk_time = _walk_time + delta if moving else 0.0
	var step_up := moving and fmod(_walk_time * BOB_STEPS_PER_SECOND, 2.0) < 1.0
	var bob := Vector2(0, -1.0 if step_up else 0.0)
	_body.position = _draw_back + bob
	_show_mount(bob)


## O rastro gira no plano do chão: o pai (SlashPivot) achata Y pela metade, então o
## arco aparece em perspectiva isométrica.
func _on_attack_struck(direction: Vector2, attack: AttackData) -> void:
	if attack.projectile:
		_release(direction, attack.projectile)
		return
	var angle := direction.angle()
	if _slash_tween:
		_slash_tween.kill()
	_slash.rotation = angle - SLASH_SWEEP
	_slash.modulate.a = 1.0
	_slash_tween = create_tween().set_parallel()
	_slash_tween.tween_property(_slash, "rotation", angle + SLASH_SWEEP, SLASH_TIME)
	_slash_tween.tween_property(_slash, "modulate:a", 0.0, SLASH_TIME).set_ease(Tween.EASE_IN)


func _on_attack_started(direction: Vector2, attack: AttackData) -> void:
	if attack.projectile:
		_draw_back = -_screen_direction(direction).sign() * DRAW_BACK


## Solta a flecha: o corpo volta e sai um sopro da cor do rastro na boca da arma.
func _release(direction: Vector2, projectile: ProjectileData) -> void:
	_draw_back = Vector2.ZERO
	var at := _character.position + Vector2(0, -Projectile.HEIGHT) \
		+ _screen_direction(direction) * RELEASE_AHEAD
	SparkBurst.spawn(_character.get_parent(), at, projectile.glow_color, RELEASE_PARTICLES,
		RELEASE_SPEED, RELEASE_LIFETIME)


## Direção na tela (unitária) de uma direção no plano do chão.
func _screen_direction(direction: Vector2) -> Vector2:
	return Iso.ground_to_screen(direction).normalized()


## Montado: o desenho da montaria embaixo (balança junto) e o cavaleiro sentado nas costas dela.
func _show_mount(bob: Vector2) -> void:
	var mounted := _character.rider != null and _character.rider.is_mounted()
	if mounted != _was_mounted:
		_was_mounted = mounted
		SparkBurst.spawn(_character.get_parent(), _character.position, DUST_COLOR, DUST_PARTICLES,
			DUST_SPEED, DUST_LIFETIME)
	_mount.visible = mounted
	if not mounted:
		return
	var mount := _character.mount
	_mount.texture = mount.texture
	_mount.position = mount.texture_offset + bob
	_mount.flip_h = _body.flip_h
	_body.position.y -= mount.rider_height
