class_name RegionData
extends Resource
## Uma região do mundo (ADR-005/020): id e a cena dela. Catálogo em `data/regions/`. Ids que
## chegam do save só servem para buscar aqui (nunca caminhos de arquivo).

@export var id: StringName
@export var scene: PackedScene
