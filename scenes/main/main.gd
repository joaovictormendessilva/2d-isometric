extends Node
## Ponto de entrada: cria a sessão, a rede (ver Network), a região inicial, o jogador local e
## as criaturas. Single-player = host com 1 jogador (ADR-004); no coop, só o host cria as
## entidades e os clientes as recebem (ADR-012).
##
## Argumentos de linha de comando (depois de `--`):
##   rede: ver `scenes/net/network.gd` (--host, --host-lan, --join=<ip>, --port=<n>).
##   --screenshot=<caminho.png>   salva uma captura após alguns quadros e fecha o jogo.
##   --move=<x>,<y>               segura essa intenção de movimento antes da captura.
##   --open-inventory             abre o inventário antes da captura.
##   --lang=<código>              idioma dos textos (ex.: en); sem ele, o idioma do sistema.
##   --region=<id>                começa nessa região (ex.: forest), sem olhar o save.

const REGIONS_DIR := "res://data/regions/"
const START_REGION := &"meadow"
const SKILLS_DIR := "res://data/skills/"
const STRUCTURES_DIR := "res://data/structures/"
const SCREENSHOT_FRAMES := 45
const STARTER_KIT := "res://data/debug/starter_kit.tres"

## Defina antes de adicionar à árvore para ignorar a linha de comando (testes de rede).
var configure_network_from_command_line := true
## Kit de itens para testes (`game/debug/starter_kit` no project.godot). Só existe em
## compilações de desenvolvimento: um jogo exportado nunca dá itens de graça. Testes desligam.
var use_debug_starter_kit := true
## Save do mundo (só o host usa); vazio = não lê nem grava. Capturas de tela não usam save.
var save_path := SaveService.default_path

var items := ItemDatabase.load_all()
var skills := DataCatalog.new(SKILLS_DIR)
var recipes := RecipeDatabase.load_all()
var session := GameSession.new(items)
var regions := DataCatalog.new(REGIONS_DIR)
## Região carregada (a do jogador local).
var region: Region

var _input_detached := false
var _traveling := false

@onready var network: Network = $Network
@onready var player_state: PlayerStateSync = $PlayerState
@onready var saves: SaveService = $Saves
@onready var _world: Node2D = $World
@onready var _camera: GameCamera = $Camera
@onready var _local_input: LocalPlayerInput = $LocalInput
@onready var _spawner: EntitySpawner = $EntitySpawner
@onready var _damage_numbers: DamageNumbers = $WorldText/DamageNumbers
@onready var _hud: Hud = $UI/Hud
@onready var _net_status: NetStatus = $UI/NetStatus
@onready var _debug_overlay: DebugOverlay = $UI/DebugOverlay
@onready var _player_feedback: PlayerFeedback = $PlayerFeedback
@onready var _interaction_prompt: InteractionPrompt = $WorldText/InteractionPrompt
@onready var _inventory_panel: InventoryPanel = $UI/InventoryPanel
@onready var _placement_preview: PlacementPreview = $World/PlacementPreview


func _ready() -> void:
	Texts.apply_command_line(OS.get_cmdline_user_args())
	# A rede começa ANTES da região: os objetos da região (pontos de coleta) decidem no
	# próprio `_ready` se pedem o estado ao host.
	if configure_network_from_command_line:
		network.configure_from_command_line(OS.get_cmdline_user_args())
	network.start()
	_net_status.network = network

	_spawner.structures = DataCatalog.new(STRUCTURES_DIR)
	if multiplayer.is_server():
		if _is_screenshot_run():
			save_path = ""
		saves.setup(save_path, session, _spawner, network, items, skills, _spawner.structures)
	_load_region(_start_region())

	_spawner.setup(session, region, local_player_id(), _damage_numbers, items, player_state)
	player_state.session = session
	player_state.items = items
	player_state.skills = skills
	player_state.recipes = recipes
	player_state.spawner = _spawner
	if use_debug_starter_kit and OS.is_debug_build() \
			and ProjectSettings.get_setting("game/debug/starter_kit", false):
		_spawner.starter_kit = load(STARTER_KIT)
	_spawner.local_player_spawned.connect(_on_local_player_spawned)
	_debug_overlay.session = session
	_debug_overlay.player_id = local_player_id()
	if multiplayer.is_server():
		saves.enter_region(region)
		_spawner.saves = saves
		_spawner.spawn_player(local_player_id())
		_spawner.spawn_region_monsters()
		network.player_joined.connect(_spawner.spawn_player)
		network.player_left.connect(_spawner.despawn_player)

	_handle_command_line()


func local_player_id() -> int:
	return network.local_player_id()


## Sozinho: a região onde o jogador estava ao sair (save), ou a de `--region=`. No coop todos
## começam na inicial, porque ainda só existe uma região ativa por partida (F2c).
func _start_region() -> RegionData:
	if network.is_online():
		return regions.get_entry(START_REGION) as RegionData
	var chosen := saves.region_of(local_player_id())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--region="):
			chosen = StringName(arg.trim_prefix("--region="))
	var data := regions.get_entry(chosen) as RegionData
	return data if data else regions.get_entry(START_REGION) as RegionData


func _load_region(data: RegionData) -> void:
	region = data.scene.instantiate()
	_world.add_child(region)
	region.passage_entered.connect(_on_passage_entered)
	_camera.set_bounds(region.camera_bounds)


## Um jogador entrou numa passagem. Sozinho, viaja (depois da física: a região é trocada fora
## do passo de colisões). No coop ainda não há viagem (F2c): quem entrou só vê o aviso.
func _on_passage_entered(player_id: int, passage: Passage) -> void:
	if network.is_online():
		var character := session.get_player_entity(player_id) as Character
		if player_id == local_player_id() and character:
			_damage_numbers.show_text(character.position, Texts.get_text(&"PASSAGE_COOP_SOON"),
				UiStyle.WARNING)
		return
	if not _traveling:
		_traveling = true
		_travel.call_deferred(player_id, passage.target_region, passage.target_passage)


## Troca a região carregada: a anterior vai para o save (memória) e é liberada, com as criaturas
## e os itens no chão dela; o personagem passa para a nova, na chegada da passagem de destino.
func _travel(player_id: int, region_id: StringName, passage_id: StringName) -> void:
	_traveling = false
	var target := regions.get_entry(region_id) as RegionData
	var character := session.get_player_entity(player_id) as Character
	if target == null or character == null:
		return
	character.gatherer.stop()
	saves.leave_region()
	var old := region
	_load_region(target)
	_spawner.set_region(region)
	var passage := region.get_passage(passage_id)
	_spawner.move_player(character,
		passage.arrival_position() if passage else region.get_spawn_position())
	old.free()
	saves.enter_region(region)
	_spawner.spawn_region_monsters()


## O personagem do jogador local chegou (no host, na hora; no cliente, quando o host o cria).
func _on_local_player_spawned(character: Character) -> void:
	_local_input.player_id = local_player_id()
	if _local_input.target == null and not _input_detached:
		_local_input.target = character
	_camera.follow(character)
	var inventory := session.get_inventory(local_player_id())
	var progress := session.get_skills(local_player_id())
	_hud.setup(character, progress, skills)
	_player_feedback.setup(character, inventory, progress, items, skills, _damage_numbers)
	_interaction_prompt.setup(character)
	_placement_preview.setup(inventory, items, character)
	_inventory_panel.placement = _placement_preview
	_inventory_panel.setup(inventory, items, player_state, local_player_id())
	player_state.request_full_state()


## Desliga teclado/controle do jogador local (testes e capturas dirigem o personagem
## diretamente por intenções).
func detach_local_input() -> void:
	_input_detached = true
	_local_input.target = null


static func _is_screenshot_run() -> bool:
	return Array(OS.get_cmdline_user_args()).any(
		func(arg: String) -> bool: return arg.begins_with("--screenshot="))


func _handle_command_line() -> void:
	var screenshot_path := ""
	var move := Vector2.ZERO
	var open_inventory := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--move="):
			var parts := arg.trim_prefix("--move=").split(",")
			move = Vector2(parts[0].to_float(), parts[1].to_float())
		elif arg == "--open-inventory":
			open_inventory = true
	if screenshot_path.is_empty():
		return
	for i in SCREENSHOT_FRAMES:
		await get_tree().physics_frame
		var character := session.get_player_entity(local_player_id()) as Character
		if character and move != Vector2.ZERO:
			detach_local_input()
			character.set_move_intent(move)
	if open_inventory:
		_inventory_panel.set_open(true)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("[main] screenshot: %s" % screenshot_path)
	get_tree().quit()
