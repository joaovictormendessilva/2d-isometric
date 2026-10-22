class_name GatheringBalance
extends Resource
## Números gerais da coleta (`data/balance/gathering.tres`).

## Sem ferramenta, as mãos coletam só pontos que não exigem ferramenta, nesta velocidade.
@export var hands_speed: float = 0.5
## Folga máxima (plano do chão) entre a pegada do jogador e a do ponto de coleta.
@export var gather_range: float = 10.0
