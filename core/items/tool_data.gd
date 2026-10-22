class_name ToolData
extends ItemData
## Ferramenta de coleta (machado, picareta...). Enquanto não há equipamentos (Etapa E4), a
## melhor ferramenta do tipo certo no inventário é usada automaticamente.

## Tipo de coleta em que a ferramenta serve.
@export var skill: GatheringSkillData
## Nível da ferramenta: libera pontos de coleta que exigem esse nível ou menos.
@export var tier: int = 1
## Multiplica a velocidade de coleta (as mãos valem `GatheringBalance.hands_speed`).
@export var speed: float = 1.0
