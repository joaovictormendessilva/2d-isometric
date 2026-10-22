class_name MonsterSpawnPoint
extends Marker2D
## Ponto onde uma criatura nasce e renasce depois de morta (filhos de `MonsterSpawns`).

@export var monster_scene: PackedScene
@export var respawn_time: float = 20.0
