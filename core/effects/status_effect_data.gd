class_name StatusEffectData
extends Resource
## Um efeito com duração num ator (buff ou debuff): bônus de atributos enquanto dura e/ou dano ou
## cura a cada "tick". Um arquivo por efeito em `data/effects/` (ADR-025). Quem aplica (golpe,
## poção, habilidade) só aponta para o efeito; as regras ficam em `ActiveEffects`.

@export var id: StringName
## Segundos. Reaplicar um efeito ativo renova o tempo cheio (não soma, não empilha).
@export var duration: float = 5.0
## Debuff (veneno, lentidão...): a apresentação mostra em vermelho; buffs em verde.
@export var harmful := false
## Somados aos do equipamento enquanto o efeito dura (podem ser negativos: lentidão = -30%).
@export var bonuses: StatBonuses

@export_group("A cada tick")
@export var tick_interval: float = 1.0
## Dano por tick. Ignora defesa e não atordoa nem dá invulnerabilidade (ver DamageInfo.periodic).
@export var damage_per_tick: int = 0
@export var heal_per_tick: int = 0

@export_group("Apresentação")
## Ícone 8x8 (desenhado em escala 2 no HUD).
@export var icon: Texture2D
## Partículas no ator enquanto o efeito dura (0 = nenhuma; teto em StatusEffectVfx).
@export var vfx_amount: int = 0
@export var vfx_color := Color.WHITE
## Pixels por segundo para cima (bolhas de veneno sobem devagar).
@export var vfx_rise_speed: float = 12.0
## Nos pés (rapidez) em vez de no corpo todo.
@export var vfx_at_feet := false


func get_display_name() -> String:
	return Texts.name_of("EFFECT", id)


func has_ticks() -> bool:
	return tick_interval > 0.0 and (damage_per_tick > 0 or heal_per_tick > 0)
