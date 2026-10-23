class_name Monster
extends Character
## Criatura: um Character configurado por um `MonsterData` (atributos, ataque, drops).
## O comportamento vem do MonsterBrain filho.

## Chefes vivos na árvore (barra de vida no alto da tela, BossBar).
const BOSS_GROUP := &"bosses"

@export var data: MonsterData


func _ready() -> void:
	stats = data.stats
	if attacker:
		attacker.attack = data.attack
	if slammer:
		slammer.attack = data.slam
	if data.is_boss:
		add_to_group(BOSS_GROUP)
	super._ready()
