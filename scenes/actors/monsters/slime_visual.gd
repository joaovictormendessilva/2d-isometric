extends Node2D
## Apresentação do slime: respira (achata e estica), se encolhe na preparação do bote e
## estica no bote. Com salto (SlamAttacker, Rei Slime): se encolhe cada vez mais durante o
## aviso, estica no ar subindo e descendo (a sombra fica no chão) e se esborracha ao cair.
## Só LÊ o estado do Character pai.

const BREATH_HZ := 2.5
const BREATH_AMOUNT := 0.06
const WINDUP_SQUASH := Vector2(1.3, 0.7)
const STRIKE_STRETCH := Vector2(0.8, 1.25)
const STRIKE_TIME := 0.18
const LAND_SQUASH := Vector2(1.35, 0.7)
const LAND_TIME := 0.15
const POSE_SMOOTHING := 12.0

var _time := 0.0
var _pose := Vector2.ONE
var _strike_left := 0.0
var _land_left := 0.0

@onready var _character: Character = get_parent()
@onready var _body: Sprite2D = $Body


func _ready() -> void:
	_character.attacker.attack_struck.connect(func(_d: Vector2, _a: AttackData) -> void:
		_strike_left = STRIKE_TIME)
	if _character.slammer:
		_character.slammer.slam_landed.connect(func(_l: Vector2, _a: SlamAttackData) -> void:
			_land_left = LAND_TIME)


func _process(delta: float) -> void:
	_time += delta
	_strike_left = maxf(_strike_left - delta, 0.0)
	_land_left = maxf(_land_left - delta, 0.0)
	_pose = _pose.lerp(_target_pose(), minf(delta * POSE_SMOOTHING, 1.0))
	_body.scale = _pose
	var slammer := _character.slammer
	_body.position.y = -roundf(slammer.height()) if slammer else 0.0
	if absf(_character.facing.x) > 0.1:
		_body.flip_h = _character.facing.x < 0.0


func _target_pose() -> Vector2:
	var slammer := _character.slammer
	if _land_left > 0.0:
		return LAND_SQUASH
	if slammer and slammer.is_airborne():
		return STRIKE_STRETCH
	if slammer and slammer.is_slamming() and slammer.windup_progress() > 0.0:
		return Vector2.ONE.lerp(WINDUP_SQUASH, slammer.windup_progress())
	if _strike_left > 0.0:
		return STRIKE_STRETCH
	if _character.attacker.is_attacking():
		return WINDUP_SQUASH
	var breath := sin(_time * TAU * BREATH_HZ) * BREATH_AMOUNT
	return Vector2(1.0 + breath, 1.0 - breath)
