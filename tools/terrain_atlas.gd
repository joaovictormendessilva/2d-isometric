## Definição única do atlas de terreno provisório, compartilhada pelos geradores de arte e de
## região. Para adicionar um tipo de tile, acrescente-o aqui (a coluna é a posição na lista).

const TEXTURE_PATH := "res://assets/tilesets/placeholder/terrain.png"
const TILESET_PATH := "res://assets/tilesets/placeholder/terrain_tileset.tres"
const SOURCE_ID := 0

const COLUMNS: Array[StringName] = [&"grass_0", &"grass_1", &"grass_2", &"dirt", &"water",
	&"cave_floor", &"chasm"]
const GRASS: Array[StringName] = [&"grass_0", &"grass_1", &"grass_2"]
## Tiles que bloqueiam passagem (ganham colisão no TileSet).
const BLOCKING: Array[StringName] = [&"water", &"chasm"]


static func coords(tile: StringName) -> Vector2i:
	var column := COLUMNS.find(tile)
	assert(column >= 0, "Tile desconhecido: %s" % tile)
	return Vector2i(column, 0)
