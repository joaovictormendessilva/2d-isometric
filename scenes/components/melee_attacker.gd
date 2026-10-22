class_name MeleeAttacker
extends Node
## Executa ataques corpo a corpo do Character pai: preparação (telegrafia) → golpe → recuperação.
## No instante do golpe, procura alvos de outra facção dentro do arco, no plano do chão.
## Só a autoridade aplica o dano; todos os sinais servem para apresentação.

signal attack_started(direction: Vector2, attack: MeleeAttackData)  ## Início da preparação.
signal attack_struck(direction: Vector2, attack: MeleeAttackData)  ## Instante do golpe.
signal attack_finished

enum Phase { READY, WINDUP, RECOVERY }

## Maior raio de pegada esperado num alvo; amplia a busca física inicial.
const MAX_TARGET_RADIUS := 16.0
const MAX_TARGETS := 32

@export var attack: MeleeAttackData

var _phase := Phase.READY
var _time_left := 0.0
var _direction := Vector2.DOWN

@onready var _body: Character = get_parent()


func is_attacking() -> bool:
	return _phase != Phase.READY


func move_multiplier() -> float:
	return attack.move_multiplier if is_attacking() else 1.0


## `direction` no plano do chão. Retorna se o ataque começou.
func try_attack(direction: Vector2) -> bool:
	if attack == null or is_attacking() or direction == Vector2.ZERO:
		return false
	_direction = direction.normalized()
	_phase = Phase.WINDUP
	_time_left = attack.windup
	attack_started.emit(_direction, attack)
	return true


## Ao ser atingido: interrompe a preparação, se o ataque permitir. Golpes já desferidos
## não são desfeitos.
func interrupt() -> void:
	if _phase == Phase.WINDUP and attack.interruptible:
		_finish()


func _physics_process(delta: float) -> void:
	if _phase == Phase.READY:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	if _phase == Phase.WINDUP:
		_strike()
	else:
		_finish()


func _strike() -> void:
	_phase = Phase.RECOVERY
	_time_left = attack.recovery
	_body.add_ground_impulse(_direction * attack.lunge)
	if _body.is_multiplayer_authority():
		for target in _find_targets():
			target.health.apply_damage(DamageInfo.create(attack.damage, _direction,
				attack.knockback, _body.entity_id, _body.player_id))
	attack_struck.emit(_direction, attack)


func _finish() -> void:
	_phase = Phase.READY
	attack_finished.emit()


func _find_targets() -> Array[Character]:
	# Busca física larga (círculo de tela cobre a elipse do chão), depois filtro exato no chão.
	var shape := CircleShape2D.new()
	shape.radius = _body.footprint_radius() + attack.reach + MAX_TARGET_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, _body.global_position)
	query.collision_mask = PhysicsLayers.ACTORS
	var targets: Array[Character] = []
	for hit in _body.get_world_2d().direct_space_state.intersect_shape(query, MAX_TARGETS):
		var target := hit.collider as Character
		if target != null and _can_hit(target):
			targets.append(target)
	return targets


func _can_hit(target: Character) -> bool:
	if target == _body or target.faction == _body.faction or not target.is_alive():
		return false
	var to_target := Iso.screen_to_ground(target.global_position - _body.global_position)
	var gap := to_target.length() - target.footprint_radius() - _body.footprint_radius()
	if gap > attack.reach:
		return false
	if attack.arc_degrees >= 360.0 or to_target.is_zero_approx():
		return true
	return absf(rad_to_deg(_direction.angle_to(to_target))) <= attack.arc_degrees / 2.0
