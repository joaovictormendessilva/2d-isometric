class_name RideState
extends RefCounted
## Se um jogador está a pé, subindo na montaria ou montado (ADR-035). Fica na sessão (não no
## personagem), para continuar montado ao viajar entre regiões. Só o host decide as mudanças;
## os outros computadores recebem a fase (`replicate`).

signal changed

enum Phase { ON_FOOT, MOUNTING, MOUNTED }

var phase := Phase.ON_FOOT
## Subindo: segundos que faltam e o total (para a barra de progresso).
var _time_left := 0.0
var _mount_time := 0.0


func is_mounted() -> bool:
	return phase == Phase.MOUNTED


## Subindo ou montado: o jogador não ataca, não coleta nem lança habilidades.
func is_busy() -> bool:
	return phase != Phase.ON_FOOT


## Subindo: quanto já foi (0 a 1).
func progress() -> float:
	return 1.0 - _time_left / _mount_time if phase == Phase.MOUNTING and _mount_time > 0.0 else 0.0


## Começa a subir; `seconds` = tempo de montar da montaria.
func start(seconds: float) -> void:
	_mount_time = maxf(seconds, 0.0)
	_time_left = _mount_time
	_set_phase(Phase.MOUNTING)


## Passa o tempo de subir. `can_finish`: só quem decide (host) completa a subida; os outros
## computadores só andam a barra e esperam a fase oficial.
func advance(delta: float, can_finish: bool) -> void:
	if phase != Phase.MOUNTING:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	if _time_left == 0.0 and can_finish:
		_set_phase(Phase.MOUNTED)


## Desce (ou desiste de subir).
func dismount() -> void:
	_set_phase(Phase.ON_FOOT)


## Fase vinda do host (já conferida). Subindo: a barra recomeça com `seconds`.
func replicate(value: Phase, seconds: float) -> void:
	if value == Phase.MOUNTING:
		start(seconds)
	else:
		_set_phase(value)


func _set_phase(value: Phase) -> void:
	if value != phase:
		phase = value
		changed.emit()
	elif value == Phase.MOUNTING:
		changed.emit()  # recomeçou a subir
