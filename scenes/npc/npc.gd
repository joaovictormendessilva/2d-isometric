class_name Npc
extends StaticBody2D
## NPC fixo de uma região (mercador...): faz parte da cena da região, igual em todos os
## computadores, e bloqueia a passagem como uma pedra. Não tem estado de jogo: o que ele vende
## e compra está em `data` (NpcData) e quem decide as trocas é o host (PlayerStateSync).

const GROUP := &"npcs"

@export var data: NpcData


func _ready() -> void:
	var sprite: Sprite2D = $Sprite
	sprite.texture = data.texture
	sprite.offset = data.sprite_offset
	($Footprint as Footprint).radius = data.footprint_radius
	add_to_group(GROUP)


## Os pés em `at` estão perto o bastante para negociar?
func reaches(at: Vector2) -> bool:
	return Iso.ground_distance(position, at) <= data.interact_range
