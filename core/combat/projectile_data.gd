class_name ProjectileData
extends Resource
## Como um projétil voa e aparece: o da habilidade (orbe mágico) ou o da arma à distância
## (flecha do arco, orbe do cajado). Dano, recuo e efeitos vêm de quem o solta (AbilityData ou
## AttackData); aqui só o voo e a aparência.

enum Look { ORB, ARROW }

## Pixels por segundo no plano do chão.
@export var speed: float = 220.0
## Distância máxima (chão); depois some.
@export var max_range: float = 160.0
## Raio (chão) em que o projétil acerta uma pegada.
@export var hit_radius: float = 4.0

@export_group("Apresentação")
@export var look := Look.ORB
## Orbe: o miolo. Flecha: a haste.
@export var color := Color.WHITE
## Orbe: o brilho em volta do miolo. Flecha: ponta e penas. Também o rastro.
@export var glow_color := Color.WHITE
