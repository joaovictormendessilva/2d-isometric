class_name Channel
extends Node
## Canalização do Character pai (jogador; ADR-037): ficar alguns segundos no lugar até uma ação
## acontecer (viajar por uma pedra de portal). Só o host começa e completa; dano, morte ou sair do
## lugar interrompem. Os outros computadores recebem o começo e o fim pelo NetSync e só mostram a
## barrinha de progresso.

## Começou ou acabou (completou ou foi interrompida).
signal changed

## Andar mais que isto (chão) desde o começo interrompe.
const MOVE_TOLERANCE := 6.0

var _seconds := 0.0
var _left := 0.0
var _done := Callable()
var _from := Vector2.ZERO

@onready var _body: Character = get_parent()


func _ready() -> void:
	if _body.health:
		_body.health.damaged.connect(_interrupt.unbind(1))
	_body.died.connect(_interrupt.unbind(1))


func is_channeling() -> bool:
	return _seconds > 0.0


## Quanto já foi (0 a 1).
func progress() -> float:
	return 1.0 - _left / _seconds if is_channeling() else 0.0


func seconds() -> float:
	return _seconds


## Host: começa a canalizar por `seconds`; `done` é chamada ao completar. Retorna se começou
## (vivo, livre para agir, a pé ou já montado, e sem outra canalização).
func start(seconds: float, done: Callable) -> bool:
	if is_channeling() or seconds <= 0.0 or not _body.can_act(true):
		return false
	_done = done
	_from = _body.position
	_run(seconds)
	return true


## Começo (`seconds` > 0) ou fim (0) vindo do host, só para a barra.
func replicate(seconds: float) -> void:
	_run(seconds)


func _physics_process(delta: float) -> void:
	if not is_channeling():
		return
	_left = maxf(_left - delta, 0.0)
	if not multiplayer.is_server():
		return
	if Iso.ground_distance(_from, _body.position) > MOVE_TOLERANCE:
		_run(0.0)
	elif _left == 0.0:
		var done := _done
		_run(0.0)
		done.call()


func _interrupt() -> void:
	if multiplayer.is_server() and is_channeling():
		_run(0.0)


func _run(seconds: float) -> void:
	_seconds = seconds
	_left = seconds
	if seconds == 0.0:
		_done = Callable()
	changed.emit()
