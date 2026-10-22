class_name GameSession
extends RefCounted
## Estado da sessão independente da apresentação (ADR-004): quais jogadores existem, que
## entidade cada um controla e o registro de entidades por ID estável.
## Single-player = sessão com 1 jogador. Nenhum sistema deve procurar "o jogador" por nome
## de nó: pergunte à sessão pelo `player_id`.

var _next_entity_id := 1
var _entities: Dictionary[int, Node] = {}
var _player_entities: Dictionary[int, int] = {}  # player_id -> entity_id
var _inventories: Dictionary[int, Inventory] = {}  # player_id -> inventário


func allocate_entity_id() -> int:
	var id := _next_entity_id
	_next_entity_id += 1
	return id


func register_entity(entity_id: int, node: Node) -> void:
	_entities[entity_id] = node


func unregister_entity(entity_id: int) -> void:
	_entities.erase(entity_id)


func get_entity(entity_id: int) -> Node:
	return _entities.get(entity_id)


func add_player(player_id: int, entity_id: int) -> void:
	_player_entities[player_id] = entity_id
	if not _inventories.has(player_id):
		_inventories[player_id] = Inventory.new()


func get_inventory(player_id: int) -> Inventory:
	return _inventories.get(player_id)


func get_player_entity(player_id: int) -> Node:
	return get_entity(_player_entities.get(player_id, 0))


## Jogador saiu (desconectou). Sem identidade persistente ainda (Etapa I), um retorno é um
## jogador novo: o inventário vai junto.
func remove_player(player_id: int) -> void:
	_player_entities.erase(player_id)
	_inventories.erase(player_id)


func get_player_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_player_entities.keys())
	return ids


func get_player_count() -> int:
	return _player_entities.size()


func get_entity_count() -> int:
	return _entities.size()
