class_name EntitySpawner
extends Node
## Cria e remove entidades (ADR-012). Só o HOST decide: ele chama `spawn_*`/`enter_region`, e
## o MultiplayerSpawner ("Replicator") de cada região repete a criação nos clientes com a
## mesma função `_instantiate`, inclusive para quem entra com a partida em andamento. Remover
## o nó no host o remove nos clientes.
## Regiões (ADR-020): cada jogador está numa região, e cada cliente só recebe as entidades da
## região onde o jogador dele está. Toda entidade criada tem um "portão" (MultiplayerSynchronizer
## sem propriedades) cuja visibilidade, decidida no host, controla a quem ela é enviada.
## Em todos os computadores: registro na sessão e apresentação (números de dano).
## Só no host: morte, renascimento, drops pessoais, filhotes dos chefes e IA das criaturas.

signal local_player_spawned(character: Character)
## Host: o jogador local chegou ao mundo com o save (ou o equipamento inicial) já aplicado.
signal local_player_prepared

enum Kind { PLAYER, MONSTER, PICKUP, STRUCTURE, MINION }

const PLAYER_SCENE := preload("res://scenes/actors/character/player.tscn")
const PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")
const STRUCTURE_SCENE := preload("res://scenes/building/structure.tscn")
const PLAYER_SCALING := preload("res://data/balance/player_scaling.tres")
const PLAYER_RESPAWN_TIME := 2.5
## Tempo que o corpo da criatura fica sumindo antes de ser removido.
const CORPSE_TIME := 0.6
## Personagem que trocou de região: some para todos na hora, mas o nó fica este tempo parado
## no host, para receber (e ignorar) o que o dono mandou antes de saber da viagem.
const RETIRE_TIME := 1.0
## Onde os drops pousam: distância (chão) da criatura e raio livre exigido no ponto.
const DROP_DISTANCE_MIN := 10.0
const DROP_DISTANCE_MAX := 24.0
const DROP_CLEARANCE := 4.0
## Onde os filhotes do chefe surgem: distância (chão) do ponto de queda e raio livre exigido.
const MINION_DISTANCE_MIN := 22.0
const MINION_DISTANCE_MAX := 40.0
const MINION_CLEARANCE := 6.0
const DAMAGE_TO_PLAYER_COLOR := Color("ff6b6b")
const DAMAGE_TO_MONSTER_COLOR := Color.WHITE
const IMMUNE_COLOR := Color("a0a0b4")
const HEAL_COLOR := UiStyle.POSITIVE
## Aviso de fúria do chefe: mais tempo na tela que um número de dano.
const ENRAGED_TEXT_TIME := 1.6
## Tom dos personagens dos OUTROS jogadores, para cada um se reconhecer no coop.
const OTHER_PLAYER_TINT := Color(0.6, 1.0, 0.75)
## Limites dos dados de criação recebidos do host (nada maior é legítimo).
const MAX_HEALTH_MULTIPLIER := 100.0
const MAX_PICKUP_AMOUNT := 999
const REPLICATOR_NAME := "Replicator"
const GATE_NAME := "RegionGate"

var session: GameSession
var local_player_id := 0
var damage_numbers: DamageNumbers
var items: ItemDatabase
var player_state: PlayerStateSync
## Host: envia ao dono o livro de habilidades de cada jogador que chega.
var abilities: AbilitySync
## Tipos de estrutura (`data/structures/`), para montar as que o host cria.
var structures: DataCatalog
## Kit de testes dado a cada jogador NOVO (só em compilações de desenvolvimento; ver main).
var starter_kit: ItemBundle
## Save do mundo (host): devolve o progresso de quem volta. Null = sem save.
var saves: SaveService

var _next_pickup_id := 1
var _next_structure_id := 1
var _rng := RandomNumberGenerator.new()
## Equipamento de cada jogador já ligado ao tamanho do inventário (uma vez: o personagem é
## recriado a cada viagem, o equipamento continua).
var _sized: Dictionary[int, Equipment] = {}
## Host: filhotes vivos de cada chefe (id da entidade do chefe -> filhotes).
var _minions: Dictionary[int, Array] = {}


func setup(p_session: GameSession, p_local_player_id: int, p_damage_numbers: DamageNumbers,
		p_items: ItemDatabase, p_player_state: PlayerStateSync) -> void:
	session = p_session
	local_player_id = p_local_player_id
	damage_numbers = p_damage_numbers
	items = p_items
	player_state = p_player_state
	_rng.randomize()


## Região recém-carregada neste computador (host ou cliente): ganha o replicador dela, com o
## mesmo caminho dos dois lados.
func add_region(region: Region) -> void:
	var replicator := MultiplayerSpawner.new()
	replicator.name = REPLICATOR_NAME
	region.add_child(replicator)
	replicator.spawn_path = replicator.get_path_to(region.entities)
	replicator.spawn_function = _instantiate.bind(region)


# --- Host: quem está onde ----------------------------------------------------------------------

## Região onde está o personagem do jogador (null se ele não tiver um).
func region_of_player(player_id: int) -> Region:
	return Region.of(session.get_player_entity(player_id))


func players_in(region: Region) -> int:
	return region.player_ids().size()


## Host: o jogador sai da região onde está (viagem). O personagem some para todos e o cliente
## dele deixa de receber o que é de lá. Retorna a vida que ele tinha (0 = não tinha personagem).
func leave_region(player_id: int) -> int:
	var character := session.get_player_entity(player_id) as Character
	if character == null:
		return 0
	var region := Region.of(character)
	var health := maxi(character.health.current, 1)
	region.remove_player(player_id)
	_retire(character)
	if _is_remote(player_id):
		_update_gates(region, player_id)
	return health


## Host: o jogador entra na região, em `at`. Com `health`, vem de outra região (viagem) e
## mantém a vida; sem, está chegando no mundo (save ou equipamento inicial). O cliente dele já
## precisa ter sido avisado da região (o Main avisa antes).
func enter_region(player_id: int, region: Region, at: Vector2, health: int = 0) -> Character:
	region.add_player(player_id)
	var character: Character = _replicator(region).spawn({"kind": Kind.PLAYER,
		"entity_id": session.allocate_entity_id(), "player_id": player_id, "position": at})
	if health > 0:
		character.health.set_current(health)
	else:
		_prepare_player(character)
	if _is_remote(player_id):
		_update_gates(region, player_id)
	return character


## Jogador saiu da partida.
func despawn_player(player_id: int) -> void:
	var character := session.get_player_entity(player_id)
	if character:
		Region.of(character).remove_player(player_id)
		character.queue_free()


# --- Host: decide o que existe ---------------------------------------------------------------

func spawn_region_monsters(region: Region) -> void:
	for index in region.get_monster_spawn_points().size():
		spawn_monster(region, index)


func spawn_monster(region: Region, point_index: int) -> Monster:
	return _replicator(region).spawn({"kind": Kind.MONSTER,
		"entity_id": session.allocate_entity_id(), "point": point_index,
		"health_multiplier": CombatRules.monster_health_multiplier(
			maxi(players_in(region), 1), PLAYER_SCALING)})


## Filhote de um chefe (fase 2), em `at`. Não deixa drops nem renasce.
func spawn_minion(region: Region, summoner: Monster, at: Vector2) -> Monster:
	return _replicator(region).spawn({"kind": Kind.MINION,
		"entity_id": session.allocate_entity_id(), "summoner": summoner.entity_id, "position": at,
		"health_multiplier": summoner.max_health_multiplier})


## `from`: onde o item nasce (a criatura); `at`: onde ele pousa.
## `dropped_by_owner`: o próprio dono jogou fora (ele só pega de volta depois de se afastar).
func spawn_pickup(region: Region, item: ItemData, amount: int, owner_player_id: int,
		from: Vector2, at: Vector2, dropped_by_owner: bool = false) -> Pickup:
	var pickup_id := _next_pickup_id
	_next_pickup_id += 1
	return _replicator(region).spawn({"kind": Kind.PICKUP, "pickup_id": pickup_id,
		"item": String(item.id), "amount": amount, "owner": owner_player_id, "origin": from,
		"position": at, "dropped": dropped_by_owner})


## Estrutura colocada por um jogador (o lugar já foi conferido, ver PlacementRules).
func spawn_structure(region: Region, structure: StructureData, at: Vector2) -> Structure:
	var structure_id := _next_structure_id
	_next_structure_id += 1
	return _replicator(region).spawn({"kind": Kind.STRUCTURE, "structure_id": structure_id,
		"structure": String(structure.id), "position": at})


func _replicator(region: Region) -> MultiplayerSpawner:
	return region.get_node(REPLICATOR_NAME)


func _is_remote(player_id: int) -> bool:
	return NetRules.is_online(multiplayer) and player_id != multiplayer.get_unique_id()


## O personagem deixa de existir para todos (some nos clientes e sai da sessão), mas o nó fica
## um instante parado no host (ver RETIRE_TIME).
func _retire(character: Character) -> void:
	session.unregister_entity(character.entity_id)
	character.retire()
	var gate := character.get_node(GATE_NAME) as MultiplayerSynchronizer
	gate.public_visibility = false
	gate.update_visibility()
	get_tree().create_timer(RETIRE_TIME).timeout.connect(character.queue_free)


## Reavalia, para um cliente, o que ele recebe das entidades da região.
func _update_gates(region: Region, peer: int) -> void:
	for node in region.entities.get_children():
		var gate := node.get_node_or_null(GATE_NAME) as MultiplayerSynchronizer
		if gate:
			gate.update_visibility(peer)


# --- Todos os computadores: monta o nó a partir dos dados ------------------------------------

## Chamada pelo Replicator da região no host e em cada cliente. Nos clientes os dados vêm da
## rede: são conferidos antes do uso e nunca carregam caminhos, recursos ou objetos.
func _instantiate(data: Variant, region: Region) -> Node:
	var node: Node
	match _valid_kind(data, region):
		Kind.PLAYER:
			node = _instantiate_player(data)
		Kind.MONSTER:
			node = _instantiate_monster(data, region)
		Kind.MINION:
			node = _instantiate_minion(data, region)
		Kind.PICKUP:
			node = _instantiate_pickup(data)
		Kind.STRUCTURE:
			node = _instantiate_structure(data)
		_:
			push_warning("[spawner] dados de criação inválidos recebidos")
			var inert := Node.new()  # o Replicator exige um nó; este não faz nada
			inert.name = "Invalid"
			return inert
	_add_gate(node, region)
	return node


## Portão de visibilidade (mesmo nome nos dois lados; o filtro só existe no host). Sem
## propriedades para sincronizar: serve só para decidir a quem a entidade é enviada.
func _add_gate(node: Node, region: Region) -> void:
	var gate := MultiplayerSynchronizer.new()
	gate.name = GATE_NAME
	gate.replication_config = SceneReplicationConfig.new()
	gate.visibility_update_mode = MultiplayerSynchronizer.VISIBILITY_PROCESS_NONE
	if multiplayer.is_server():
		gate.add_visibility_filter(region.has_player)
		if node is Pickup:
			# Drop pessoal: só o computador do dono o recebe (nos outros ele ficaria escondido,
			# gastando rede e quadro; teste de carga H2). Os filtros se somam.
			var owner_id := (node as Pickup).owner_player_id
			gate.add_visibility_filter(func(peer: int) -> bool: return peer == owner_id)
	node.add_child(gate)


func _instantiate_player(data: Dictionary) -> Character:
	var character: Character = PLAYER_SCENE.instantiate()
	character.player_id = data["player_id"]
	character.position = data["position"]
	_register(character, data["entity_id"])
	session.add_player(character.player_id, character.entity_id, character.stats.inventory_slots)
	var gatherer: Gatherer = character.get_node("Gatherer")
	gatherer.session = session
	gatherer.items = items
	(character.get_node("StatusEffects") as StatusEffects).effects = session.get_effects(character.player_id)
	# Equipamento → atributos, golpe e aparência, em todos os computadores (cada um recebe o de
	# todos).
	var equipment := session.get_equipment(character.player_id)
	character.apply_equipment(equipment)
	equipment.slot_changed.connect(character.apply_equipment.bind(equipment).unbind(1))
	equipment.look_changed.connect(character.apply_equipment.bind(equipment).unbind(1))
	if _sized.get(character.player_id) != equipment:
		_sized[character.player_id] = equipment
		equipment.slot_changed.connect(_fit_inventory.bind(character.player_id).unbind(1))
	if not multiplayer.is_server():
		player_state.request_equipment_of(character.player_id)
	if character.player_id == local_player_id:
		character.add_to_group(OccluderFade.VIEWER_GROUP)
		character.ready.connect(local_player_spawned.emit.bind(character), CONNECT_ONE_SHOT)
	else:
		var visual: CharacterVisual = character.get_node("Visual")
		character.ready.connect(visual.set_tint.bind(OTHER_PLAYER_TINT), CONNECT_ONE_SHOT)
	if multiplayer.is_server():
		character.died.connect(_on_player_died)
		player_state.track_player(character.player_id)
		if abilities:
			abilities.track_player(character.player_id)
	return character


## Host, com o personagem já na árvore (vida pronta): quem já jogou neste mundo volta como
## estava; quem é novo ganha o equipamento inicial (e o kit de testes, se houver). Só depois disso
## uma aparência colecionada é novidade (avisa e vai para o dono).
func _prepare_player(character: Character) -> void:
	if not (saves and saves.restore_player(character)):
		var equipment := session.get_equipment(character.player_id)
		for item in character.stats.starting_equipment:
			EquipmentRules.give_equipped(equipment, item)
		if starter_kit:
			starter_kit.give_to(session.get_inventory(character.player_id))
	session.get_appearances(character.player_id).announces = true
	if character.player_id == local_player_id:
		local_player_prepared.emit()


## Tamanho do inventário = base do jogador + espaços das mochilas vestidas, somados direto do
## equipamento (não de `Character.bonuses`: a ordem das ligações muda quando o personagem é
## recriado numa viagem, e os bônus dele podiam ainda ser os do equipamento anterior).
func _fit_inventory(player_id: int) -> void:
	var character := session.get_player_entity(player_id) as Character
	var inventory := session.get_inventory(player_id)
	if character and inventory:
		var worn := StatBonuses.total(session.get_equipment(player_id).equipped())
		inventory.resize(character.stats.inventory_slots + worn.inventory_slots)


func _instantiate_monster(data: Dictionary, region: Region) -> Monster:
	var point := region.get_monster_spawn_points()[data["point"]]
	var monster: Monster = point.monster_scene.instantiate()
	monster.position = point.position
	monster.max_health_multiplier = data["health_multiplier"]
	_register(monster, data["entity_id"])
	monster.died.connect(_on_monster_died.bind(data["point"], weakref(region)))
	monster.phase_changed.connect(_on_boss_phase_changed.bind(monster))
	if multiplayer.is_server():
		(monster.get_node("Brain") as MonsterBrain).session = session  # IA só no host
		if monster.data.minion_scene:
			_track_minions(monster, region)
	return monster


## Host: chefe com filhotes. Na fase 2, cada queda solta filhotes; se ele desiste (volta para casa,
## imune) ou morre, os filhotes somem.
func _track_minions(boss: Monster, region: Region) -> void:
	var boss_ref: WeakRef = weakref(boss)
	var region_ref: WeakRef = weakref(region)
	(boss.get_node("SlamAttacker") as SlamAttacker).slam_landed.connect(
		func(landing: Vector2, _attack: SlamAttackData) -> void:
			_on_boss_landed(boss_ref.get_ref(), region_ref.get_ref(), landing))
	(boss.get_node("Health") as Health).immunity_changed.connect(func(immune: bool) -> void:
		if immune:
			_clear_minions(boss.entity_id))
	boss.tree_exiting.connect(_clear_minions.bind(boss.entity_id))


func _on_boss_landed(boss: Monster, region: Region, landing: Vector2) -> void:
	if boss == null or region == null or boss.phase != 2 or not boss.is_alive():
		return
	var alive: Array = _minions.get(boss.entity_id, []).filter(func(minion: Variant) -> bool:
		return is_instance_valid(minion) and minion.is_alive())
	var count := mini(boss.data.minions_per_slam, boss.data.max_minions - alive.size())
	var space := region.get_world_2d().direct_space_state
	for i in count:
		var spot := GroundQuery.find_drop_spot(space, landing, _rng, MINION_DISTANCE_MIN,
			MINION_DISTANCE_MAX, MINION_CLEARANCE)
		alive.append(spawn_minion(region, boss, spot))
	_minions[boss.entity_id] = alive


func _clear_minions(boss_entity_id: int) -> void:
	for minion: Variant in _minions.get(boss_entity_id, []):
		if is_instance_valid(minion) and not minion.is_queued_for_deletion():
			minion.queue_free()
	_minions.erase(boss_entity_id)


func _instantiate_minion(data: Dictionary, region: Region) -> Monster:
	var summoner := _summoner_of(data, region)
	var minion: Monster = summoner.data.minion_scene.instantiate()
	minion.position = data["position"]
	minion.max_health_multiplier = data["health_multiplier"]
	_register(minion, data["entity_id"])
	minion.died.connect(_on_minion_died)
	if multiplayer.is_server():
		var brain := minion.get_node("Brain") as MonsterBrain
		brain.session = session
		brain.leader = summoner  # segue o chefe e ataca o alvo dele
	return minion


## Chefe que invocou o filhote: entidade conhecida aqui, na mesma região, que tem filhotes.
func _summoner_of(data: Dictionary, region: Region) -> Monster:
	var summoner := session.get_entity(data["summoner"]) as Monster
	if summoner and Region.of(summoner) == region and summoner.data.minion_scene:
		return summoner
	return null


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
	health.healed.connect(_on_entity_healed.bind(entity))


## Tipo dos dados de criação, ou -1 se algum campo for inválido.
func _valid_kind(data: Variant, region: Region) -> int:
	if not data is Dictionary or not data.get("kind") is int:
		return -1
	var d: Dictionary = data
	match d["kind"]:
		Kind.PLAYER:
			if _is_id(d, "entity_id") and _is_id(d, "player_id") and _is_position(d, "position"):
				return Kind.PLAYER
		Kind.MONSTER:
			var multiplier: Variant = d.get("health_multiplier")
			if _is_id(d, "entity_id") and d.get("point") is int and d["point"] >= 0 \
					and d["point"] < region.get_monster_spawn_points().size() \
					and multiplier is float and is_finite(multiplier) \
					and multiplier > 0.0 and multiplier <= MAX_HEALTH_MULTIPLIER:
				return Kind.MONSTER
		Kind.MINION:
			var multiplier: Variant = d.get("health_multiplier")
			if _is_id(d, "entity_id") and _is_id(d, "summoner") and _is_position(d, "position") \
					and _summoner_of(d, region) != null and multiplier is float \
					and is_finite(multiplier) and multiplier > 0.0 \
					and multiplier <= MAX_HEALTH_MULTIPLIER:
				return Kind.MINION
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
	if _is_shown(entity):
		var color := DAMAGE_TO_PLAYER_COLOR if entity.player_id != 0 else DAMAGE_TO_MONSTER_COLOR
		if info.periodic:
			color = UiStyle.EFFECT_DAMAGE
		damage_numbers.show_number(entity.position, info.amount, color)


func _on_entity_healed(amount: int, entity: Character) -> void:
	if _is_shown(entity):
		damage_numbers.show_text(entity.position, Texts.format(&"COMBAT_HEALED", [amount]), HEAL_COLOR)


## Chefe se enfureceu (fase 2): aviso flutuante para quem está vendo a região.
func _on_boss_phase_changed(phase: int, boss: Monster) -> void:
	if phase == 2 and _is_shown(boss):
		damage_numbers.show_text(boss.position, Texts.format(&"BOSS_ENRAGED",
			[boss.data.get_display_name()]), UiStyle.ENRAGED, ENRAGED_TEXT_TIME)


func _on_entity_blocked(entity: Character) -> void:
	if _is_shown(entity):
		damage_numbers.show_text(entity.position, Texts.get_text(&"COMBAT_IMMUNE"), IMMUNE_COLOR)


## A entidade está na região que a janela mostra? (O host simula outras, sem mostrar.)
func _is_shown(entity: Node2D) -> bool:
	return entity.get_world_2d() == damage_numbers.get_viewport().world_2d


# --- Ciclo de vida -----------------------------------------------------------------------------

## O jogador local continua na sessão quando o personagem dele é recriado (viagem); os outros
## saem quando o personagem some daqui (saíram da partida ou da região).
func _on_entity_removed(entity: Character) -> void:
	session.unregister_entity(entity.entity_id)
	if entity.player_id != 0 and entity.player_id != local_player_id \
			and session.get_player_entity(entity.player_id) == null:
		session.remove_player(entity.player_id)


func _on_player_died(character: Character) -> void:
	get_tree().create_timer(PLAYER_RESPAWN_TIME).timeout.connect(
		_revive_player.bind(character.player_id))


## Por ID: o jogador pode ter saído da partida (ou da região) enquanto esperava renascer.
func _revive_player(player_id: int) -> void:
	var character := session.get_player_entity(player_id) as Character
	if character:
		character.revive(Region.of(character).get_spawn_position())


## Em todos os computadores a criatura morta sai do registro; no host, ela também deixa
## drops, some e agenda o renascimento (menos em dungeon).
func _on_monster_died(monster: Character, point_index: int, region_ref: WeakRef) -> void:
	session.unregister_entity(monster.entity_id)
	var region := region_ref.get_ref() as Region
	if not multiplayer.is_server() or region == null:
		return
	_spawn_drops(monster as Monster, region)
	get_tree().create_timer(CORPSE_TIME).timeout.connect(monster.queue_free)
	if region.is_temporary():  # dungeon: limpa fica limpa até ser esquecida
		return
	get_tree().create_timer(region.get_monster_spawn_points()[point_index].respawn_time) \
		.timeout.connect(_respawn_monster.bind(point_index, region_ref))


## Filhote morto: sai do registro e, no host, some (sem drops nem renascimento).
func _on_minion_died(minion: Character) -> void:
	session.unregister_entity(minion.entity_id)
	if multiplayer.is_server():
		get_tree().create_timer(CORPSE_TIME).timeout.connect(minion.queue_free)


## Drops pessoais: a tabela é sorteada separadamente para cada jogador da região. Cada item
## pousa num ponto andável e alcançável perto da criatura (nunca na água ou dentro de objetos).
func _spawn_drops(monster: Monster, region: Region) -> void:
	var space := region.get_world_2d().direct_space_state
	for player_id in region.player_ids():
		for entry in monster.data.drops:
			var amount := entry.roll(_rng)
			if amount > 0:
				var spot := GroundQuery.find_drop_spot(space, monster.position, _rng,
					DROP_DISTANCE_MIN, DROP_DISTANCE_MAX, DROP_CLEARANCE)
				spawn_pickup(region, entry.item, amount, player_id, monster.position, spot)


## Só se a região ainda estiver carregada (sem ninguém lá, ela é liberada e o renascimento
## agendado é esquecido).
func _respawn_monster(point_index: int, region_ref: WeakRef) -> void:
	var region := region_ref.get_ref() as Region
	if region and not region.is_queued_for_deletion():
		spawn_monster(region, point_index)
