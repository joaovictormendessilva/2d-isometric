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


## Cria o jogo completo (cena principal) com o controle local desligado.
func start_game() -> Node:
	var game := add_to_tree(MAIN_SCENE.instantiate())
	game.detach_local_input()
	return game


func spawn_character(at: Vector2) -> Character:
	var character: Character = PLAYER_SCENE.instantiate()
	character.position = at
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
## próprio) com a própria API de rede, como se fosse outro computador.
func start_network_game(instance_name: String, role: Network.Role, port: int) -> Node:
	var viewport := SubViewport.new()
	viewport.name = instance_name
	add_to_tree(viewport)
	tree.set_multiplayer(SceneMultiplayer.new(), viewport.get_path())
	_multiplayer_roots.append(viewport.get_path())
	var game := MAIN_SCENE.instantiate()
	game.configure_network_from_command_line = false
	var network: Network = game.get_node("Network")
	network.role = role
	network.port = port
	viewport.add_child(game)
	game.detach_local_input()
	return game


## Espera até `condition` ser verdadeira (no máximo `max_frames` passos de física).
func wait_until(condition: Callable, max_frames: int = 300) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()
