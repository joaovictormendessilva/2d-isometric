class_name RewardChestData
extends Resource
## Baú de recompensa (ADR-032): surge numa dungeon quando o chefe dela morre. Cada jogador abre o
## seu uma vez, e a tabela é sorteada só para ele (como os drops pessoais). Um arquivo por baú em
## `data/chests/`; a dungeon diz qual é o dela (`RegionData.reward_chest`).

@export var id: StringName
## Distância (no chão) dos pés do jogador até o baú para abri-lo.
@export var interact_range: float = 28.0
## Raio (no chão) da pegada: bloqueia a passagem como uma pedra.
@export var footprint_radius: float = 7.0
@export_group("Aparência")
@export var closed_texture: Texture2D
@export var open_texture: Texture2D
@export_group("Recompensas")
@export var drops: Array[DropEntry] = []


## Desenho de `texture` com os pés (posição do baú) no meio da base.
static func sprite_offset(texture: Texture2D) -> Vector2:
	return Vector2(-floorf(texture.get_width() / 2.0), 1 - texture.get_height())
