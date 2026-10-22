class_name GatheringSkillData
extends Resource
## Um tipo de coleta com nível próprio (Lenhador, Minerador...). O nível sobe coletando e
## deixa a coleta desse tipo mais rápida e mais rendosa. Valores em `data/skills/`.

@export var id: StringName
@export var display_name: String
@export var max_level: int = 50
@export_group("Experiência")
## Experiência para ir do nível N ao N+1: `base_xp * N ^ xp_growth`.
@export var base_xp: float = 20.0
@export var xp_growth: float = 1.5
@export_group("Bônus por nível acima do 1")
## Velocidade de coleta (0.03 = +3% por nível).
@export var speed_bonus_per_level: float = 0.03
## Chance de +1 no rendimento de cada coleta (0.02 = +2% por nível).
@export var bonus_yield_chance_per_level: float = 0.02


func xp_to_next(level: int) -> int:
	return roundi(base_xp * pow(level, xp_growth))


## Nível alcançado com `xp` de experiência total.
func level_for_xp(xp: int) -> int:
	var level := 1
	var needed := xp_to_next(level)
	while level < max_level and xp >= needed:
		xp -= needed
		level += 1
		needed = xp_to_next(level)
	return level


## Experiência total necessária para chegar ao início de `level`.
func xp_for_level(level: int) -> int:
	var total := 0
	for l in range(1, mini(level, max_level)):
		total += xp_to_next(l)
	return total
