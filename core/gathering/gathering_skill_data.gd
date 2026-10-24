class_name GatheringSkillData
extends SkillData
## Um tipo de coleta com nível próprio (Lenhador, Minerador...). O nível sobe coletando e
## deixa a coleta desse tipo mais rápida e mais rendosa. Valores em `data/skills/`.

@export_group("Bônus por nível acima do 1")
## Velocidade de coleta (0.03 = +3% por nível).
@export var speed_bonus_per_level: float = 0.03
## Chance de +1 no rendimento de cada coleta (0.02 = +2% por nível).
@export var bonus_yield_chance_per_level: float = 0.02
