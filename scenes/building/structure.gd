class_name Structure
extends StaticBody2D
## Estrutura colocada por um jogador (bancada...). Criada pelo host via EntitySpawner, igual
## em todos os computadores; bloqueia a passagem como uma pedra. Se for estação de fabricação,
## libera as receitas dela para quem estiver perto (PlayerStateSync.stations_of).

const STATION_GROUP := &"crafting_stations"

var data: StructureData


func _ready() -> void:
	var sprite: Sprite2D = $Sprite
	sprite.texture = data.texture
	sprite.offset = data.sprite_offset
	($Footprint as Footprint).radius = data.footprint_radius
	if data.is_station():
		add_to_group(STATION_GROUP)


## Os pés em `at` estão perto o bastante para usar esta estação?
func reaches(at: Vector2) -> bool:
	return Iso.ground_distance(position, at) <= data.station_range
