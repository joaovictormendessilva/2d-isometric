class_name MeleeAttacker
extends Node
## Executa ataques corpo a corpo do Character pai: preparação (telegrafia) → golpe → recuperação.
## No instante do golpe, procura alvos de outra facção dentro do arco, no plano do chão; numa
## investida (`lunge_hit_time`), continua acertando quem o avanço tocar, uma vez cada.
## Só o HOST aplica o dano (`multiplayer.is_server()`; offline também é host). Nos outros
## computadores o ataque roda igual, só para a apresentação e o bote.

signal attack_started(direction: Vector2, attack: MeleeAttackData)  ## Início da preparação.
signal attack_struck(direction: Vector2, attack: MeleeAttackData)  ## Instante do golpe.
signal attack_finished

enum Phase { READY, WINDUP, RECOVERY }

@export var attack: MeleeAttackData

var _phase := Phase.READY
var _time_left := 0.0
var _direction := Vector2.DOWN
var _next_attack: MeleeAttackData
## Investida: tempo que o avanço ainda acerta, e quem já foi acertado neste ataque.
var _hit_left := 0.0
var _hit: Dictionary[Character, bool] = {}

@onready var _body: Character = get_parent()


func is_attacking() -> bool:
	return _phase != Phase.READY


func move_multiplier() -> float:
	return attack.move_multiplier if is_attacking() else 1.0


## `direction` no plano do chão. Retorna se o ataque começou. `tolerance` (s) aceita um
## ataque que chega pela rede um pouco antes de a recuperação anterior terminar aqui
## (variação de chegada dos pacotes), sem permitir golpes mais rápidos que o normal.
func try_attack(direction: Vector2, tolerance: float = 0.0) -> bool:
	if attack == null or direction == Vector2.ZERO:
		return false
	if _phase == Phase.WINDUP or (_phase == Phase.RECOVERY and _time_left > tolerance):
		return false
	_direction = direction.normalized()
	_phase = Phase.WINDUP
	_time_left = attack.windup
	attack_started.emit(_direction, attack)
	return true


## Encerra qualquer ataque em andamento, mesmo os que não se interrompem (ex.: ao morrer).
func stop() -> void:
	if is_attacking():
		_finish()


## Ao ser atingido: interrompe a preparação, se o ataque permitir. Golpes já desferidos
## não são desfeitos.
func interrupt() -> void:
	if _phase == Phase.WINDUP and attack.interruptible:
		_finish()


func _physics_process(delta: float) -> void:
	if _phase == Phase.READY:
		return
	if _hit_left > 0.0:
		_hit_left -= delta
		_hit_targets()
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
	_hit.clear()
	_hit_left = attack.lunge_hit_time
	_hit_targets()
	attack_struck.emit(_direction, attack)


## Só o host aplica dano; cada alvo uma vez por ataque.
func _hit_targets() -> void:
	if not multiplayer.is_server():
		return
	for target in _find_targets():
		if not _hit.has(target):
			_hit[target] = true
			target.health.apply_damage(DamageInfo.create(attack.damage, _direction,
				attack.knockback, _body.entity_id, _body.player_id))


## Troca o golpe (ex.: arma vestida). No meio de um ataque, vale a partir do próximo.
func set_attack(value: MeleeAttackData) -> void:
	if is_attacking():
		_next_attack = value
	else:
		attack = value


func _finish() -> void:
	_phase = Phase.READY
	_hit_left = 0.0
	_hit.clear()
	if _next_attack:
		attack = _next_attack
		_next_attack = null
	attack_finished.emit()


func _find_targets() -> Array[Character]:
	return ActorQuery.hostiles_near(_body, _body.global_position, _body.footprint_radius(),
		attack.reach).filter(_in_arc)


func _in_arc(target: Character) -> bool:
	var to_target := Iso.screen_to_ground(target.global_position - _body.global_position)
	if attack.arc_degrees >= 360.0 or to_target.is_zero_approx():
		return true
	return absf(rad_to_deg(_direction.angle_to(to_target))) <= attack.arc_degrees / 2.0
