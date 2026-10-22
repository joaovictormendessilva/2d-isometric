class_name StructureData
extends Resource
## Um tipo de estrutura que o jogador coloca no mundo (bancada; depois fornalha, baú...). Um
## arquivo por tipo em `data/structures/`; o item que a coloca é um `PlaceableData`.

@export var id: StringName
## Raio (no chão) da pegada: bloqueia a passagem e precisa de chão livre para ser colocada.
@export var footprint_radius: float = 8.0
## Que lugar de fabricação ela é (`HAND` = nenhum, ex.: um baú).
@export var station: RecipeData.Station = RecipeData.Station.HAND
## Distância (no chão) dos pés do jogador até a estrutura para usar as receitas dela.
@export var station_range: float = 40.0
@export_group("Aparência")
@export var texture: Texture2D
## Desenho em relação aos pés (posição da estrutura no chão).
@export var sprite_offset: Vector2


func is_station() -> bool:
	return station != RecipeData.Station.HAND
