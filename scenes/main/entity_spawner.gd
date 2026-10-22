class_name EntitySpawner
extends Node
## Cria e remove entidades na autoridade: atribui IDs e registra na sessão, liga a
## apresentação (números de dano) e cuida de morte, renascimento e drops pessoais.

const PLAYER_SCENE := preload("res://scenes/actors/character/player.tscn")
const PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")
const PLAYER_SCALING := preload("res://data/balance/player_scaling.tres")
const PLAYER_RESPAWN_TIME := 2.5
## Tempo que o corpo da criatura fica sumindo antes de ser removido.
const CORPSE_TIME := 0.6
const DROP_SCATTER := Vector2(8, 4)
const DAMAGE_TO_PLAYER_COLOR := Color("ff6b6b")
const DAMAGE_TO_MONSTER_COLOR := Color.WHITE
const IMMUNE_TEXT := "Imune"
const IMMUNE_COLOR := Color("a0a0b4")

var session: GameSession
var region: Region
var local_player_id := 0
var damage_numbers: DamageNumbers

var _rng := RandomNumberGenerator.new()


func setup(p_session: GameSession, p_region: Region, p_local_player_id: int,
		p_damage_numbers: DamageNumbers) -> void:
	session = p_session
	region = p_region
	local_player_id = p_local_player_id
	damage_numbers = p_damage_numbers
	_rng.randomize()


func spawn_player(player_id: int) -> Character:
	var character: Character = PLAYER_SCENE.instantiate()
	character.player_id = player_id
	character.position = region.get_spawn_position()
	if player_id == local_player_id:
		character.add_to_group(OccluderFade.VIEWER_GROUP)
	_add_entity(character)
	session.add_player(player_id, character.entity_id)
	character.died.connect(_on_player_died)
	return character


func spawn_region_monsters() -> void:
	for point in region.get_monster_spawn_points():
		spawn_monster(point)


func spawn_monster(point: MonsterSpawnPoint) -> Monster:
	var monster: Monster = point.monster_scene.instantiate()
	monster.position = point.position
	monster.max_health_multiplier = CombatRules.monster_health_multiplier(
		session.get_player_count(), PLAYER_SCALING)
	(monster.get_node("Brain") as MonsterBrain).session = session
	_add_entity(monster)
	monster.died.connect(_on_monster_died.bind(point))
	return monster


func spawn_pickup(item: ItemData, amount: int, owner_player_id: int, at: Vector2) -> Pickup:
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	pickup.item = item
	pickup.amount = amount
	pickup.owner_player_id = owner_player_id
	pickup.session = session
	pickup.position = at
	# Drop pessoal: cada máquina só mostra os itens do seu jogador local.
	pickup.visible = owner_player_id == local_player_id
	region.entities.add_child(pickup)
	return pickup


func _add_entity(entity: Character) -> void:
	entity.entity_id = session.allocate_entity_id()
	region.entities.add_child(entity)
	entity.reset_physics_interpolation()
	session.register_entity(entity.entity_id, entity)
	entity.health.damaged.connect(_on_entity_damaged.bind(entity))
	entity.health.blocked.connect(_on_entity_blocked.unbind(1).bind(entity))


func _on_entity_damaged(info: DamageInfo, entity: Character) -> void:
	var color := DAMAGE_TO_PLAYER_COLOR if entity.player_id != 0 else DAMAGE_TO_MONSTER_COLOR
	damage_numbers.show_number(entity.position, info.amount, color)


func _on_entity_blocked(entity: Character) -> void:
	damage_numbers.show_text(entity.position, IMMUNE_TEXT, IMMUNE_COLOR)


func _on_player_died(character: Character) -> void:
	get_tree().create_timer(PLAYER_RESPAWN_TIME).timeout.connect(
		character.revive.bind(region.get_spawn_position()))


func _on_monster_died(monster: Character, point: MonsterSpawnPoint) -> void:
	_spawn_drops(monster as Monster)
	session.unregister_entity(monster.entity_id)
	get_tree().create_timer(CORPSE_TIME).timeout.connect(monster.queue_free)
	get_tree().create_timer(point.respawn_time).timeout.connect(spawn_monster.bind(point))


## Drops pessoais: a tabela é sorteada separadamente para cada jogador da sessão.
func _spawn_drops(monster: Monster) -> void:
	for player_id in session.get_player_ids():
		for entry in monster.data.drops:
			var amount := entry.roll(_rng)
			if amount > 0:
				var scatter := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * DROP_SCATTER
				spawn_pickup(entry.item, amount, player_id, monster.position + scatter)
