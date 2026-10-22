class_name TestCase
extends RefCounted
## Base dos testes automáticos. Cada método `test_*` de um arquivo `tests/test_*.gd` é
## executado por `tests/run_tests.gd`. Métodos podem usar `await` (ex.: esperar física).

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const CHARACTER_SCENE := preload("res://scenes/actors/character/character.tscn")

var tree: SceneTree
var failures := PackedStringArray()
var _owned_nodes: Array[Node] = []


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
	var character: Character = CHARACTER_SCENE.instantiate()
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
