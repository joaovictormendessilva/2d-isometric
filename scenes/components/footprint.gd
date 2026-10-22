@tool
class_name Footprint
extends CollisionPolygon2D
## "Pegada" de colisão de qualquer entidade: um círculo no plano do chão, que na tela vira uma
## elipse 2:1 (ver `Iso`). Assim, todas as colisões são justas em qualquer direção.
## Use em personagens, monstros e objetos; ajuste só o raio.

const SEGMENTS := 12

## Raio no plano do chão, em pixels.
@export var radius: float = 5.0:
	set(value):
		radius = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var points := PackedVector2Array()
	for i in SEGMENTS:
		var angle := TAU * i / SEGMENTS
		points.append(Iso.ground_to_screen(Vector2.from_angle(angle) * radius))
	polygon = points
