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
var _skills: Dictionary[int, SkillProgress] = {}  # player_id -> experiência de coleta
var _equipment: Dictionary[int, Equipment] = {}  # player_id -> equipamento vestido
var _wallets: Dictionary[int, Wallet] = {}  # player_id -> moedas
var _cooldowns: Dictionary[int, Cooldowns] = {}  # player_id -> esperas (poções)
var _recipe_books: Dictionary[int, RecipeBook] = {}  # player_id -> receitas aprendidas
var _effects: Dictionary[int, ActiveEffects] = {}  # player_id -> buffs e debuffs
var _ability_books: Dictionary[int, AbilityBook] = {}  # player_id -> habilidades
var _items: ItemDatabase
var _equipment_layout: EquipmentLayout


## `items` dá o limite de pilha de cada item nos inventários (sem ele: limite padrão).
## `equipment_layout`: espaços de equipamento (sem ele: o de `data/`).
func _init(items: ItemDatabase = null, equipment_layout: EquipmentLayout = null) -> void:
	_items = items
	_equipment_layout = equipment_layout if equipment_layout else EquipmentLayout.load_default()


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


## `inventory_slots`: tamanho do inventário, criado só na primeira vez (renascer não o zera).
func add_player(player_id: int, entity_id: int,
		inventory_slots: int = Inventory.DEFAULT_SLOTS) -> void:
	_player_entities[player_id] = entity_id
	if not _inventories.has(player_id):
		_inventories[player_id] = Inventory.new(inventory_slots, _items)
		_skills[player_id] = SkillProgress.new()
		_equipment[player_id] = Equipment.new(_equipment_layout, _items)
		_wallets[player_id] = Wallet.new()
		_cooldowns[player_id] = Cooldowns.new()
		_recipe_books[player_id] = RecipeBook.new()
		_effects[player_id] = ActiveEffects.new()
		_ability_books[player_id] = AbilityBook.new()


func get_inventory(player_id: int) -> Inventory:
	return _inventories.get(player_id)


func get_equipment(player_id: int) -> Equipment:
	return _equipment.get(player_id)


func get_skills(player_id: int) -> SkillProgress:
	return _skills.get(player_id)


func get_wallet(player_id: int) -> Wallet:
	return _wallets.get(player_id)


func get_cooldowns(player_id: int) -> Cooldowns:
	return _cooldowns.get(player_id)


func get_recipe_book(player_id: int) -> RecipeBook:
	return _recipe_books.get(player_id)


func get_effects(player_id: int) -> ActiveEffects:
	return _effects.get(player_id)


func get_ability_book(player_id: int) -> AbilityBook:
	return _ability_books.get(player_id)


func get_player_entity(player_id: int) -> Node:
	return get_entity(_player_entities.get(player_id, 0))


## Jogador saiu (desconectou). O save do mundo (SaveService, só no host) já guardou o personagem;
## aqui ele some da sessão (quem volta é recriado e recebe o progresso do save).
func remove_player(player_id: int) -> void:
	_player_entities.erase(player_id)
	_inventories.erase(player_id)
	_skills.erase(player_id)
	_equipment.erase(player_id)
	_wallets.erase(player_id)
	_cooldowns.erase(player_id)
	_recipe_books.erase(player_id)
	_effects.erase(player_id)
	_ability_books.erase(player_id)


func get_player_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_player_entities.keys())
	return ids


func get_player_count() -> int:
	return _player_entities.size()


func get_entity_count() -> int:
	return _entities.size()
