class_name ActorStats
extends Resource
## Atributos de um ator (jogador ou criatura). Os valores ficam em `data/`, não no código.
## Distâncias e velocidades em pixels no plano do chão (ver `Iso`).

@export_group("Movimento")
@export var move_speed: float = 90.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
## Multiplicador de velocidade ao andar na horizontal (ver `Iso.move_speed_factor`).
@export_range(0.5, 1.0) var horizontal_speed_factor: float = 1.0

@export_group("Combate")
@export var max_health: int = 100
## Reduz dano com retorno decrescente (ver `CombatRules.mitigate`).
@export var defense: int = 0
## Tempo sem receber dano depois de ser atingido.
@export var invulnerability_time: float = 0.0
## Tempo sem controle depois de ser atingido (recuo).
@export var hit_stun: float = 0.2
## 0 = sofre todo o recuo; 1 = imune a recuo.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0
