class_name ActorStats
extends Resource
## Parâmetros de movimento de um ator. Os valores ficam em `data/actors/*.tres`, não no código.
## Velocidades em pixels por segundo no plano do chão (ver `Iso`).

@export var move_speed: float = 90.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
## Multiplicador de velocidade ao andar na horizontal (ver `Iso.move_speed_factor`).
@export_range(0.5, 1.0) var horizontal_speed_factor: float = 1.0
