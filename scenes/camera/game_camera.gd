class_name GameCamera
extends Camera2D
## Câmera que segue uma entidade. Fica na janela (o personagem mora no mundo da região, ver
## RegionWorlds) e copia a posição dele a cada passo de física, depois de ele se mover: com
## a interpolação de física ligada, câmera e personagem são desenhados entre os mesmos dois
## passos, sem tremores entre eles.
## Tremor (skill game-feel): só em impactos fortes perto do jogador local, em pixels inteiros,
## decaindo. É apresentação deste computador: nada passa pela rede.

## Quem pede um tremor chama `shake_near` no grupo (não precisa conhecer a câmera).
const GROUP := &"game_camera"

var _target: Node2D
var _shake_strength := 0.0
var _shake_time := 0.0
var _shake_left := 0.0


func _ready() -> void:
	process_physics_priority = 100  # depois dos personagens
	add_to_group(GROUP)


func follow(target: Node2D) -> void:
	_target = target
	global_position = target.global_position
	reset_physics_interpolation()


func set_bounds(rect: Rect2) -> void:
	limit_left = floori(rect.position.x)
	limit_top = floori(rect.position.y)
	limit_right = ceili(rect.end.x)
	limit_bottom = ceili(rect.end.y)


## Treme se o personagem seguido estiver no mundo `world` a até `reach` (chão) de `at`.
func shake_near(at: Vector2, world: World2D, reach: float, strength: float,
		duration: float) -> void:
	if not is_instance_valid(_target) or _target.get_world_2d() != world \
			or Iso.ground_distance(_target.global_position, at) > reach or duration <= 0.0:
		return
	_shake_strength = maxf(strength, _shake_strength if _shake_left > 0.0 else 0.0)
	_shake_time = duration
	_shake_left = duration


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var amount := _shake_strength * _shake_left / _shake_time
	offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount)).round()


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_target):
		global_position = _target.global_position
		force_update_scroll()  # a atualização interna da câmera já rodou neste passo
