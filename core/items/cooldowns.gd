class_name Cooldowns
extends RefCounted
## Esperas de um jogador por grupo (ex.: poções), em segundos de `NetRules.now()`. O host
## decide; o dono recebe cada espera começada e conta no próprio relógio (ver PlayerStateSync).

signal started(group: StringName, seconds: float)

## Maior espera aceita da rede (protege o cliente de valores absurdos).
const MAX_SECONDS := 600.0

var _ready_at: Dictionary[StringName, float] = {}


func remaining(group: StringName, now: float) -> float:
	return maxf(_ready_at.get(group, 0.0) - now, 0.0)


func is_ready(group: StringName, now: float) -> bool:
	return remaining(group, now) == 0.0


## Host: começa a espera do grupo. Também usado pelo cliente com o valor vindo do host.
func start(group: StringName, seconds: float, now: float) -> void:
	if seconds <= 0.0:
		return
	_ready_at[group] = now + seconds
	started.emit(group, seconds)
