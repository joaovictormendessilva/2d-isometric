extends Node2D
## Apresentação do slime: respira (achata e estica), se encolhe na preparação do bote e
## estica no bote. Só LÊ o estado do Character pai.

const BREATH_HZ := 2.5
const BREATH_AMOUNT := 0.06
const WINDUP_SQUASH := Vector2(1.3, 0.7)
const STRIKE_STRETCH := Vector2(0.8, 1.25)
const STRIKE_TIME := 0.18
const POSE_SMOOTHING := 12.0

var _time := 0.0
var _pose := Vector2.ONE
var _strike_left := 0.0

@onready var _character: Character = get_parent()
@onready var _body: Sprite2D = $Body


func _ready() -> void:
	_character.attacker.attack_struck.connect(func(_d: Vector2, _a: MeleeAttackData) -> void:
		_strike_left = STRIKE_TIME)


func _process(delta: float) -> void:
	_time += delta
	_strike_left = maxf(_strike_left - delta, 0.0)
	var breath := sin(_time * TAU * BREATH_HZ) * BREATH_AMOUNT
	var target := Vector2(1.0 + breath, 1.0 - breath)
	if _strike_left > 0.0:
		target = STRIKE_STRETCH
	elif _character.attacker.is_attacking():
		target = WINDUP_SQUASH
	_pose = _pose.lerp(target, minf(delta * POSE_SMOOTHING, 1.0))
	_body.scale = _pose
	if absf(_character.facing.x) > 0.1:
		_body.flip_h = _character.facing.x < 0.0
