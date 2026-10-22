class_name MonsterData
extends Resource
## Definição de uma criatura: atributos, ataque, comportamento e drops. Um arquivo por
## criatura em `data/monsters/`.

@export var id: StringName
@export var display_name: String
@export var stats: ActorStats
@export var attack: MeleeAttackData
@export_group("Comportamento (px no chão)")
## Distância em que percebe um jogador.
@export var aggro_radius: float = 110.0
## Distância máxima de casa antes de desistir e voltar.
@export var leash_radius: float = 220.0
@export_group("Recompensas")
@export var drops: Array[DropEntry] = []
