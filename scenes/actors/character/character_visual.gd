extends Node2D
## Apresentação do personagem: escolhe o quadro (frente/costas), espelha para os lados e
## balança 1 px ao andar. Só LÊ o estado do Character pai; não altera regras de jogo.

const FRAME_FRONT := 0
const FRAME_BACK := 1
const BOB_STEPS_PER_SECOND := 8.0
const MOVING_SPEED := 5.0

var _walk_time := 0.0

@onready var _character: Character = get_parent()
@onready var _body: Sprite2D = $Body


func _process(delta: float) -> void:
	var facing := _character.facing
	_body.frame = FRAME_BACK if facing.y < -0.1 else FRAME_FRONT
	if absf(facing.x) > 0.1:
		_body.flip_h = facing.x < 0.0

	var moving := _character.ground_velocity.length() > MOVING_SPEED
	_walk_time = _walk_time + delta if moving else 0.0
	var step_up := moving and fmod(_walk_time * BOB_STEPS_PER_SECOND, 2.0) < 1.0
	_body.position.y = -1.0 if step_up else 0.0
