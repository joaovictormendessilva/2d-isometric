class_name ProjectileData
extends Resource
## Como um projétil voa e aparece: o da habilidade (orbe mágico) ou o da arma à distância
## (flecha do arco, orbe do cajado). Dano, recuo e efeitos vêm de quem o solta (AbilityData ou
## AttackData); aqui só o voo e a aparência.

enum Look { ORB, ARROW }

## Pixels de TELA por segundo, iguais em todas as direções (quem mira vê a tela; ADR-033).
@export var speed: float = 220.0
## Distância máxima, em pixels de tela; depois some.
@export var max_range: float = 160.0
## Raio (chão) em que o projétil acerta uma pegada.
@export var hit_radius: float = 4.0
## Ao acertar, explode: fere todos os inimigos neste raio (chão; a pegada conta) em volta do
## impacto, não só quem foi tocado (orbe do cajado). 0 = só quem foi tocado.
@export var splash_radius: float = 0.0

@export_group("Apresentação")
@export var look := Look.ORB
## Orbe: o miolo. Flecha: a haste.
@export var color := Color.WHITE
## Orbe: o brilho em volta do miolo. Flecha: as penas. Também o rastro.
@export var glow_color := Color.WHITE
## Flecha: a ponta (diferente das penas, para se ver para onde ela aponta).
@export var tip_color := Color.WHITE
