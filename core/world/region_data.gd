class_name RegionData
extends Resource
## Uma região do mundo (ADR-005/020): id e a cena dela. Catálogo em `data/regions/`. Ids que
## chegam do save só servem para buscar aqui (nunca caminhos de arquivo).

@export var id: StringName
@export var scene: PackedScene
## Dungeon (ADR-031): nunca vai para o save e começa do zero a cada vez que é carregada (quando
## fica vazia, é liberada e esquecida); criaturas não renascem e não se constrói nela.
@export var temporary := false
## Dungeon: onde volta quem saiu do jogo lá dentro (região e passagem de chegada, a entrada).
@export var exit_region: StringName
@export var exit_passage: StringName
