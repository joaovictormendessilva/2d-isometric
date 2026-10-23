class_name SlamAttacker
extends Node
## Salto com queda em área do Character pai (chefes, F4): aviso no chão → voo → impacto →
## recuperação parada. Quem simula o corpo (o host) o leva pelo ar até o ponto de queda e só
## o host aplica o dano. Nos outros computadores o salto roda igual, só para a apresentação
## (altura do pulo, aviso no chão); a posição chega pela rede (NetSync).

## Início do aviso: `landing` é o ponto de queda (tela).
signal slam_started(landing: Vector2, attack: SlamAttackData)
## Saiu do chão.
signal slam_launched
## Caiu: instante do impacto.
signal slam_landed(landing: Vector2, attack: SlamAttackData)
signal slam_finished

enum Phase { READY, WINDUP, AIRBORNE, RECOVERY }

@export var attack: SlamAttackData

var _phase := Phase.READY
var _elapsed := 0.0
var _cooldown_left := 0.0
var _from := Vector2.ZERO
var _landing := Vector2.ZERO
var _next_attack: SlamAttackData

@onready var _body: Character = get_parent()


func is_slamming() -> bool:
	return _phase != Phase.READY


## Pronto para saltar (parado e fora da espera entre saltos)?
func can_slam() -> bool:
	return attack != null and _phase == Phase.READY and _cooldown_left <= 0.0


func move_multiplier() -> float:
	return 0.0 if is_slamming() else 1.0


## Ponto de queda do salto em andamento (tela).
func landing() -> Vector2:
	return _landing


## Tempo desde o início do salto, até a queda (aviso + voo). Apresentação.
func elapsed_until_landing() -> float:
	match _phase:
		Phase.WINDUP:
			return maxf(_elapsed, 0.0)
		Phase.AIRBORNE:
			return attack.windup + _elapsed
	return attack.windup + attack.air_time


## Fração do aviso já passada (0 a 1; fora dele, 0). Apresentação (pose de preparação).
func windup_progress() -> float:
	return clampf(_elapsed / attack.windup, 0.0, 1.0) if _phase == Phase.WINDUP else 0.0


func is_airborne() -> bool:
	return _phase == Phase.AIRBORNE


## Altura atual do pulo na tela (0 no chão). Apresentação.
func height() -> float:
	if _phase != Phase.AIRBORNE:
		return 0.0
	return sin(PI * clampf(_elapsed / attack.air_time, 0.0, 1.0)) * attack.height


## Começa o salto até `landing_point` (tela).
func try_slam(landing_point: Vector2) -> bool:
	if not can_slam():
		return false
	_from = _body.position
	_landing = landing_point
	_phase = Phase.WINDUP
	_elapsed = 0.0
	slam_started.emit(_landing, attack)
	return true


## Salto decidido em outro computador (o host; ver NetSync): ignora a espera entre saltos, que
## pode diferir um pouco entre computadores. `delay` (s) atrasa o início para combinar com a
## posição recebida, que é desenhada um pouco no passado.
func play_remote(landing_point: Vector2, delay: float) -> void:
	stop()
	_cooldown_left = 0.0
	if try_slam(landing_point):
		_elapsed = -delay


## Troca o salto (fase do chefe). No meio de um salto, vale a partir do próximo.
func set_attack(value: SlamAttackData) -> void:
	if is_slamming():
		_next_attack = value
	else:
		attack = value


## Encerra o salto (ex.: ao morrer). Sem impacto.
func stop() -> void:
	if is_slamming():
		_finish()


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if is_slamming():
		_advance(delta)


func _advance(delta: float) -> void:
	_elapsed += delta
	if _phase == Phase.WINDUP and _elapsed >= attack.windup:
		_elapsed -= attack.windup
		_phase = Phase.AIRBORNE
		slam_launched.emit()
	if _phase == Phase.AIRBORNE:
		if _simulates():
			_body.ground_velocity = Vector2.ZERO
			_body.position = _from.lerp(_landing, clampf(_elapsed / attack.air_time, 0.0, 1.0))
		if _elapsed >= attack.air_time:
			_elapsed -= attack.air_time
			_land()
	if _phase == Phase.RECOVERY and _elapsed >= attack.recovery:
		_finish()


func _finish() -> void:
	_phase = Phase.READY
	if _next_attack:
		attack = _next_attack
		_next_attack = null
	slam_finished.emit()


func _land() -> void:
	_phase = Phase.RECOVERY
	_cooldown_left = attack.cooldown
	if multiplayer.is_server():
		for target in AreaStrike.hit(_body, _landing, attack.radius, attack.damage,
				attack.knockback):
			_body.apply_hit_effects(target)
	slam_landed.emit(_landing, attack)


## Este computador move o corpo? (O host, ou offline; nos outros a posição vem da rede.)
func _simulates() -> bool:
	return _body.net == null or _body.net.is_simulating()
