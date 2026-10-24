extends Node
## Ponto de entrada: cria a sessão, a rede (ver Network), as regiões, o jogador local e as
## criaturas. Single-player = host com 1 jogador (ADR-004); no coop, só o host cria as
## entidades e os clientes as recebem (ADR-012).
## Regiões (ADR-020): o host carrega cada região que tem jogador (cada uma no seu mundo, ver
## RegionWorlds) e diz a cada cliente qual carregar; a janela mostra a do jogador local.
##
## Argumentos de linha de comando (depois de `--`):
##   rede: ver `scenes/net/network.gd` (--host, --host-lan, --join=<ip>, --code=<c>, --port=<n>).
##   --screenshot=<caminho.png>   salva uma captura após alguns quadros e fecha o jogo.
##   --move=<x>,<y>               segura essa intenção de movimento antes da captura.
##   --at=<x>,<y>                 põe o jogador nesse ponto da região antes da captura.
##   --open-inventory             abre o inventário antes da captura.
##   --open-shop[=<npc>]          leva o jogador até o NPC da região (ou o de id <npc>) e abre a
##                                loja dele.
##   --effect=<id>                aplica esse efeito (data/effects/) no jogador antes da captura.
##   --lang=<código>              idioma dos textos (ex.: en); sem ele, o idioma do sistema.
##   --region=<id>                o host começa nessa região (ex.: forest), sem olhar o save.
##   --quality=<low|medium|high>  qualidade dos efeitos só nesta execução (ADR-028).
##   --equip=<ids>                veste esses itens (data/items/, separados por vírgula) antes da
##                                captura.
##   --look=<ids>                 coleciona esses equipamentos e os mostra como aparência
##                                (transmog) no primeiro espaço do tipo de cada um.

## O jogador local chegou ao mundo (primeira vez nesta partida).
signal match_started
## A partida não abriu (porta em uso, host não encontrado, código errado...) ou o cliente
## perdeu o host; `reason` é o aviso para o jogador. Quem criou o jogo decide o que fazer
## (GameStart volta à tela de partida).
signal match_ended(reason: String)

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
## Mercador de testes (ver DevMerchant). Mesmas regras do kit; testes desligam.
var use_dev_merchant := true
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
## Barra do chefe no alto da tela e teclas de habilidade embaixo (só do jogador local). Criadas
## quando o personagem local chega: um cliente recusado antes disso não deixa nós soltos.
var _boss_bar: BossBar
var _ability_bar: AbilityBar

@onready var network: Network = $Network
@onready var player_state: PlayerStateSync = $PlayerState
@onready var abilities: AbilitySync = $Abilities
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
	VfxQuality.shared().apply_command_line(OS.get_cmdline_user_args())
	if configure_network_from_command_line:
		network.configure_from_command_line(OS.get_cmdline_user_args())
	_net_status.network = network
	# O cliente espera a porta da frente do host. Sem conseguir abrir a partida, nenhum mundo
	# é montado (o cliente nunca tem um mundo próprio no lugar do do host): fica o aviso.
	if await network.start() != OK:
		if _is_screenshot_run():
			await get_tree().create_timer(NetStatus.REFRESH_INTERVAL * 2).timeout  # aviso na tela
			Screenshot.capture_and_quit(self, Screenshot.path())
		match_ended.emit(network.status_text())
		return
	network.connection_ended.connect(func() -> void: match_ended.emit(network.status_text()))
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
	abilities.session = session
	_spawner.abilities = abilities
	_local_input.player_state = player_state
	_local_input.abilities = abilities
	_interaction_prompt.player_state = player_state
	if use_debug_starter_kit and OS.is_debug_build() \
			and ProjectSettings.get_setting("game/debug/starter_kit", false):
		_spawner.starter_kit = load(STARTER_KIT)
	_spawner.local_player_spawned.connect(_on_local_player_spawned)
	# Avisos só depois de o estado do jogador chegar: o que veio do save ou do host não é novidade.
	_spawner.local_player_prepared.connect(_player_feedback.start_announcing, CONNECT_ONE_SHOT)
	abilities.full_state_received.connect(_player_feedback.start_announcing, CONNECT_ONE_SHOT)
	_debug_overlay.session = session
	_debug_overlay.player_id = local_player_id()
	if multiplayer.is_server():
		_spawner.saves = saves
		_arrive(local_player_id())
		network.player_joined.connect(_arrive)
		network.player_left.connect(_on_player_left)

	_handle_command_line()


func local_player_id() -> int:
	return network.local_player_id()


# --- Host: quem está em que região -------------------------------------------------------------

## Jogador chegando ao mundo: na região e passagem onde estava ao sair (save; quem saiu dentro
## de uma dungeon volta para a entrada dela).
func _arrive(player_id: int) -> void:
	_place_player(player_id, _start_region(player_id), saves.passage_of(player_id))


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
	if use_dev_merchant and DevMerchant.is_enabled():
		DevMerchant.add_to(loaded, items, recipes)
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
	if not _local_ui_ready:
		_boss_bar = BossBar.new()
		$UI.add_child(_boss_bar)
	_boss_bar.set_character(character)
	_player_feedback.set_character(character)
	_interaction_prompt.setup(character)
	_placement_preview.setup(inventory, items, character)
	if _local_ui_ready:
		return
	_local_ui_ready = true
	_ability_bar = AbilityBar.new()
	$UI.add_child(_ability_bar)
	_ability_bar.setup(session.get_ability_book(local_player_id()), abilities)
	var progress := session.get_skills(local_player_id())
	var wallet := session.get_wallet(local_player_id())
	_hud.setup(progress, skills, inventory, items, session.get_cooldowns(local_player_id()),
		session.get_effects(local_player_id()))
	_player_feedback.setup(inventory, wallet, session.get_recipe_book(local_player_id()), recipes,
		progress, items, skills, _damage_numbers)
	player_state.use_refused.connect(_player_feedback.show_use_refusal)
	abilities.cast_refused.connect(_player_feedback.show_cast_refusal)
	_player_feedback.watch_abilities(session.get_ability_book(local_player_id()))
	_player_feedback.watch_effects(session.get_effects(local_player_id()))
	_player_feedback.watch_appearances(session.get_appearances(local_player_id()), items)
	_inventory_panel.placement = _placement_preview
	_inventory_panel.setup(inventory, items, player_state, local_player_id())
	_setup_shop(inventory, wallet)
	player_state.request_full_state()
	abilities.request_full_state()
	match_started.emit()


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
	return not Screenshot.path().is_empty()


func _handle_command_line() -> void:
	var screenshot_path := Screenshot.path()
	var move := Vector2.ZERO
	var at := Vector2.INF
	var open_inventory := false
	var open_shop := false
	var shop_npc := &""
	var effects: Array[StatusEffectData] = []
	var equip := ""
	var looks := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--equip="):
			equip = arg.trim_prefix("--equip=")
		elif arg.begins_with("--look="):
			looks = arg.trim_prefix("--look=")
		elif arg.begins_with("--at="):
			at = _vector_arg(arg.trim_prefix("--at="))
		elif arg.begins_with("--move="):
			move = _vector_arg(arg.trim_prefix("--move="))
		elif arg == "--open-shop" or arg.begins_with("--open-shop="):
			open_shop = true
			shop_npc = StringName(arg.trim_prefix("--open-shop").trim_prefix("="))
		elif arg == "--open-inventory":
			open_inventory = true
		elif arg.begins_with("--effect="):
			var effect := EffectDatabase.shared().get_effect(StringName(arg.trim_prefix("--effect=")))
			if effect:
				effects.append(effect)
	if screenshot_path.is_empty():
		return
	dev_equip(local_player_id(), equip)
	_dev_look(local_player_id(), looks)
	var player := session.get_player_entity(local_player_id()) as Character
	if player and at.is_finite():
		player.position = at
		player.reset_physics_interpolation()
	for i in SCREENSHOT_FRAMES:
		await get_tree().physics_frame
		var character := session.get_player_entity(local_player_id()) as Character
		if character and move != Vector2.ZERO:
			detach_local_input()
			character.set_move_intent(move)
		if character and not effects.is_empty():
			for effect in effects:
				character.status_effects.apply(effect)
			effects.clear()
	if open_inventory:
		_inventory_panel.set_open(true)
	if open_shop:
		_talk_to_first_npc(shop_npc)
	Screenshot.capture_and_quit(self, screenshot_path)


## Capturas (tela e folha de quadros): veste itens novos de `ids` (separados por vírgula) direto
## no equipamento do jogador, onde couberem (sem espaço livre do tipo, substitui o primeiro: ex.
## o arco no lugar da espada inicial). Não é ação de jogo: só ferramentas chamam.
func dev_equip(player_id: int, ids: String) -> void:
	var equipment := session.get_equipment(player_id)
	for id in ids.split(",", false):
		var item := equipment.data_of(StringName(id))
		var worn := item != null and EquipmentRules.give_equipped(equipment, item)
		if item and not worn and equipment.index_of_type(item.get_slot()) >= 0:
			equipment.replicate_slot(equipment.index_of_type(item.get_slot()), Equipment.EMPTY)
			worn = EquipmentRules.give_equipped(equipment, item)
		if not worn:
			push_warning("[main] --equip: %s não é equipamento ou não coube" % id)


## Capturas: coleciona cada equipamento de `ids` e o mostra no primeiro espaço do tipo dele.
func _dev_look(player_id: int, ids: String) -> void:
	var equipment := session.get_equipment(player_id)
	var collection := session.get_appearances(player_id)
	for id in ids.split(",", false):
		var item := equipment.data_of(StringName(id))
		if item == null:
			push_warning("[main] --look: %s não é equipamento" % id)
			continue
		collection.collect(item.id)
		EquipmentRules.set_look(equipment, collection, equipment.index_of_type(item.get_slot()),
			item.id)


## Captura de tela da loja: põe o jogador ao lado do primeiro NPC da região e abre a loja.
func _talk_to_first_npc(npc_id: StringName = &"") -> void:
	var character := session.get_player_entity(local_player_id()) as Character
	for node in region.entities.get_children():
		var npc := node as Npc
		if npc and character and (npc_id.is_empty() or npc.data.id == npc_id):
			character.position = npc.position + Iso.ground_to_screen(Vector2(-20, 0))
			character.reset_physics_interpolation()
			_shop_panel.talk_to(npc)
			return


## "x,y" da linha de comando (capturas).
static func _vector_arg(text: String) -> Vector2:
	var parts := text.split(",")
	return Vector2(parts[0].to_float(), parts[1].to_float()) if parts.size() == 2 else Vector2.ZERO
