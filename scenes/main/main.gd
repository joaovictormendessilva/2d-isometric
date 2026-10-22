extends Node
## Ponto de entrada: cria a sessão, carrega a região inicial, o jogador local e as criaturas.
## Single-player = host com 1 jogador (ADR-004).
##
## Argumentos de linha de comando (depois de `--`), usados pelo Claude para conferir telas:
##   --screenshot=<caminho.png>   salva uma captura após alguns quadros e fecha o jogo.
##   --move=<x>,<y>               segura essa intenção de movimento antes da captura.

const LOCAL_PLAYER_ID := 1
const START_REGION := preload("res://scenes/regions/meadow/meadow.tscn")
const SCREENSHOT_FRAMES := 45

var session := GameSession.new()
var region: Region
var items := ItemDatabase.load_all()

@onready var _world: Node2D = $World
@onready var _camera: GameCamera = $Camera
@onready var _local_input: LocalPlayerInput = $LocalInput
@onready var _spawner: EntitySpawner = $EntitySpawner
@onready var _damage_numbers: DamageNumbers = $World/DamageNumbers
@onready var _hud: Hud = $UI/Hud
@onready var _debug_overlay: DebugOverlay = $UI/DebugOverlay


func _ready() -> void:
	region = START_REGION.instantiate()
	_world.add_child(region)
	_spawner.setup(session, region, LOCAL_PLAYER_ID, _damage_numbers)

	var character := _spawner.spawn_player(LOCAL_PLAYER_ID)
	_spawner.spawn_region_monsters()

	_local_input.player_id = LOCAL_PLAYER_ID
	_local_input.target = character
	_camera.set_bounds(region.camera_bounds)
	_camera.follow(character)
	_hud.setup(character, session.get_inventory(LOCAL_PLAYER_ID), items)
	_debug_overlay.session = session
	_debug_overlay.player_id = LOCAL_PLAYER_ID

	_handle_command_line()


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
