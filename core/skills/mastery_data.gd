class_name MasteryData
extends SkillData
## Maestria de combate (estilo Albion, ADR-038): um tipo de arma ou de magia com nível próprio,
## que sobe ferindo inimigos com ela e aumenta o dano dela. Sem classe nem nível geral: trocar de
## arma é treinar outra trilha. Golpes (`AttackData.mastery`) e habilidades
## (`AbilityData.mastery`) dizem qual maestria treinam. Valores em `data/skills/`.

## Experiência por ponto de dano causado de fato.
@export var xp_per_damage: float = 1.0
@export_group("Bônus por nível acima do 1")
## Dano dos golpes desta maestria (0.03 = +3% por nível).
@export var damage_bonus_per_level: float = 0.03


## Multiplicador do dano no nível `level` (1,0 no nível 1).
func damage_multiplier(level: int) -> float:
	return 1.0 + damage_bonus_per_level * (clampi(level, 1, max_level) - 1)


## Dano de um golpe de `base` no nível `level` (arredondado; nunca abaixo do base).
func scaled_damage(base: int, level: int) -> int:
	return maxi(roundi(base * damage_multiplier(level)), base)


## Bônus de dano em pontos percentuais (para mostrar ao jogador).
func damage_bonus_percent(level: int) -> int:
	return roundi((damage_multiplier(level) - 1.0) * 100.0)


func xp_for_damage(damage: int) -> int:
	return maxi(roundi(damage * xp_per_damage), 0)
