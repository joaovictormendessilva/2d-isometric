class_name AbilityCaster
extends Node
## Lança habilidades do Character pai (ADR-026): preparação (`cast_time`, andando mais devagar) →
## solta o projétil na região. Apanhar não interrompe; morrer, sim. Em todo computador o
## lançamento roda igual (apresentação); só o projétil do host causa dano (ver Projectile).
## Quem pode lançar o quê (livro, recarga) é decidido antes, por AbilitySync.

signal cast_started(ability: AbilityData, direction: Vector2)
signal cast_released(ability: AbilityData, direction: Vector2)

var _ability: AbilityData
var _direction := Vector2.DOWN
var _time_left := 0.0

@onready var _body: Character = get_parent()


func is_casting() -> bool:
	return _ability != null


func move_multiplier() -> float:
	return _ability.cast_move_multiplier if is_casting() else 1.0


## `direction` no plano do chão. Retorna se começou.
func try_cast(ability: AbilityData, direction: Vector2) -> bool:
	if ability == null or is_casting() or direction.is_zero_approx():
		return false
	_ability = ability
	_direction = direction.normalized()
	_time_left = ability.cast_time
	cast_started.emit(ability, _direction)
	return true


func stop() -> void:
	_ability = null


func _physics_process(delta: float) -> void:
	if not is_casting():
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	var ability := _ability
	_ability = null
	_release(ability)


func _release(ability: AbilityData) -> void:
	var region := Region.of(_body)
	if region == null:
		return
	var projectile := Projectile.new()
	projectile.setup(ability, _body, _direction)
	region.entities.add_child(projectile)
	cast_released.emit(ability, _direction)
