class_name Gatherer
extends Node
## Coleta do Character pai em pontos de coleta (`ResourceNode`). Cada coleta leva um tempo
## (`GatheringRules.gather_duration`); ao terminar, o HOST sorteia o rendimento, entrega os
## itens e a experiência e gasta uma carga do ponto. A coleta continua sozinha até o ponto
## esgotar, e para se o jogador se mexer, atacar, apanhar ou sair de alcance.
## No coop, o dono coleta na hora (barra de progresso) e pede ao host, que confere tudo de
## novo e decide o resultado (ver NetSync).

signal started(node: ResourceNode, duration: float)
signal stopped
## O jogador tentou coletar mas não pode (sem ferramenta ou nível): apresentação.
signal refused(node: ResourceNode, reason: GatheringRules.Check)

const BALANCE := preload("res://data/balance/gathering.tres")
## Quanto o corpo pode se afastar de onde começou a coletar antes de a coleta cair.
const MOVE_TOLERANCE := 3.0
## Maior raio de pegada de um ponto de coleta; amplia a busca física.
const MAX_NODE_RADIUS := 16.0

var session: GameSession
var items: ItemDatabase

var _node: ResourceNode
var _duration := 0.0
var _time_left := 0.0
var _anchor := Vector2.ZERO
var _move_tolerance := MOVE_TOLERANCE
var _rng := RandomNumberGenerator.new()

@onready var _body: Character = get_parent()


func _ready() -> void:
	_rng.randomize()


func is_gathering() -> bool:
	return _node != null


func current_node() -> ResourceNode:
	return _node


## Progresso da coleta atual (0 a 1), para a barra.
func progress() -> float:
	return 1.0 - _time_left / _duration if is_gathering() and _duration > 0.0 else 0.0


## Ponto de coleta não esgotado mais próximo ao alcance, ou null.
func find_node() -> ResourceNode:
	var shape := CircleShape2D.new()
	shape.radius = _body.footprint_radius() + BALANCE.gather_range + MAX_NODE_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, _body.global_position)
	query.collision_mask = PhysicsLayers.WORLD
	var best: ResourceNode
	var best_gap := INF
	for hit in _body.get_world_2d().direct_space_state.intersect_shape(query, 16):
		var node := hit.collider as ResourceNode
		if node == null or node.is_depleted():
			continue
		var gap := _gap_to(node)
		if gap <= BALANCE.gather_range and gap < best_gap:
			best = node
			best_gap = gap
	return best


## Começa a coletar `node`. `slack` alarga o alcance e a tolerância de movimento para pedidos
## que chegam pela rede (o host vê o jogador um pouco atrasado). Retorna se começou.
func try_gather(node: ResourceNode, slack: float = 0.0) -> bool:
	if node == null or node.is_depleted() or _gap_to(node) > BALANCE.gather_range + slack:
		return false
	var result := check(node)
	if result != GatheringRules.Check.OK:
		refused.emit(node, result)
		return false
	stop()
	_node = node
	_duration = GatheringRules.gather_duration(node.data, _skill_level(node.data.skill),
		GatheringRules.best_tool(node.data, _tools()), BALANCE)
	_time_left = _duration
	_anchor = _body.position
	_move_tolerance = MOVE_TOLERANCE + slack
	started.emit(node, _duration)
	return true


## Este jogador pode coletar `node` (ferramenta e nível)?
func check(node: ResourceNode) -> GatheringRules.Check:
	return GatheringRules.check(node.data, _skill_level(node.data.skill),
		GatheringRules.best_tool(node.data, _tools()))


func stop() -> void:
	if is_gathering():
		_node = null
		stopped.emit()


func _physics_process(delta: float) -> void:
	if not is_gathering():
		return
	if not _body.is_alive() or _node.is_depleted() \
			or _body.position.distance_to(_anchor) > _move_tolerance:
		stop()
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	if multiplayer.is_server():
		_complete()
	_time_left += _duration  # segue coletando; o ponto esgotado encerra no próximo passo


## Host: uma coleta concluída.
func _complete() -> void:
	var data := _node.data
	var level := _skill_level(data.skill)
	var inventory := session.get_inventory(_body.player_id)
	var gained := GatheringRules.roll_yield(data, level, _rng)
	for item_id in gained:
		inventory.add(item_id, gained[item_id])
	session.get_skills(_body.player_id).add_xp(data.skill.id, data.xp_per_gather)
	_node.take_charge()


func _gap_to(node: ResourceNode) -> float:
	var footprint: Footprint = node.get_node("Footprint")
	return Iso.ground_distance(_body.position, node.position) - _body.footprint_radius() \
		- footprint.radius


func _tools() -> Array[ToolData]:
	var inventory := session.get_inventory(_body.player_id) if session else null
	return items.tools_in(inventory) if inventory and items else [] as Array[ToolData]


func _skill_level(skill: GatheringSkillData) -> int:
	var progress := session.get_skills(_body.player_id) if session else null
	return progress.level(skill) if progress else 1
