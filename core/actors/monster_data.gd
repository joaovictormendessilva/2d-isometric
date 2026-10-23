class_name MonsterData
extends Resource
## Definição de uma criatura: atributos, ataque, comportamento e drops. Um arquivo por
## criatura em `data/monsters/`.

@export var id: StringName
@export var stats: ActorStats
@export var attack: MeleeAttackData
## Ataque especial opcional: salto com queda em área (precisa do nó SlamAttacker na cena).
@export var slam: SlamAttackData
## Chefe: barra de vida no alto da tela para quem está por perto (F4).
@export var is_boss := false
@export_group("Comportamento (px no chão)")
## Distância em que percebe um jogador.
@export var aggro_radius: float = 110.0
## Distância máxima de casa antes de desistir e voltar.
@export var leash_radius: float = 220.0
@export_group("Recompensas")
@export var drops: Array[DropEntry] = []


## Nome no idioma atual (chave `MONSTER_<ID>` em `data/i18n/texts.csv`).
func get_display_name() -> String:
	return Texts.name_of("MONSTER", id)
