extends Node
## Ponto de entrada: cria a sessão, a rede (ver Network), a região inicial, o jogador local e
## as criaturas. Single-player = host com 1 jogador (ADR-004); no coop, só o host cria as
## entidades e os clientes as recebem (ADR-012).
##
## Argumentos de linha de comando (depois de `--`):
##   rede: ver `scenes/net/network.gd` (--host, --host-lan, --join=<ip>, --port=<n>).
##   --screenshot=<caminho.png>   salva uma captura após alguns quadros e fecha o jogo.
##   --move=<x>,<y>               segura essa intenção de movimento antes da captura.

const START_REGION := preload("res://scenes/regions/meadow/meadow.tscn")
const SKILLS_DIR := "res://data/skills/"
const SCREENSHOT_FRAMES := 45

## Defina antes de adicionar à árvore para ignorar a linha de comando (testes de rede).
var configure_network_from_command_line := true

var session := GameSession.new()
var region: Region
var items := ItemDatabase.load_all()
var skills := DataCatalog.new(SKILLS_DIR)

var _input_detached := false

@onready var network: Network = $Network
@onready var _world: Node2D = $World
@onready var _camera: GameCamera = $Camera
@onready var _local_input: LocalPlayerInput = $LocalInput
@onready var _spawner: EntitySpawner = $EntitySpawner
@onready var _damage_numbers: DamageNumbers = $World/DamageNumbers
@onready var _hud: Hud = $UI/Hud
@onready var _net_status: NetStatus = $UI/NetStatus
@onready var _debug_overlay: DebugOverlay = $UI/DebugOverlay
@onready var _player_feedback: PlayerFeedback = $PlayerFeedback


func _ready() -> void:
	# A rede começa ANTES da região: os objetos da região (pontos de coleta) decidem no
	# próprio `_ready` se pedem o estado ao host.
	network.session = session
	network.items = items
	network.skills = skills
	if configure_network_from_command_line:
		network.configure_from_command_line(OS.get_cmdline_user_args())
	network.start()
	_net_status.network = network

	region = START_REGION.instantiate()
	_world.add_child(region)
	_camera.set_bounds(region.camera_bounds)

	_spawner.setup(session, region, local_player_id(), _damage_numbers, items, network)
	_spawner.local_player_spawned.connect(_on_local_player_spawned)
	_debug_overlay.session = session
	_debug_overlay.player_id = local_player_id()
	if multiplayer.is_server():
		_spawner.spawn_player(local_player_id())
		_spawner.spawn_region_monsters()
		network.player_joined.connect(_spawner.spawn_player)
		network.player_left.connect(_spawner.despawn_player)

	_handle_command_line()


func local_player_id() -> int:
	return network.local_player_id()


## O personagem do jogador local chegou (no host, na hora; no cliente, quando o host o cria).
func _on_local_player_spawned(character: Character) -> void:
	_local_input.player_id = local_player_id()
	if _local_input.target == null and not _input_detached:
		_local_input.target = character
	_camera.follow(character)
	var inventory := session.get_inventory(local_player_id())
	var progress := session.get_skills(local_player_id())
	_hud.setup(character, inventory, items, progress, skills)
	_player_feedback.setup(character, inventory, progress, items, skills, _damage_numbers)


## Desliga teclado/controle do jogador local (testes e capturas dirigem o personagem
## diretamente por intenções).
func detach_local_input() -> void:
	_input_detached = true
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
	for i in SCREENSHOT_FRAMES:
		await get_tree().physics_frame
		var character := session.get_player_entity(local_player_id()) as Character
		if character and move != Vector2.ZERO:
			detach_local_input()
			character.set_move_intent(move)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("[main] screenshot: %s" % screenshot_path)
	get_tree().quit()
