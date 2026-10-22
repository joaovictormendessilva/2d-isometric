class_name Monster
extends Character
## Criatura: um Character configurado por um `MonsterData` (atributos, ataque, drops).
## O comportamento vem do MonsterBrain filho.

@export var data: MonsterData


func _ready() -> void:
	stats = data.stats
	if attacker:
		attacker.attack = data.attack
	super._ready()
