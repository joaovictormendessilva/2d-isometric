class_name Character
extends CharacterBody2D
## Corpo simulado de um ator controlado por um jogador. A origem do nó fica nos PÉS
## (usada pelo Y-sort). Recebe apenas INTENÇÕES de movimento; quem aplica a física é a
## autoridade (single-player: este mesmo processo). Não lê teclado — ver LocalPlayerInput.

@export var stats: ActorStats

var entity_id := 0
var player_id := 0
## Velocidade atual no plano do chão (ver `Iso`).
var ground_velocity := Vector2.ZERO
## Última direção de movimento pedida, no plano do chão. Usada pela apresentação.
var facing := Vector2.DOWN

var _move_intent := Vector2.ZERO


## `direction` no plano do chão; comprimento até 1 (controle analógico pode ser menor).
func set_move_intent(direction: Vector2) -> void:
	_move_intent = direction.limit_length(1.0)


func _physics_process(delta: float) -> void:
	var target := _move_intent * stats.move_speed \
		* Iso.move_speed_factor(_move_intent, stats.horizontal_speed_factor)
	var rate := stats.acceleration if _move_intent != Vector2.ZERO else stats.friction
	ground_velocity = ground_velocity.move_toward(target, rate * delta)
	velocity = Iso.ground_to_screen(ground_velocity)
	move_and_slide()
	# Depois de deslizar numa colisão, a velocidade real pode ter mudado.
	ground_velocity = Iso.screen_to_ground(velocity)
	if _move_intent != Vector2.ZERO:
		facing = _move_intent.normalized()
