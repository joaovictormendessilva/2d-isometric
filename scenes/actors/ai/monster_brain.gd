class_name MonsterBrain
extends Node
## IA simples e reutilizável: percebe o jogador mais próximo dentro do raio de agressão,
## persegue, ataca quando no alcance e volta para casa se for longe demais.
## Ao desistir ("evadir"), volta até casa imune e sem perceber ninguém, e lá recupera a vida
## toda. Sem isso, ela oscila na borda da coleira ou vira alvo fácil enquanto foge.
## Gera só INTENÇÕES para o Monster pai — igual a um jogador, mas automatizado.
## Criaturas com salto (SlamAttacker, chefes) saltam sobre alvos a meia distância, se o ponto
## de queda for chão livre; perto, usam o golpe comum.
## Filhotes de chefe (`leader`) não têm casa nem coleira: seguem o chefe e atacam o alvo dele
## (quem o chefe persegue, mesmo longe); se o chefe desiste ou morre, os filhotes somem.
## Sem busca de caminho por enquanto: as pegadas redondas deslizam em volta dos obstáculos.

## A escolha de alvo roda a 5 Hz (barato com muitas criaturas); o movimento, todo quadro.
const THINK_INTERVAL := 0.2
## Sem `engage_distance` no ataque: ataca quando a folga até o alvo for menor que esta fração do
## alcance.
const ATTACK_RANGE_FRACTION := 0.8
const HOME_TOLERANCE := 6.0
## Fração da velocidade ao voltar para casa sem ter desistido (alvo saiu do raio de agressão).
const IDLE_RETURN_SPEED := 0.6
## Filhote sem alvo fica a esta distância (chão) do chefe, em vez de colar nele.
const LEADER_FOLLOW_DISTANCE := 30.0

var session: GameSession
## Chefe que invocou esta criatura (host; ver EntitySpawner). Null = criatura comum.
var leader: Monster

var _home := Vector2.ZERO
var _target: Character
var _returning := false
var _think_left := 0.0

@onready var _body: Monster = get_parent()


func _ready() -> void:
	process_physics_priority = -10  # decide antes da física do corpo
	_home = _body.position
	_think_left = randf() * THINK_INTERVAL  # espalha o custo entre quadros


## Jogador que está perseguindo (null = nenhum). Filhotes atacam o alvo do chefe.
func target() -> Character:
	return _target if is_instance_valid(_target) else null


## Desistiu da perseguição e está voltando para casa (imune, ignora jogadores até chegar).
func is_returning() -> bool:
	return _returning


func _physics_process(delta: float) -> void:
	if not _body.is_alive() or session == null:
		return
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = THINK_INTERVAL
		_think()
	if _body.slammer and _body.slammer.is_slamming():
		return  # no ar ou se recuperando: o salto decide
	if _target == null:
		_return_home()
		return
	var to_target := Iso.screen_to_ground(_target.position - _body.position)
	if _try_slam(to_target):
		return
	var gap := to_target.length() - _target.footprint_radius() - _body.footprint_radius()
	if gap <= _engage_distance():
		_body.set_move_intent(Vector2.ZERO)
		_body.request_attack(to_target)
	else:
		_body.set_move_intent(to_target.normalized())


func _think() -> void:
	if is_instance_valid(leader) and leader.is_alive():
		_home = leader.position
		var leader_target := (leader.get_node("Brain") as MonsterBrain).target()
		_target = leader_target if leader_target else _pick_target()
		return
	if not _returning and Iso.ground_distance(_body.position, _home) > _body.data.leash_radius:
		_returning = true
		_body.health.set_immune(true)
	_target = null if _returning else _pick_target()


## Salta no alvo se puder: salto pronto, alvo a meia distância e chão livre onde ele está.
func _try_slam(to_target: Vector2) -> bool:
	if _body.slammer == null or not _body.slammer.can_slam():
		return false
	var slam := _body.slammer.attack
	var distance := to_target.length()
	if distance < slam.min_distance or distance > slam.max_distance:
		return false
	var space := _body.get_world_2d().direct_space_state
	return GroundQuery.is_walkable(space, _target.position, _body.footprint_radius()) \
		and _body.request_slam(_target.position)


## Folga até o alvo para começar o golpe: a do ataque (investidas começam de longe) ou parte
## do alcance.
func _engage_distance() -> float:
	var attack := _body.data.attack
	return attack.engage_distance if attack.engage_distance > 0.0 \
		else attack.reach * ATTACK_RANGE_FRACTION


## Jogador vivo mais próximo dentro do raio de agressão.
func _pick_target() -> Character:
	var best: Character
	var best_distance := _body.data.aggro_radius
	for player_id in session.get_player_ids():
		var candidate := session.get_player_entity(player_id) as Character
		# Só quem está na mesma região (o host simula várias, cada uma no seu mundo).
		if candidate == null or not candidate.is_alive() or candidate.get_parent() != _body.get_parent():
			continue
		var distance := Iso.ground_distance(_body.position, candidate.position)
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	return best


func _return_home() -> void:
	var to_home := Iso.screen_to_ground(_home - _body.position)
	var tolerance := LEADER_FOLLOW_DISTANCE if is_instance_valid(leader) else HOME_TOLERANCE
	if to_home.length() > tolerance:
		_body.set_move_intent(to_home.normalized() * (1.0 if _returning else IDLE_RETURN_SPEED))
		return
	_body.set_move_intent(Vector2.ZERO)
	if _returning:
		_returning = false
		_body.health.set_immune(false)
		_body.health.restore_full()
