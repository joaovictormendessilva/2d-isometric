class_name LocalPlayerInput
extends Node
## Lê teclado/mouse/controle do jogador LOCAL e entrega INTENÇÕES ao personagem dele.
## Movimento: direções da tela viram direções no plano do chão (cima na tela = "norte"),
## então as diagonais andam alinhadas às bordas dos tiles.
## Interagir (E / botão A): falar com o NPC ao alcance (abre a loja; ver Main) ou, sem NPC,
## coletar o ponto de coleta mais próximo.
## Poção (Q / LB): bebe a primeira poção de vida do inventário (o host confere).
## Habilidades (1–4 / RB, B, direcional): lança a do espaço, com a mesma mira do ataque.
## Ataque: segurar repete o golpe; um clique que começou na interface não ataca. Mira no
## mouse se o último dispositivo de mira foi o mouse; com o controle, na direção em que o
## personagem olha. Teclas não mudam a mira: teclado e mouse se usam juntos (andar com WASD e
## apertar 1 continua mirando no ponteiro).
## No coop, o personagem local age na hora e o NetSync pede ao host (ADR-012).

## Interagiu com um NPC ao alcance (quem abre a loja é o Main).
signal talk_requested(npc: Npc)

## Grupo de nós da interface que podem estar usando o mouse (método `captures_mouse()`),
## ex.: janela sendo arrastada, item na mão. Enquanto usam, o clique não é ataque.
const MOUSE_CAPTURE_GROUP := &"mouse_capture"
## Movimento mínimo do analógico para considerar o controle como dispositivo ativo.
const JOYPAD_ACTIVITY := 0.5
## Ação de entrada de cada espaço de habilidade (project.godot).
const ABILITY_ACTIONS: Array[StringName] = [&"ability_1", &"ability_2", &"ability_3", &"ability_4"]

var player_id := 0
var target: Character
## Diz qual NPC está ao alcance do jogador (sem ela, a interação só coleta).
var player_state: PlayerStateSync
## Lança as habilidades das teclas 1–4 (sem ela, as teclas não fazem nada).
var abilities: AbilitySync

var _aim_with_mouse := false
## O clique de mouse atual começou com o ponteiro livre? (Um clique que começou na interface
## não vira ataque, nem se o ponteiro sair dela com o botão ainda apertado.)
var _mouse_press_is_free := false


func _ready() -> void:
	# Roda antes da física dos personagens, para a intenção valer no mesmo quadro.
	process_physics_priority = -10


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_aim_with_mouse = true
	elif event is InputEventJoypadButton:
		_aim_with_mouse = false
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > JOYPAD_ACTIVITY:
		_aim_with_mouse = false
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_mouse_press_is_free = not _mouse_is_busy()


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	target.set_move_intent(Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"))
	if Input.is_action_just_pressed(&"interact"):
		var npc := player_state.npc_near(player_id) if player_state else null
		if npc:
			talk_requested.emit(npc)
		else:
			target.request_gather()
	if Input.is_action_just_pressed(&"use_potion") and player_state:
		player_state.request_quick_heal()
	if abilities:
		for index in AbilityBook.SLOTS:
			if Input.is_action_just_pressed(ABILITY_ACTIONS[index]):
				abilities.request_cast(player_id, index, _aim_direction())
	var mouse_attack := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if Input.is_action_pressed(&"attack") and (not mouse_attack or _mouse_press_is_free):
		target.request_attack(_aim_direction())


## Ponteiro sobre a interface, ou a interface usando o mouse (arrastando janela, item na mão).
func _mouse_is_busy() -> bool:
	if get_viewport().gui_get_hovered_control() != null:
		return true
	return get_tree().get_nodes_in_group(MOUSE_CAPTURE_GROUP).any(
		func(node: Node) -> bool: return node.captures_mouse())


func _aim_direction() -> Vector2:
	if _aim_with_mouse:
		var to_mouse := Iso.screen_to_ground(_mouse_in_world() - target.global_position)
		if not to_mouse.is_zero_approx():
			return to_mouse
	return target.facing


## Ponteiro em coordenadas do mundo, pela janela (o personagem mora no mundo da região, que
## não recebe o mouse; ver RegionWorlds).
func _mouse_in_world() -> Vector2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
