class_name Region
extends Node2D
## Uma região do mundo (ADR-005/020): chão em TileMapLayer, entidades com Y-sort, ponto de
## entrada do jogador e passagens para outras regiões. Cada região é uma cena; o estado que
## persiste (estruturas, pontos de coleta) fica no save (SaveService).

## Um jogador entrou numa passagem desta região (quem decide a viagem é o Main).
signal passage_entered(player_id: int, passage: Passage)

@export var region_id: StringName
## Retângulo (em pixels de tela) totalmente coberto pelo chão; limita a câmera.
@export var camera_bounds: Rect2
## Luz ambiente (multiplica as cores do mundo; a interface não muda). Branco = sem mudança.
@export var ambient := Color.WHITE

@onready var ground: TileMapLayer = $Ground
@onready var entities: Node2D = $Entities
@onready var _player_spawn: Marker2D = $PlayerSpawn


func _ready() -> void:
	if ambient != Color.WHITE:
		var light := CanvasModulate.new()
		light.color = ambient
		add_child(light)
	for passage in get_passages():
		passage.entered_by.connect(passage_entered.emit)


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
