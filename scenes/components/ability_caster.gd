class_name AbilityCaster
extends Node
## Lança habilidades do Character pai (ADR-026): preparação (`cast_time`, andando mais devagar) →
## solta o projétil (na direção da mira) ou a área (no ponto mirado, até o alcance) na região.
## Apanhar não interrompe; morrer, sim. Em todo computador o lançamento roda igual
## (apresentação); só o projétil ou a área do host causam dano (ver Projectile e AreaBlast).
## Quem pode lançar o quê (livro, recarga) é decidido antes, por AbilitySync.
## A mira (`aim`) é o caminho até o ponto mirado no plano do chão: direção e distância.

signal cast_started(ability: AbilityData, aim: Vector2)
signal cast_released(ability: AbilityData, aim: Vector2)

var _ability: AbilityData
var _aim := Vector2.DOWN
var _time_left := 0.0

@onready var _body: Character = get_parent()


func is_casting() -> bool:
	return _ability != null


func move_multiplier() -> float:
	return _ability.cast_move_multiplier if is_casting() else 1.0


## `aim` no plano do chão. Retorna se começou.
func try_cast(ability: AbilityData, aim: Vector2) -> bool:
	if ability == null or is_casting() or aim.is_zero_approx():
		return false
	_ability = ability
	_aim = aim
	_time_left = ability.cast_time
	cast_started.emit(ability, _aim)
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
	match ability.shape:
		AbilityData.Shape.AREA:
			var blast := AreaBlast.new()
			blast.setup(ability, _body,
				_body.position + Iso.ground_to_screen(ability.area_offset(_aim)))
			region.ground_effects.add_child(blast)
		_:
			Projectile.launch(ability.projectile, _body, _aim, ability.damage, ability.knockback,
				ability.hit_effects)
	cast_released.emit(ability, _aim)
