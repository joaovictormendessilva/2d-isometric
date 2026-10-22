class_name EntitySpawner
extends Node
## Cria e remove entidades (ADR-012). Só o HOST decide: ele chama `spawn_*`, e o
## MultiplayerSpawner filho ("Replicator") repete a criação em cada cliente com a mesma
## função `_instantiate`, inclusive para quem entra com a partida em andamento. Remover o
## nó no host o remove nos clientes.
## Em todos os computadores: registro na sessão e apresentação (números de dano).
## Só no host: morte, renascimento, drops pessoais e IA das criaturas.

signal local_player_spawned(character: Character)

enum Kind { PLAYER, MONSTER, PICKUP, STRUCTURE }

const PLAYER_SCENE := preload("res://scenes/actors/character/player.tscn")
const PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")
const STRUCTURE_SCENE := preload("res://scenes/building/structure.tscn")
const PLAYER_SCALING := preload("res://data/balance/player_scaling.tres")
const PLAYER_RESPAWN_TIME := 2.5
## Tempo que o corpo da criatura fica sumindo antes de ser removido.
const CORPSE_TIME := 0.6
## Onde os drops pousam: distância (chão) da criatura e raio livre exigido no ponto.
const DROP_DISTANCE_MIN := 10.0
const DROP_DISTANCE_MAX := 24.0
const DROP_CLEARANCE := 4.0
const DAMAGE_TO_PLAYER_COLOR := Color("ff6b6b")
const DAMAGE_TO_MONSTER_COLOR := Color.WHITE
const IMMUNE_COLOR := Color("a0a0b4")
## Tom dos personagens dos OUTROS jogadores, para cada um se reconhecer no coop.
const OTHER_PLAYER_TINT := Color(0.6, 1.0, 0.75)
## Limites dos dados de criação recebidos do host (nada maior é legítimo).
const MAX_HEALTH_MULTIPLIER := 100.0
const MAX_PICKUP_AMOUNT := 999

var session: GameSession
var region: Region
var local_player_id := 0
var damage_numbers: DamageNumbers
var items: ItemDatabase
var player_state: PlayerStateSync
## Tipos de estrutura (`data/structures/`), para montar as que o host cria.
var structures: DataCatalog
## Kit de testes dado a cada jogador ao entrar (só em compilações de desenvolvimento; ver main).
var starter_kit: ItemBundle

var _monster_points: Array[MonsterSpawnPoint] = []
var _next_pickup_id := 1
var _next_structure_id := 1
var _rng := RandomNumberGenerator.new()

@onready var _replicator: MultiplayerSpawner = $Replicator


func setup(p_session: GameSession, p_region: Region, p_local_player_id: int,
		p_damage_numbers: DamageNumbers, p_items: ItemDatabase,
		p_player_state: PlayerStateSync) -> void:
	session = p_session
	region = p_region
	local_player_id = p_local_player_id
	damage_numbers = p_damage_numbers
	items = p_items
	player_state = p_player_state
	_monster_points = region.get_monster_spawn_points()
	_rng.randomize()
	_replicator.spawn_path = _replicator.get_path_to(region.entities)
	_replicator.spawn_function = _instantiate


# --- Host: decide o que existe ---------------------------------------------------------------

func spawn_player(player_id: int) -> Character:
	return _replicator.spawn({"kind": Kind.PLAYER, "entity_id": session.allocate_entity_id(),
		"player_id": player_id, "position": region.get_spawn_position()})


func despawn_player(player_id: int) -> void:
	var character := session.get_player_entity(player_id)
	if character:
		character.queue_free()


func spawn_region_monsters() -> void:
	for index in _monster_points.size():
		spawn_monster(index)


func spawn_monster(point_index: int) -> Monster:
	return _replicator.spawn({"kind": Kind.MONSTER, "entity_id": session.allocate_entity_id(),
		"point": point_index, "health_multiplier": CombatRules.monster_health_multiplier(
			session.get_player_count(), PLAYER_SCALING)})


## `from`: onde o item nasce (a criatura); `at`: onde ele pousa.
## `dropped_by_owner`: o próprio dono jogou fora (ele só pega de volta depois de se afastar).
func spawn_pickup(item: ItemData, amount: int, owner_player_id: int, from: Vector2,
		at: Vector2, dropped_by_owner: bool = false) -> Pickup:
	var pickup_id := _next_pickup_id
	_next_pickup_id += 1
	return _replicator.spawn({"kind": Kind.PICKUP, "pickup_id": pickup_id, "item": String(item.id),
		"amount": amount, "owner": owner_player_id, "origin": from, "position": at,
		"dropped": dropped_by_owner})


## Estrutura colocada por um jogador (o lugar já foi conferido, ver PlacementRules).
func spawn_structure(structure: StructureData, at: Vector2) -> Structure:
	var structure_id := _next_structure_id
	_next_structure_id += 1
	return _replicator.spawn({"kind": Kind.STRUCTURE, "structure_id": structure_id,
		"structure": String(structure.id), "position": at})


# --- Todos os computadores: monta o nó a partir dos dados ------------------------------------

## Chamada pelo Replicator no host e em cada cliente. Nos clientes os dados vêm da rede:
## são conferidos antes do uso e nunca carregam caminhos, recursos ou objetos.
func _instantiate(data: Variant) -> Node:
	match _valid_kind(data):
		Kind.PLAYER:
			return _instantiate_player(data)
		Kind.MONSTER:
			return _instantiate_monster(data)
		Kind.PICKUP:
			return _instantiate_pickup(data)
		Kind.STRUCTURE:
			return _instantiate_structure(data)
	push_warning("[spawner] dados de criação inválidos recebidos")
	var inert := Node.new()  # o Replicator exige um nó; este não faz nada
	inert.name = "Invalid"
	return inert


func _instantiate_player(data: Dictionary) -> Character:
	var character: Character = PLAYER_SCENE.instantiate()
	character.player_id = data["player_id"]
	character.position = data["position"]
	_register(character, data["entity_id"])
	session.add_player(character.player_id, character.entity_id, character.stats.inventory_slots)
	var gatherer: Gatherer = character.get_node("Gatherer")
	gatherer.session = session
	gatherer.items = items
	if character.player_id == local_player_id:
		character.add_to_group(OccluderFade.VIEWER_GROUP)
		character.ready.connect(local_player_spawned.emit.bind(character), CONNECT_ONE_SHOT)
	else:
		var visual: CharacterVisual = character.get_node("Visual")
		character.ready.connect(visual.set_tint.bind(OTHER_PLAYER_TINT), CONNECT_ONE_SHOT)
	if multiplayer.is_server():
		character.died.connect(_on_player_died)
		player_state.track_player(character.player_id)
		if starter_kit:
			starter_kit.give_to(session.get_inventory(character.player_id))
	return character


func _instantiate_monster(data: Dictionary) -> Monster:
	var point := _monster_points[data["point"]]
	var monster: Monster = point.monster_scene.instantiate()
	monster.position = point.position
	monster.max_health_multiplier = data["health_multiplier"]
	_register(monster, data["entity_id"])
	monster.died.connect(_on_monster_died.bind(data["point"]))
	if multiplayer.is_server():
		(monster.get_node("Brain") as MonsterBrain).session = session  # IA só no host
	return monster


func _instantiate_pickup(data: Dictionary) -> Pickup:
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	pickup.name = "P%d" % data["pickup_id"]
	pickup.item = items.get_item(StringName(data["item"]))
	pickup.amount = data["amount"]
	pickup.owner_player_id = data["owner"]
	pickup.session = session
	pickup.origin = data["origin"]
	pickup.position = data["position"]
	pickup.waits_for_owner_to_leave = data["dropped"]
	# Drop pessoal: cada computador só mostra os itens do seu jogador local.
	pickup.visible = pickup.owner_player_id == local_player_id
	return pickup


func _instantiate_structure(data: Dictionary) -> Structure:
	var structure: Structure = STRUCTURE_SCENE.instantiate()
	structure.name = "S%d" % data["structure_id"]
	structure.data = structures.get_entry(StringName(data["structure"]))
	structure.position = data["position"]
	return structure


func _register(entity: Character, entity_id: int) -> void:
	entity.name = "E%d" % entity_id  # nomes iguais em todos os computadores (caminho das RPCs)
	entity.entity_id = entity_id
	session.register_entity(entity_id, entity)
	entity.tree_exiting.connect(_on_entity_removed.bind(entity))
	var health: Health = entity.get_node("Health")  # `entity.health` só existe na árvore
	health.damaged.connect(_on_entity_damaged.bind(entity))
	health.blocked.connect(_on_entity_blocked.bind(entity).unbind(1))


## Tipo dos dados de criação, ou -1 se algum campo for inválido.
func _valid_kind(data: Variant) -> int:
	if not data is Dictionary or not data.get("kind") is int:
		return -1
	var d: Dictionary = data
	match d["kind"]:
		Kind.PLAYER:
			if _is_id(d, "entity_id") and _is_id(d, "player_id") and _is_position(d, "position"):
				return Kind.PLAYER
		Kind.MONSTER:
			var multiplier: Variant = d.get("health_multiplier")
			if _is_id(d, "entity_id") and d.get("point") is int \
					and d["point"] >= 0 and d["point"] < _monster_points.size() \
					and multiplier is float and is_finite(multiplier) \
					and multiplier > 0.0 and multiplier <= MAX_HEALTH_MULTIPLIER:
				return Kind.MONSTER
		Kind.PICKUP:
			var item: Variant = d.get("item")
			if _is_id(d, "pickup_id") and _is_id(d, "owner") and _is_position(d, "position") \
					and _is_position(d, "origin") and d.get("dropped") is bool \
					and item is String and items.get_item(StringName(item)) != null \
					and d.get("amount") is int and d["amount"] >= 1 and d["amount"] <= MAX_PICKUP_AMOUNT:
				return Kind.PICKUP
		Kind.STRUCTURE:
			var structure: Variant = d.get("structure")
			if _is_id(d, "structure_id") and _is_position(d, "position") and structure is String \
					and structures.get_entry(StringName(structure)) is StructureData:
				return Kind.STRUCTURE
	return -1


static func _is_id(data: Dictionary, key: String) -> bool:
	return data.get(key) is int and data[key] > 0


static func _is_position(data: Dictionary, key: String) -> bool:
	return data.get(key) is Vector2 and NetRules.is_valid_vector(data[key])


# --- Apresentação ----------------------------------------------------------------------------

func _on_entity_damaged(info: DamageInfo, entity: Character) -> void:
	var color := DAMAGE_TO_PLAYER_COLOR if entity.player_id != 0 else DAMAGE_TO_MONSTER_COLOR
	damage_numbers.show_number(entity.position, info.amount, color)


func _on_entity_blocked(entity: Character) -> void:
	damage_numbers.show_text(entity.position, Texts.get_text(&"COMBAT_IMMUNE"), IMMUNE_COLOR)


# --- Ciclo de vida -----------------------------------------------------------------------------

func _on_entity_removed(entity: Character) -> void:
	session.unregister_entity(entity.entity_id)
	if entity.player_id != 0 and session.get_player_entity(entity.player_id) == null:
		session.remove_player(entity.player_id)


func _on_player_died(character: Character) -> void:
	get_tree().create_timer(PLAYER_RESPAWN_TIME).timeout.connect(
		_revive_player.bind(character.player_id))


## Por ID: o jogador pode ter saído da partida enquanto esperava renascer.
func _revive_player(player_id: int) -> void:
	var character := session.get_player_entity(player_id) as Character
	if character:
		character.revive(region.get_spawn_position())


## Em todos os computadores a criatura morta sai do registro; no host, ela também deixa
## drops, some e agenda o renascimento.
func _on_monster_died(monster: Character, point_index: int) -> void:
	session.unregister_entity(monster.entity_id)
	if not multiplayer.is_server():
		return
	_spawn_drops(monster as Monster)
	get_tree().create_timer(CORPSE_TIME).timeout.connect(monster.queue_free)
	get_tree().create_timer(_monster_points[point_index].respawn_time).timeout.connect(
		spawn_monster.bind(point_index))


## Drops pessoais: a tabela é sorteada separadamente para cada jogador da sessão. Cada item
## pousa num ponto andável e alcançável perto da criatura (nunca na água ou dentro de objetos).
func _spawn_drops(monster: Monster) -> void:
	var space := region.get_world_2d().direct_space_state
	for player_id in session.get_player_ids():
		for entry in monster.data.drops:
			var amount := entry.roll(_rng)
			if amount > 0:
				var spot := GroundQuery.find_drop_spot(space, monster.position, _rng,
					DROP_DISTANCE_MIN, DROP_DISTANCE_MAX, DROP_CLEARANCE)
				spawn_pickup(entry.item, amount, player_id, monster.position, spot)
