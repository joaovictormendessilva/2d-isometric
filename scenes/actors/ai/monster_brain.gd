class_name MonsterBrain
extends Node
## IA simples e reutilizável: percebe o jogador mais próximo dentro do raio de agressão,
## persegue, ataca quando no alcance e volta para casa se for longe demais.
## Ao desistir, volta até casa antes de perceber alguém de novo: sem isso, ela oscila na
## borda da coleira quando o jogador para logo depois dela.
## Gera só INTENÇÕES para o Monster pai — igual a um jogador, mas automatizado.
## Sem busca de caminho por enquanto: as pegadas redondas deslizam em volta dos obstáculos.

## A escolha de alvo roda a 5 Hz (barato com muitas criaturas); o movimento, todo quadro.
const THINK_INTERVAL := 0.2
## Ataca quando a folga até o alvo for menor que esta fração do alcance.
const ATTACK_RANGE_FRACTION := 0.8
const HOME_TOLERANCE := 6.0
const RETURN_SPEED := 0.6

var session: GameSession

var _home := Vector2.ZERO
var _target: Character
var _returning := false
var _think_left := 0.0

@onready var _body: Monster = get_parent()


func _ready() -> void:
	process_physics_priority = -10  # decide antes da física do corpo
	_home = _body.position
	_think_left = randf() * THINK_INTERVAL  # espalha o custo entre quadros


## Desistiu da perseguição e está voltando para casa (ignora jogadores até chegar).
func is_returning() -> bool:
	return _returning


func _physics_process(delta: float) -> void:
	if not _body.is_alive() or session == null:
		return
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = THINK_INTERVAL
		_think()
	if _target == null:
		_return_home()
		return
	var to_target := Iso.screen_to_ground(_target.position - _body.position)
	var gap := to_target.length() - _target.footprint_radius() - _body.footprint_radius()
	if gap <= _body.data.attack.reach * ATTACK_RANGE_FRACTION:
		_body.set_move_intent(Vector2.ZERO)
		_body.request_attack(to_target)
	else:
		_body.set_move_intent(to_target.normalized())


func _think() -> void:
	if Iso.ground_distance(_body.position, _home) > _body.data.leash_radius:
		_returning = true
	_target = null if _returning else _pick_target()


## Jogador vivo mais próximo dentro do raio de agressão.
func _pick_target() -> Character:
	var best: Character
	var best_distance := _body.data.aggro_radius
	for player_id in session.get_player_ids():
		var candidate := session.get_player_entity(player_id) as Character
		if candidate == null or not candidate.is_alive():
			continue
		var distance := Iso.ground_distance(_body.position, candidate.position)
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	return best


func _return_home() -> void:
	var to_home := Iso.screen_to_ground(_home - _body.position)
	if to_home.length() <= HOME_TOLERANCE:
		_returning = false
		_body.set_move_intent(Vector2.ZERO)
	else:
		_body.set_move_intent(to_home.normalized() * RETURN_SPEED)
