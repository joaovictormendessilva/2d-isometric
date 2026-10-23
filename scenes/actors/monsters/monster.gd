class_name Monster
extends Character
## Criatura: um Character configurado por um `MonsterData` (atributos, ataque, drops).
## O comportamento vem do MonsterBrain filho.
## Chefes com fase 2 (`phase_two_health`) se enfurecem abaixo daquela fração da vida: trocam o
## salto pelo da fase 2. A fase vem da vida, que todo computador conhece (o host decide).

## A fase mudou (1 = normal, 2 = enfurecido).
signal phase_changed(phase: int)

## Chefes vivos na árvore (barra de vida no alto da tela, BossBar).
const BOSS_GROUP := &"bosses"

@export var data: MonsterData

var phase := 1


func _ready() -> void:
	stats = data.stats
	if attacker:
		attacker.attack = data.attack
	if slammer:
		slammer.attack = data.slam
	if data.is_boss:
		add_to_group(BOSS_GROUP)
	super._ready()
	if data.phase_two_health > 0.0:
		health.changed.connect(_update_phase)


func _update_phase(current: int, maximum: int) -> void:
	var value := 2 if current <= maximum * data.phase_two_health else 1
	if value == phase:
		return
	phase = value
	if slammer:
		slammer.set_attack(data.phase_two_slam if value == 2 and data.phase_two_slam else data.slam)
	phase_changed.emit(value)
