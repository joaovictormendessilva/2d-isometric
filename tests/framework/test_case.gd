class_name TestCase
extends RefCounted
## Base dos testes automáticos. Cada método `test_*` de um arquivo `tests/test_*.gd` é
## executado por `tests/run_tests.gd`. Métodos podem usar `await` (ex.: esperar física).

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const PLAYER_SCENE := preload("res://scenes/actors/character/player.tscn")
const SLIME_SCENE := preload("res://scenes/actors/monsters/slime.tscn")

var tree: SceneTree
var failures := PackedStringArray()
var _owned_nodes: Array[Node] = []
var _multiplayer_roots: Array[NodePath] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance,
		"%s (esperado %.2f ± %.2f, obtido %.2f)" % [message, expected, tolerance, actual])


## Adiciona um nó à árvore; ele é removido automaticamente ao fim do teste.
func add_to_tree(node: Node) -> Node:
	tree.root.add_child(node)
	_owned_nodes.append(node)
	return node


## Cria o jogo completo (cena principal) com o controle local desligado. Sem `save_path`, o
## jogo não lê nem grava save.
func start_game(save_path: String = "") -> Node:
	var game := _new_game(save_path)
	add_to_tree(game)
	game.detach_local_input()
	return game


## Avisos flutuantes do jogador local (`PlayerFeedback`) na fila ou já mostrados.
func feedback_texts(game: Node) -> Array:
	var feedback := game.get_node("PlayerFeedback") as PlayerFeedback
	var texts: Array = feedback._queue.map(func(message: Array) -> String: return message[0])
	for label: Label in (game.get_node("WorldText/DamageNumbers") as DamageNumbers)._pool:
		if not label.text.is_empty():
			texts.append(label.text)
	return texts


## Jogador avulso, já com o equipamento inicial vestido (como o spawner faz no jogo).
func spawn_character(at: Vector2) -> Character:
	var character: Character = PLAYER_SCENE.instantiate()
	character.position = at
	var equipment := Equipment.new(EquipmentLayout.load_default(), ItemDatabase.load_all())
	for item in character.stats.starting_equipment:
		EquipmentRules.give_equipped(equipment, item)
	character.apply_equipment(equipment)
	return add_to_tree(character)


func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func cleanup() -> void:
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()
	for path in _multiplayer_roots:
		tree.set_multiplayer(null, path)
	_multiplayer_roots.clear()


## Slime avulso; com `session`, a IA dele enxerga os jogadores dessa sessão.
func spawn_slime(at: Vector2, session: GameSession = null) -> Monster:
	var slime: Monster = SLIME_SCENE.instantiate()
	slime.position = at
	(slime.get_node("Brain") as MonsterBrain).session = session
	return add_to_tree(slime)


## Registra um personagem avulso como jogador de uma sessão de teste.
func register_player(session: GameSession, character: Character, player_id: int) -> void:
	character.player_id = player_id
	character.entity_id = session.allocate_entity_id()
	session.register_entity(character.entity_id, character)
	session.add_player(player_id, character.entity_id)


## Uma instância do jogo em rede dentro do teste: cada uma num SubViewport (mundo físico
## próprio) com a própria API de rede, como se fosse outro computador. `in_window`: direto na
## janela (desenhada, com a API de rede dela), para benchmarks com uma instância por processo.
## `match_code`: código da partida (no host, o exigido; no cliente, o digitado).
func start_network_game(instance_name: String, role: Network.Role, port: int,
		save_path: String = "", in_window: bool = false, match_code: String = "") -> Node:
	var game := _new_game(save_path)
	game.configure_network_from_command_line = false
	var network: Network = game.get_node("Network")
	network.role = role
	network.port = port
	network.match_code = match_code
	if in_window:
		add_to_tree(game)
	else:
		var viewport := SubViewport.new()
		viewport.name = instance_name
		add_to_tree(viewport)
		tree.set_multiplayer(SceneMultiplayer.new(), viewport.get_path())
		_multiplayer_roots.append(viewport.get_path())
		viewport.add_child(game)
	game.detach_local_input()
	return game


func _new_game(save_path: String) -> Node:
	var game := MAIN_SCENE.instantiate()
	game.use_debug_starter_kit = false  # testes contam itens: começam de mãos vazias
	game.use_dev_merchant = false
	game.save_path = save_path
	return game


## Espera até `condition` ser verdadeira (no máximo `max_frames` passos de física).
func wait_until(condition: Callable, max_frames: int = 300) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


func first_monster(game: Node) -> Monster:
	for node in (game.region as Region).entities.get_children():
		if node is Monster:
			return node
	return null


func pickups(game: Node) -> Array:
	return (game.region as Region).entities.get_children().filter(func(n: Node) -> bool: return n is Pickup)


func structures(game: Node) -> Array:
	return (game.region as Region).entities.get_children().filter(func(n: Node) -> bool: return n is Structure)


## Ponto livre perto do jogador onde a estrutura pode ser colocada (procura em volta dele).
func free_spot_near(character: Character, structure: StructureData) -> Vector2:
	var space := character.get_world_2d().direct_space_state
	for distance in [24.0, 32.0, 40.0]:
		for step in 16:
			var at: Vector2 = character.position + Iso.ground_to_screen(
				Vector2.from_angle(TAU * step / 16.0) * distance)
			if PlacementRules.can_place(space, structure, character.position, at.round()):
				return at.round()
	return character.position  # nenhum: o teste que usar vai reprovar


## Desliga a IA de todas as criaturas (testes que não querem ser interrompidos por ataques).
func calm_monsters(game: Node) -> void:
	for node in (game.region as Region).entities.get_children():
		if node is Monster:
			node.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED


## Primeiro ponto de coleta do tipo dado (`ResourceNodeData.id`) na região.
func resource_node(game: Node, data_id: StringName) -> ResourceNode:
	for node in (game.region as Region).entities.get_children():
		if node is ResourceNode and node.data.id == data_id:
			return node
	return null


## Primeiro NPC da região (o mercador, na campina), ou null.
func merchant_node(game: Node) -> Npc:
	for node in (game.region as Region).entities.get_children():
		if node is Npc:
			return node
	return null


## Põe o personagem encostado no ponto de coleta (à esquerda dele, no plano do chão).
func stand_next_to(character: Character, node: ResourceNode) -> void:
	character.position = node.approach_point(character.footprint_radius())
	character.reset_physics_interpolation()


## Leva um personagem simulado neste computador até `target` a uma velocidade aceita pelo host
## (o host recusa teletransporte). Ignora colisões: o teste só precisa chegar.
func glide_to(character: Character, target: Vector2) -> void:
	const STEP := 1.5  # px por quadro = 90 px/s
	while character.position.distance_to(target) > STEP:
		character.position = character.position.move_toward(target, STEP)
		await tree.physics_frame
	character.position = target


## Clique esquerdo (pressionado) para entregar a controles da interface.
func left_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


## Primeiro espaço do inventário com este item, ou -1.
func slot_of(inventory: Inventory, item_id: StringName) -> int:
	for index in inventory.capacity():
		if inventory.slot_item(index) == item_id:
			return index
	return -1
