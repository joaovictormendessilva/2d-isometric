class_name ExitPortal
extends Passage
## Saída rápida de uma dungeon (ADR-032): círculo mágico no chão que surge quando o chefe morre,
## junto com o baú. Entrar nele leva para fora, na entrada da dungeon (`exit_region`/
## `exit_passage` da região), como qualquer passagem. Criado pelo host via EntitySpawner.
## A origem do nó é a borda de cima do círculo (o desenho e o gatilho ficam abaixo dela): no
## Y-sort, quem pisa no círculo é desenhado por cima dele.

## Surge aos poucos e depois pulsa devagar (só apresentação).
const APPEAR_TIME := 0.6
const PULSE_TIME := 1.2
const PULSE_LOW_ALPHA := 0.7


func _ready() -> void:
	super()
	var sprite: Sprite2D = $Sprite
	sprite.modulate.a = 0.0
	var appear := create_tween()
	appear.tween_property(sprite, "modulate:a", 1.0, APPEAR_TIME)
	appear.tween_callback(_pulse.bind(sprite))


func _pulse(sprite: Sprite2D) -> void:
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(sprite, "modulate:a", PULSE_LOW_ALPHA, PULSE_TIME)
	pulse.tween_property(sprite, "modulate:a", 1.0, PULSE_TIME)
