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
@export_group("Fase 2 (chefes)")
## Fração da vida em que o chefe se enfurece (fase 2); 0 = sem fase 2. Volta à fase 1 se curar.
@export_range(0.0, 1.0) var phase_two_health: float = 0.0
## Salto da fase 2 (mais rápido). Sem ele, o mesmo da fase 1.
@export var phase_two_slam: SlamAttackData
## Fase 2: filhotes que surgem em volta de cada queda. Não deixam drops e somem quando o chefe
## morre ou desiste (volta para casa).
@export var minion_scene: PackedScene
@export var minions_per_slam: int = 2
## Máximo de filhotes vivos ao mesmo tempo.
@export var max_minions: int = 4
@export_group("Recompensas")
@export var drops: Array[DropEntry] = []


## Nome no idioma atual (chave `MONSTER_<ID>` em `data/i18n/texts.csv`).
func get_display_name() -> String:
	return Texts.name_of("MONSTER", id)
