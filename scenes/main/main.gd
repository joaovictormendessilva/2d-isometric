extends Node
## Ponto de entrada: cria a sessão, a rede (ver Network), as regiões, o jogador local e as
## criaturas. Single-player = host com 1 jogador (ADR-004); no coop, só o host cria as
## entidades e os clientes as recebem (ADR-012).
## Regiões (ADR-020): o host carrega cada região que tem jogador (cada uma no seu mundo, ver
## RegionWorlds) e diz a cada cliente qual carregar; a janela mostra a do jogador local.
##
## Argumentos de linha de comando (depois de `--`):
##   rede: ver `scenes/net/network.gd` (--host, --host-lan, --join=<ip>, --port=<n>).
##   --screenshot=<caminho.png>   salva uma captura após alguns quadros e fecha o jogo.
##   --move=<x>,<y>               segura essa intenção de movimento antes da captura.
##   --open-inventory             abre o inventário antes da captura.
##   --open-shop                  leva o jogador até o NPC da região e abre a loja dele.
##   --lang=<código>              idioma dos textos (ex.: en); sem ele, o idioma do sistema.
##   --region=<id>                o host começa nessa região (ex.: forest), sem olhar o save.

const REGIONS_DIR := "res://data/regions/"
const START_REGION := &"meadow"
const SKILLS_DIR := "res://data/skills/"
const STRUCTURES_DIR := "res://data/structures/"
const SCREENSHOT_FRAMES := 45
const STARTER_KIT := "res://data/debug/starter_kit.tres"
## Região que ficou sem ninguém continua carregada este tempo no host antes de ser guardada e
## liberada: mensagens atrasadas de quem acabou de sair ainda chegam aos nós dela.
const EMPTY_REGION_TIME := EntitySpawner.RETIRE_TIME * 1.5

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
## Região que a janela mostra (a do jogador local; null no cliente até o host dizer qual).
var region: Region

var _input_detached := false
var _local_ui_ready := false
## Host: jogadores com viagem já marcada (a passagem pode disparar mais de uma vez).
var _traveling: Dictionary[int, bool] = {}

@onready var network: Network = $Network
@onready var player_state: PlayerStateSync = $PlayerState
@onready var saves: SaveService = $Saves
@onready var worlds: RegionWorlds = $Regions
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
@onready var _shop_panel: ShopPanel = $UI/ShopPanel
@onready var _placement_preview: PlacementPreview = $World/PlacementPreview


func _ready() -> void:
	Texts.apply_command_line(OS.get_cmdline_user_args())
	if configure_network_from_command_line:
		network.configure_from_command_line(OS.get_cmdline_user_args())
	network.start()
	_net_status.network = network
	worlds.catalog = regions

	_spawner.structures = DataCatalog.new(STRUCTURES_DIR)
	if multiplayer.is_server():
		if _is_screenshot_run():
			save_path = ""
		saves.setup(save_path, session, _spawner, network, items, skills, recipes,
			_spawner.structures)
	_spawner.setup(session, local_player_id(), _damage_numbers, items, player_state)
	player_state.session = session
	player_state.items = items
	player_state.skills = skills
	player_state.recipes = recipes
	player_state.spawner = _spawner
	_local_input.player_state = player_state
	_interaction_prompt.player_state = player_state
	if use_debug_starter_kit and OS.is_debug_build() \
			and ProjectSettings.get_setting("game/debug/starter_kit", false):
		_spawner.starter_kit = load(STARTER_KIT)
	_spawner.local_player_spawned.connect(_on_local_player_spawned)
	_debug_overlay.session = session
	_debug_overlay.player_id = local_player_id()
	if multiplayer.is_server():
		_spawner.saves = saves
		_place_player(local_player_id(), _start_region(local_player_id()))
		network.player_joined.connect(func(player_id: int) -> void:
			_place_player(player_id, _start_region(player_id)))
		network.player_left.connect(_on_player_left)

	_handle_command_line()


func local_player_id() -> int:
	return network.local_player_id()


# --- Host: quem está em que região -------------------------------------------------------------

## Onde o jogador começa: a região onde estava ao sair (save) ou a inicial. O jogador do host
## pode escolher com `--region=` (testes e capturas).
func _start_region(player_id: int) -> StringName:
	var chosen := saves.region_of(player_id)
	if player_id == local_player_id():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--region="):
				chosen = StringName(arg.trim_prefix("--region="))
	return chosen if regions.get_entry(chosen) else START_REGION


## Põe o jogador na região: chegando no mundo, ou viajando (o personagem é recriado lá, na
## chegada da passagem `passage_id`, com a vida que tinha). O cliente dele é avisado antes de
## o personagem nascer, para já ter a região carregada.
func _place_player(player_id: int, region_id: StringName, passage_id: StringName = &"") -> void:
	var target := _ensure_region(region_id)
	var old := _spawner.region_of_player(player_id)
	var health := _spawner.leave_region(player_id)
	if player_id != local_player_id():
		_enter_region.rpc_id(player_id, region_id)
	var passage := target.get_passage(passage_id)
	_spawner.enter_region(player_id, target,
		passage.arrival_position() if passage else target.get_spawn_position(), health)
	if old and old != target:
		_release_when_empty(old)


## Carrega a região se ainda não estiver: estado do save, criaturas e passagens.
func _ensure_region(region_id: StringName) -> Region:
	var loaded := worlds.get_region(region_id)
	if loaded:
		return loaded
	loaded = _load_region(region_id)
	loaded.passage_entered.connect(_on_passage_entered)
	saves.region_loaded(loaded)
	_spawner.spawn_region_monsters(loaded)
	return loaded


func _release_when_empty(old: Region) -> void:
	get_tree().create_timer(EMPTY_REGION_TIME).timeout.connect(
		_release_if_empty.bind(weakref(old)))


## Sem ninguém lá, a região vai para o save (memória) e é liberada, com as criaturas e os itens
## no chão dela.
func _release_if_empty(region_ref: WeakRef) -> void:
	var old := region_ref.get_ref() as Region
	if old and _spawner.players_in(old) == 0:
		saves.region_unloading(old)
		worlds.unload(old)


## Um jogador (de qualquer região) entrou numa passagem. A viagem acontece depois da física:
## a troca de região sai do passo de colisões.
func _on_passage_entered(player_id: int, passage: Passage) -> void:
	if not _traveling.has(player_id):
		_traveling[player_id] = true
		_travel.call_deferred(player_id, passage.target_region, passage.target_passage)


func _travel(player_id: int, region_id: StringName, passage_id: StringName) -> void:
	_traveling.erase(player_id)
	if session.get_player_entity(player_id) != null and regions.get_entry(region_id) != null:
		_place_player(player_id, region_id, passage_id)


func _on_player_left(player_id: int) -> void:
	var left := _spawner.region_of_player(player_id)
	_spawner.despawn_player(player_id)
	if left:
		_release_when_empty(left)


# --- Todos: região carregada e mostrada --------------------------------------------------------

func _load_region(region_id: StringName) -> Region:
	var loaded := worlds.load_region(region_id)
	_spawner.add_region(loaded)
	return loaded


## Host → cliente: o jogador dele vai para esta região (chegando no mundo ou viajando). O
## cliente troca a região carregada; as entidades de lá chegam logo depois pelo replicador.
@rpc("authority", "call_remote", "reliable")
func _enter_region(region_id: StringName) -> void:
	if regions.get_entry(region_id) == null or (region and region.region_id == region_id):
		return
	for loaded in worlds.loaded():
		worlds.unload(loaded)
	_show_region(_load_region(region_id))


func _show_region(shown: Region) -> void:
	if shown == region:
		return
	region = shown
	worlds.show_region(shown)
	_camera.set_bounds(shown.camera_bounds)
	# A Godot solta a camada que segue a câmera (textos do mundo) quando o mundo da janela
	# troca; tirar e pôr de volta na árvore a liga ao mundo novo (ver tests/render_checks.gd).
	var world_text := _damage_numbers.get_parent()
	remove_child(world_text)
	add_child(world_text)
	move_child(world_text, _camera.get_index())


## O personagem do jogador local chegou (no host, na hora; no cliente, quando o host o cria).
## Ele é recriado a cada viagem: o que depende do personagem é refeito, o resto só da primeira vez.
func _on_local_player_spawned(character: Character) -> void:
	_show_region(Region.of(character))
	_local_input.player_id = local_player_id()
	if not _input_detached:
		_local_input.target = character
	_camera.follow(character)
	var inventory := session.get_inventory(local_player_id())
	_hud.set_character(character)
	_player_feedback.set_character(character)
	_interaction_prompt.setup(character)
	_placement_preview.setup(inventory, items, character)
	if _local_ui_ready:
		return
	_local_ui_ready = true
	var progress := session.get_skills(local_player_id())
	var wallet := session.get_wallet(local_player_id())
	_hud.setup(progress, skills, inventory, items, session.get_cooldowns(local_player_id()))
	_player_feedback.setup(inventory, wallet, session.get_recipe_book(local_player_id()), recipes,
		progress, items, skills, _damage_numbers)
	player_state.use_refused.connect(_player_feedback.show_use_refusal)
	_inventory_panel.placement = _placement_preview
	_inventory_panel.setup(inventory, items, player_state, local_player_id())
	_setup_shop(inventory, wallet)
	player_state.request_full_state()


## Loja dos NPCs: a tecla de interagir perto de um abre; o inventário abre e fecha junto (vender
## é pelo menu do botão direito dele), e fechar o inventário encerra a conversa.
func _setup_shop(inventory: Inventory, wallet: Wallet) -> void:
	_shop_panel.setup(inventory, wallet, items, player_state, local_player_id())
	_inventory_panel.shop = _shop_panel
	_local_input.talk_requested.connect(_shop_panel.talk_to)
	_shop_panel.toggled.connect(func(open: bool) -> void:
		if _inventory_panel.visible != open:
			_inventory_panel.set_open(open))
	_inventory_panel.visibility_changed.connect(func() -> void:
		if not _inventory_panel.visible:
			_shop_panel.close())


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
	var open_shop := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--move="):
			var parts := arg.trim_prefix("--move=").split(",")
			move = Vector2(parts[0].to_float(), parts[1].to_float())
		elif arg == "--open-shop":
			open_shop = true
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
	if open_shop:
		_talk_to_first_npc()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("[main] screenshot: %s" % screenshot_path)
	get_tree().quit()


## Captura de tela da loja: põe o jogador ao lado do primeiro NPC da região e abre a loja.
func _talk_to_first_npc() -> void:
	var character := session.get_player_entity(local_player_id()) as Character
	for node in region.entities.get_children():
		var npc := node as Npc
		if npc and character:
			character.position = npc.position + Iso.ground_to_screen(Vector2(-20, 0))
			character.reset_physics_interpolation()
			_shop_panel.talk_to(npc)
			return
