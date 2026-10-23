class_name Region
extends Node2D
## Uma região do mundo (ADR-005/020): chão em TileMapLayer, entidades com Y-sort, ponto de
## entrada do jogador e passagens para outras regiões. Cada região é uma cena; o estado que
## persiste (estruturas, pontos de coleta) fica no save (SaveService).

## Um jogador entrou numa passagem desta região (quem decide a viagem é o Main).
signal passage_entered(player_id: int, passage: Passage)
## Host: um jogador saiu da região (viagem ou saída da partida); quem manda mensagens ao
## computador dele sobre nós daqui para de mandar (HostBroadcast).
signal player_exited(player_id: int)

@export var region_id: StringName
## Retângulo (em pixels de tela) totalmente coberto pelo chão; limita a câmera.
@export var camera_bounds: Rect2
## Luz ambiente (multiplica as cores do mundo; a interface não muda). Branco = sem mudança.
@export var ambient := Color.WHITE

## Efeitos desenhados no chão, por baixo de tudo que está em `entities` (aviso do salto do chefe).
## Só apresentação: criada aqui em cada computador, nunca replicada.
var ground_effects := Node2D.new()
var _players: Dictionary[int, bool] = {}

@onready var ground: TileMapLayer = $Ground
@onready var entities: Node2D = $Entities
@onready var _player_spawn: Marker2D = $PlayerSpawn


func _ready() -> void:
	ground_effects.name = "GroundEffects"
	add_child(ground_effects)
	move_child(ground_effects, entities.get_index())
	if ambient != Color.WHITE:
		var light := CanvasModulate.new()
		light.color = ambient
		add_child(light)
	for passage in get_passages():
		passage.entered_by.connect(passage_entered.emit)


## Host: jogadores nesta região agora (no coop, cada um pode estar numa). É o que decide o que
## cada cliente recebe: só o que acontece na região dele (ids de jogador = ids de computador).
func add_player(player_id: int) -> void:
	_players[player_id] = true


func remove_player(player_id: int) -> void:
	if _players.erase(player_id):
		player_exited.emit(player_id)


func has_player(player_id: int) -> bool:
	return _players.has(player_id)


func player_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_players.keys())
	return ids


func get_spawn_position() -> Vector2:
	return _player_spawn.position


func get_monster_spawn_points() -> Array[MonsterSpawnPoint]:
	var points: Array[MonsterSpawnPoint] = []
	var container := get_node_or_null("MonsterSpawns")
	if container:
		points.assign(container.get_children())
	return points


func get_passages() -> Array[Passage]:
	var passages: Array[Passage] = []
	var container := get_node_or_null("Passages")
	if container:
		passages.assign(container.get_children())
	return passages


## Passagem pelo id (null se não existir).
func get_passage(passage_id: StringName) -> Passage:
	for passage in get_passages():
		if passage.passage_id == passage_id:
			return passage
	return null


## Região onde o nó está (null se estiver fora de uma).
static func of(node: Node) -> Region:
	while node and node is not Region:
		node = node.get_parent()
	return node as Region
