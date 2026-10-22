class_name GameCamera
extends Camera2D
## Câmera que segue uma entidade. Vira filha do alvo para herdar a posição já interpolada
## (physics interpolation), evitando tremores entre câmera e personagem.


func follow(target: Node2D) -> void:
	reparent(target, false)
	position = Vector2.ZERO
	reset_physics_interpolation()


func set_bounds(rect: Rect2) -> void:
	limit_left = floori(rect.position.x)
	limit_top = floori(rect.position.y)
	limit_right = ceili(rect.end.x)
	limit_bottom = ceili(rect.end.y)
