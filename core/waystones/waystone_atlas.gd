class_name WaystoneAtlas
extends RefCounted
## Todas as pedras de portal do mundo, a partir do catálogo de regiões: de cada id, a pedra e a
## região onde ela fica (ADR-037). Ids que chegam do save ou da rede só servem para buscar aqui.

var _stones: Dictionary[StringName, WaystoneData] = {}
var _regions: Dictionary[StringName, StringName] = {}  # pedra -> região


func _init(regions: DataCatalog) -> void:
	for entry in regions.entries():
		var region := entry as RegionData
		for stone in region.waystones:
			_stones[stone.id] = stone
			_regions[stone.id] = region.id


func has(waystone_id: StringName) -> bool:
	return _stones.has(waystone_id)


func get_stone(waystone_id: StringName) -> WaystoneData:
	return _stones.get(waystone_id)


## Região da pedra (vazio se ela não existir).
func region_of(waystone_id: StringName) -> StringName:
	return _regions.get(waystone_id, &"")
