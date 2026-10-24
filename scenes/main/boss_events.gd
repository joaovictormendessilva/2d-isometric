class_name BossEvents
extends Node
## Eventos de chefe errante (ADR-036). Só o HOST decide: espera um intervalo sorteado do evento,
## escolhe uma das regiões dele que está carregada e tem jogadores (nunca dungeon), põe o chefe
## num ponto livre perto de um ponto de criatura e avisa todos os jogadores, de todas as regiões.
## Um evento por vez. O chefe vai embora depois de `stay_time` (se não estiver lutando); morto,
## deixa o baú do evento só para quem o feriu. Os avisos (apareceu, foi embora, derrotado) chegam
## a todos os computadores pelo `announced`, conferidos contra os catálogos locais.

signal announced(kind: Announcement, event: BossEventData, region_id: StringName)

enum Announcement { APPEARED, LEFT, DEFEATED }

## Chefes de evento vivos, em todos os computadores (a seta do evento aponta para eles).
const BOSS_GROUP := &"event_bosses"

## Nenhuma região do evento com jogadores na hora: tenta de novo depois deste tempo (s).
const RETRY_TIME := 30.0
## Ponto do chefe: até esta distância (chão) de um ponto de criatura sorteado, com este raio livre.
const SPOT_DISTANCE_MAX := 40.0
const SPOT_CLEARANCE := 16.0
## Acabou o tempo, mas o chefe está lutando: confere de novo depois deste tempo (s).
const LEAVE_CHECK_TIME := 5.0

var spawner: EntitySpawner
## Regiões carregadas no host (onde o chefe pode surgir).
var worlds: RegionWorlds
## Catálogo das regiões (confere o id dos avisos vindos do host).
var regions: DataCatalog

var _rng := RandomNumberGenerator.new()
var _running := false
var _wait := 0.0
var _event: BossEventData
var _boss: Monster
var _stay_left := 0.0
## Quem feriu o chefe atual (só esses abrem o baú).
var _hurt_by: Dictionary[int, bool] = {}


## Host: começa a contar para o primeiro evento. `first_delay` < 0: intervalo sorteado.
func start(first_delay: float = -1.0) -> void:
	if not multiplayer.is_server():
		return
	_running = true
	_wait = first_delay if first_delay >= 0.0 else _next_interval()


func active_boss() -> Monster:
	return _boss if is_instance_valid(_boss) else null


func _physics_process(delta: float) -> void:
	if not _running:
		return
	if active_boss():
		_stay_left -= delta
		if _stay_left <= 0.0:
			_leave_if_idle()
		return
	_wait -= delta
	if _wait <= 0.0:
		_try_start()


func _try_start() -> void:
	var events := spawner.boss_events.entries()
	if events.is_empty():
		_running = false
		return
	var event := events[_rng.randi_range(0, events.size() - 1)] as BossEventData
	var candidates := event.regions.map(worlds.get_region).filter(func(region: Region) -> bool:
		return region != null and not region.is_temporary() and spawner.players_in(region) > 0)
	if candidates.is_empty():
		_wait = RETRY_TIME
		return
	var region: Region = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_event = event
	_boss = spawner.spawn_event_boss(region, event, _find_spot(region))
	_stay_left = event.stay_time
	_hurt_by.clear()
	_boss.health.damaged.connect(_on_boss_damaged)
	_boss.died.connect(_on_boss_died.unbind(1))
	_boss.tree_exiting.connect(_on_boss_gone)
	_announce(Announcement.APPEARED, event, region.region_id)


## Ponto andável e livre perto de um ponto de criatura sorteado da região.
func _find_spot(region: Region) -> Vector2:
	var points := region.get_monster_spawn_points()
	var center := points[_rng.randi_range(0, points.size() - 1)].position if not points.is_empty() \
		else region.get_spawn_position()
	return GroundQuery.find_drop_spot(region.get_world_2d().direct_space_state, center, _rng, 0.0,
		SPOT_DISTANCE_MAX, SPOT_CLEARANCE)


## Acabou o tempo: sem alvo, vai embora; lutando, espera mais um pouco.
func _leave_if_idle() -> void:
	var brain := _boss.get_node("Brain") as MonsterBrain
	if brain.target() != null:
		_stay_left = LEAVE_CHECK_TIME
		return
	var region := Region.of(_boss)
	var boss := _boss
	_finish()
	boss.queue_free()
	_announce(Announcement.LEFT, _event, region.region_id)


func _on_boss_damaged(info: DamageInfo) -> void:
	if info.source_player_id > 0:
		_hurt_by[info.source_player_id] = true


## Derrotado: depois que o corpo some, o baú surge onde ele caiu, só para quem o feriu (e ainda
## está na partida).
func _on_boss_died() -> void:
	var region := Region.of(_boss)
	var allowed: Array[int] = []
	for player_id: int in _hurt_by:
		if spawner.session.get_player_entity(player_id) != null:
			allowed.append(player_id)
	if not allowed.is_empty():
		get_tree().create_timer(EntitySpawner.CORPSE_TIME).timeout.connect(_spawn_chest.bind(
			weakref(region), _event, _boss.position, allowed))
	_finish()
	_announce(Announcement.DEFEATED, _event, region.region_id)


func _spawn_chest(region_ref: WeakRef, event: BossEventData, at: Vector2,
		allowed: Array[int]) -> void:
	var region := region_ref.get_ref() as Region
	if region and not region.is_queued_for_deletion():
		spawner.spawn_event_chest(region, event, at, allowed)


## O chefe sumiu sem morrer nem ir embora (a região foi liberada): o evento acaba em silêncio.
func _on_boss_gone() -> void:
	if _boss != null:
		_finish()


func _finish() -> void:
	_boss = null
	_wait = _next_interval()


func _next_interval() -> float:
	var events := spawner.boss_events.entries()
	if events.is_empty():
		return RETRY_TIME
	var event := events[0] as BossEventData if _event == null else _event
	return _rng.randf_range(event.interval_min, event.interval_max)


## Host → todos (de todas as regiões): o aviso do evento.
func _announce(kind: Announcement, event: BossEventData, region_id: StringName) -> void:
	_announced(kind, String(event.id), String(region_id))
	if NetRules.is_online(multiplayer):
		_announced.rpc(kind, String(event.id), String(region_id))


@rpc("authority", "call_remote", "reliable")
func _announced(kind: int, event_id: String, region_id: String) -> void:
	var event := spawner.boss_events.get_entry(StringName(event_id)) as BossEventData
	if kind >= 0 and kind < Announcement.size() and event \
			and regions.get_entry(StringName(region_id)) != null:
		announced.emit(kind, event, StringName(region_id))
