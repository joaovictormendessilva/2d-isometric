class_name ConsumableData
extends ItemData
## Item que se usa e se gasta (uma unidade por uso), ex.: poção de vida. Usar é pelo menu do
## botão direito do inventário ou, para curar, pela tecla de poção (ver ConsumableRules).

## Vida devolvida na hora (0 = não cura).
@export var heal: int = 0
## Efeitos aplicados em quem usa (ex.: rapidez). Reusar renova o tempo (ADR-025).
@export var effects: Array[StatusEffectData] = []
## Tomo: ensina esta habilidade a quem lê (ADR-026). Quem já conhece não gasta o tomo.
@export var teaches_ability: AbilityData
## Espera depois de usar, em segundos. Vale para todos os itens do mesmo `cooldown_group`
## (beber uma poção não deixa beber outra logo em seguida).
@export var cooldown: float = 0.0
@export var cooldown_group: StringName = &"potion"
