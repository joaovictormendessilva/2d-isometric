class_name GameCamera
extends Camera2D
## Câmera que segue uma entidade. Fica na janela (o personagem mora no mundo da região, ver
## RegionWorlds) e copia a posição dele a cada passo de física, depois de ele se mover: com
## a interpolação de física ligada, câmera e personagem são desenhados entre os mesmos dois
## passos, sem tremores entre eles.

var _target: Node2D


func _ready() -> void:
	process_physics_priority = 100  # depois dos personagens


func follow(target: Node2D) -> void:
	_target = target
	global_position = target.global_position
	reset_physics_interpolation()


func set_bounds(rect: Rect2) -> void:
	limit_left = floori(rect.position.x)
	limit_top = floori(rect.position.y)
	limit_right = ceili(rect.end.x)
	limit_bottom = ceili(rect.end.y)


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_target):
		global_position = _target.global_position
		force_update_scroll()  # a atualização interna da câmera já rodou neste passo
