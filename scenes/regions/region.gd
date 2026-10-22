class_name Region
extends Node2D
## Uma região do mundo (ADR-005): chão em TileMapLayer, entidades com Y-sort e ponto de
## entrada do jogador. Cada região é uma cena; só uma fica carregada por vez.

@export var region_id: StringName
## Retângulo (em pixels de tela) totalmente coberto pelo chão; limita a câmera.
@export var camera_bounds: Rect2

@onready var ground: TileMapLayer = $Ground
@onready var entities: Node2D = $Entities
@onready var _player_spawn: Marker2D = $PlayerSpawn


func get_spawn_position() -> Vector2:
	return _player_spawn.position
