class_name Rider
extends Node
## Montaria do Character pai (jogador; ADR-035). O estado (a pé, subindo, montado) é o
## `RideState` do jogador na sessão, que sobrevive à viagem entre regiões; a montaria é a vestida
## (`Character.mount`). Só o host muda o estado: começa a subir a pedido do jogador (livre para
## agir e com montaria vestida), completa a subida e derruba quem leva dano, morre ou tira a
## montaria. Os outros computadores recebem a fase pelo NetSync e só andam a barra de subir.

var state := RideState.new()

@onready var _body: Character = get_parent()


func _ready() -> void:
	if _body.health:
		_body.health.damaged.connect(_knock_off.unbind(1))
	_body.died.connect(_knock_off.unbind(1))


func is_mounted() -> bool:
	return state.is_mounted() and _body.mount != null


## Subindo ou montado: não ataca, não coleta nem lança habilidades.
func is_busy() -> bool:
	return state.is_busy()


## Multiplica a velocidade de andar (atributo; vale também na conferência do host): montado, a
## da montaria.
func speed_factor() -> float:
	return 1.0 + _body.mount.speed_percent / 100.0 if is_mounted() else 1.0


## Multiplica a velocidade só na física, como o ataque e o lançamento: subindo, fica parado.
func move_multiplier() -> float:
	return 0.0 if state.phase == RideState.Phase.MOUNTING else 1.0


## Host: o jogador apertou a tecla de montar. A pé: começa a subir (se der); subindo ou
## montado: desce. Canalizando, nada. Retorna se algo mudou.
func toggle() -> bool:
	if _body.channel and _body.channel.is_channeling():
		return false  # canalizando, não faz nada além de andar
	if state.is_busy():
		state.dismount()
		return true
	if _body.mount == null or not _body.can_act():
		return false
	state.start(_body.mount.mount_time)
	return true


## Host: a montaria vestida mudou; sem montaria, desce.
func mount_changed() -> void:
	if _body.mount == null and multiplayer.is_server():
		state.dismount()


func _physics_process(delta: float) -> void:
	state.advance(delta, multiplayer.is_server())  # corpo aposentado (viagem) não processa


func _knock_off() -> void:
	if multiplayer.is_server():
		state.dismount()
