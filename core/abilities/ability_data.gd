class_name AbilityData
extends Resource
## Uma habilidade que o jogador aprende e põe numa tecla (ADR-026). Um arquivo por habilidade em
## `data/abilities/`. Hoje só projéteis (mira no cursor, acerta o primeiro inimigo no caminho);
## habilidades em área entram com o mesmo formato. Sem mana: só tempo de recarga.

@export var id: StringName
@export var icon: Texture2D
## Segundos até poder lançar de novo (conta a partir do lançamento).
@export var cooldown: float = 3.0
## Preparação antes de sair (antecipação; o jogador anda mais devagar). Apanhar não interrompe.
@export var cast_time: float = 0.15
@export_range(0.0, 1.0) var cast_move_multiplier: float = 0.5

@export_group("Projétil")
@export var damage: int = 10
@export var knockback: float = 60.0
## Pixels por segundo no plano do chão.
@export var speed: float = 220.0
## Distância máxima (chão); depois some.
@export var max_range: float = 160.0
## Raio (chão) em que o projétil acerta uma pegada.
@export var hit_radius: float = 4.0
## Efeitos aplicados em quem é acertado (ex.: queimadura), como os golpes das criaturas.
@export var hit_effects: Array[StatusEffectData] = []

@export_group("Apresentação")
@export var vfx_color := Color.WHITE
## Cor do brilho em volta do miolo.
@export var vfx_glow_color := Color.WHITE


## Nome no idioma atual (chave `ABILITY_<ID>` em `data/i18n/texts.csv`).
func get_display_name() -> String:
	return Texts.name_of("ABILITY", id)
