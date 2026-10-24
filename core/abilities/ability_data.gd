class_name AbilityData
extends Resource
## Uma habilidade que o jogador aprende e põe numa tecla (ADR-026). Um arquivo por habilidade em
## `data/abilities/`. Sem mana: só tempo de recarga. Mira no cursor: o projétil sai na direção
## dele; a área cai no ponto dele (até o alcance), com aviso no chão antes do impacto.

enum Shape { PROJECTILE, AREA }

@export var id: StringName
@export var icon: Texture2D
@export var shape := Shape.PROJECTILE
## Segundos até poder lançar de novo (conta a partir do lançamento).
@export var cooldown: float = 3.0
## Preparação antes de sair (antecipação; o jogador anda mais devagar). Apanhar não interrompe.
@export var cast_time: float = 0.15
@export_range(0.0, 1.0) var cast_move_multiplier: float = 0.5

@export_group("Golpe")
@export var damage: int = 10
@export var knockback: float = 60.0
## Área: até onde o ponto de queda alcança (o projétil tem o próprio alcance).
@export var max_range: float = 160.0
## Efeitos aplicados em quem é acertado (ex.: queimadura), como os golpes das criaturas.
@export var hit_effects: Array[StatusEffectData] = []

@export_group("Projétil")
## Voo e aparência do projétil (forma PROJECTILE).
@export var projectile: ProjectileData

@export_group("Área")
## Raio (chão) do impacto; a pegada do alvo conta.
@export var area_radius: float = 24.0
## Aviso no chão: segundos entre soltar a habilidade e o impacto.
@export var area_delay: float = 0.6

@export_group("Apresentação")
## Cores da área (o projétil tem as próprias).
@export var vfx_color := Color.WHITE
## Borda do aviso no chão e brilho do impacto da área.
@export var vfx_glow_color := Color.WHITE


## Nome no idioma atual (chave `ABILITY_<ID>` em `data/i18n/texts.csv`).
func get_display_name() -> String:
	return Texts.name_of("ABILITY", id)


## Onde a área cai, a partir de quem lança, para a mira `aim` (plano do chão): no ponto mirado,
## até o alcance.
func area_offset(aim: Vector2) -> Vector2:
	return aim.limit_length(max_range)
