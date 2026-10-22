class_name LocalPlayerInput
extends Node
## Lê teclado/mouse/controle do jogador LOCAL e entrega INTENÇÕES ao personagem dele.
## Movimento: direções da tela viram direções no plano do chão (cima na tela = "norte"),
## então as diagonais andam alinhadas às bordas dos tiles.
## Interagir (E / botão A): coletar o ponto de coleta mais próximo.
## Ataque: segurar repete o golpe. Mira no mouse se ele foi o último dispositivo usado;
## senão, na direção em que o personagem olha (teclado/controle).
## No coop, o personagem local age na hora e o NetSync pede ao host (ADR-012).

## Movimento mínimo do analógico para considerar o controle como dispositivo ativo.
const JOYPAD_ACTIVITY := 0.5

var player_id := 0
var target: Character

var _aim_with_mouse := false


func _ready() -> void:
	# Roda antes da física dos personagens, para a intenção valer no mesmo quadro.
	process_physics_priority = -10


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_aim_with_mouse = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_aim_with_mouse = false
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > JOYPAD_ACTIVITY:
		_aim_with_mouse = false


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	target.set_move_intent(Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"))
	if Input.is_action_just_pressed(&"interact"):
		target.request_gather()
	if Input.is_action_pressed(&"attack") and not _pointer_over_ui():
		target.request_attack(_aim_direction())


## Clique sobre a interface (ex.: tela de inventário) não é ataque.
func _pointer_over_ui() -> bool:
	return _aim_with_mouse and get_viewport().gui_get_hovered_control() != null


func _aim_direction() -> Vector2:
	if _aim_with_mouse:
		var to_mouse := Iso.screen_to_ground(target.get_global_mouse_position() - target.global_position)
		if not to_mouse.is_zero_approx():
			return to_mouse
	return target.facing
