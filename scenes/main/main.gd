extends Node
## Ponto de entrada: cria a sessão, carrega a região inicial e o personagem do jogador local.
## Single-player = host com 1 jogador (ADR-004).
##
## Argumentos de linha de comando (depois de `--`), usados pelo Claude para conferir telas:
##   --screenshot=<caminho.png>   salva uma captura após alguns quadros e fecha o jogo.
##   --move=<x>,<y>               segura essa intenção de movimento antes da captura.

const LOCAL_PLAYER_ID := 1
const START_REGION := preload("res://scenes/regions/meadow/meadow.tscn")
const CHARACTER_SCENE := preload("res://scenes/actors/character/character.tscn")
const SCREENSHOT_FRAMES := 45

var session := GameSession.new()
var region: Region

@onready var _world: Node2D = $World
@onready var _camera: GameCamera = $Camera
@onready var _local_input: LocalPlayerInput = $LocalInput
@onready var _debug_overlay: DebugOverlay = $UI/DebugOverlay


func _ready() -> void:
	region = START_REGION.instantiate()
	_world.add_child(region)

	var character := spawn_player_character(LOCAL_PLAYER_ID, region.get_spawn_position())
	_local_input.player_id = LOCAL_PLAYER_ID
	_local_input.target = character
	_camera.set_bounds(region.camera_bounds)
	_camera.follow(character)
	_debug_overlay.session = session
	_debug_overlay.player_id = LOCAL_PLAYER_ID

	_handle_command_line()


func spawn_player_character(player_id: int, at: Vector2) -> Character:
	var character: Character = CHARACTER_SCENE.instantiate()
	character.entity_id = session.allocate_entity_id()
	character.player_id = player_id
	character.position = at
	region.entities.add_child(character)
	character.reset_physics_interpolation()
	session.register_entity(character.entity_id, character)
	session.add_player(player_id, character.entity_id)
	return character


## Desliga teclado/controle do jogador local (testes e capturas dirigem o personagem
## diretamente por intenções).
func detach_local_input() -> void:
	_local_input.target = null


func _handle_command_line() -> void:
	var screenshot_path := ""
	var move := Vector2.ZERO
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--move="):
			var parts := arg.trim_prefix("--move=").split(",")
			move = Vector2(parts[0].to_float(), parts[1].to_float())
	if screenshot_path.is_empty():
		return
	var character := session.get_player_entity(LOCAL_PLAYER_ID) as Character
	if move != Vector2.ZERO:
		detach_local_input()
		character.set_move_intent(move)
	for i in SCREENSHOT_FRAMES:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("[main] screenshot: %s" % screenshot_path)
	get_tree().quit()
