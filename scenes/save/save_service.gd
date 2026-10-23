class_name SaveService
extends Node
## Save do mundo (ADR-019). SÓ o host guarda: o progresso de cada personagem que jogou aqui
## (inclusive dos amigos, como no coop do Stardew Valley) e o estado da região (estruturas
## colocadas, pontos de coleta). Quem entra no mundo de outro não guarda nada.
##
## Quando grava: quando um jogador sai, ao fechar a janela e a cada `AUTOSAVE_TIME`. (Parar o
## jogo pelo editor da Godot encerra o processo na hora: perde no máximo esse intervalo.)
## Itens no chão e criaturas não são guardados: o mundo volta com criaturas novas.

const DEFAULT_PATH := "user://saves/world.json"
const AUTOSAVE_TIME := 30.0
## Limite de estruturas lidas do arquivo (bem acima do legítimo; só barra lixo).
const MAX_STRUCTURES := 1000

## Arquivo do save; vazio = só na memória. Testes e ferramentas de captura trocam o padrão para não
## mexer no mundo de quem joga.
static var default_path := DEFAULT_PATH

var _path := ""
var _save: WorldSave
var _session: GameSession
var _spawner: EntitySpawner
## Regiões carregadas agora (no coop, uma por região com jogador).
var _loaded: Array[Region] = []
var _network: Network
var _items: ItemDatabase
var _skills: DataCatalog
var _recipes: RecipeDatabase
var _structures: DataCatalog


## Host: abre o mundo. Sem `path`, o save fica só na memória (regiões deixadas e quem sai e
## volta na mesma partida), sem ler nem gravar arquivo. Depois, `region_loaded` para cada região
## carregada (antes de os jogadores chegarem nela).
func setup(path: String, session: GameSession, spawner: EntitySpawner, network: Network,
		items: ItemDatabase, skills: DataCatalog, recipes: RecipeDatabase,
		structures: DataCatalog) -> void:
	if not multiplayer.is_server():
		return
	_session = session
	_spawner = spawner
	_network = network
	_items = items
	_skills = skills
	_recipes = recipes
	_structures = structures
	network.player_left.connect(_on_player_left)
	_save = WorldSave.load_file(path) if not path.is_empty() else WorldSave.new()
	if _save == null:
		push_warning("[save] %s ilegível e não pôde ser guardado de lado: nada será gravado" % path)
		_save = WorldSave.new()
		return
	_path = path
	if _path.is_empty():
		return
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_TIME
	timer.timeout.connect(save_now)
	add_child(timer)
	timer.start()


## Host com o mundo aberto (com ou sem arquivo).
func is_enabled() -> bool:
	return _save != null


## Região onde o jogador estava ao sair ("" se não houver; quem chama confere no catálogo).
func region_of(player_id: int) -> StringName:
	var record: Variant = _save.players.get(_network.player_key(player_id)) if is_enabled() else null
	var region_id: Variant = record.get("region") if record is Dictionary else null
	return StringName(region_id) if region_id is String else &""


## A região acabou de ser carregada: volta ao estado guardado (estruturas, pontos de coleta).
func region_loaded(region: Region) -> void:
	_loaded.append(region)
	if is_enabled():
		_restore_region(region, _save.regions.get(String(region.region_id)))


## A região vai ser liberada (ninguém mais nela): o estado dela fica guardado na memória.
func region_unloading(region: Region) -> void:
	_loaded.erase(region)
	if is_enabled():
		_save.regions[String(region.region_id)] = _capture_region(region)


## Host: o personagem acabou de ser criado. Quem já jogou neste mundo volta como estava
## (retorna true); quem é novo fica como está (false).
func restore_player(character: Character) -> bool:
	if not is_enabled():
		return false
	var record: Variant = _save.players.get(_network.player_key(character.player_id))
	if record == null:
		return false
	var player_id := character.player_id
	var appearances := _session.get_appearances(player_id)
	# Coleção antes do inventário: o que o personagem tem se junta a ela (saves de antes da G3c).
	appearances.replicate(record.get("appearances") if record is Dictionary else null, _items)
	var health := CharacterRecord.restore(record, _session.get_inventory(player_id),
		_session.get_equipment(player_id), _session.get_skills(player_id),
		_session.get_wallet(player_id), _session.get_recipe_book(player_id), _skills, _items,
		_recipes)
	if health > 0:
		character.health.set_current(health)
	if record is Dictionary:  # o resto conferido como dado não confiável
		_session.get_effects(player_id).replicate(record.get("effects"), EffectDatabase.shared())
		_session.get_ability_book(player_id).replicate(record.get("abilities"),
			AbilityDatabase.shared())
		EquipmentRules.restore_looks(record.get("looks"), _session.get_equipment(player_id),
			appearances)
	return true


func save_now() -> Error:
	if not is_enabled():
		return OK
	for player_id in _session.get_player_ids():
		_remember(player_id)
	for region in _loaded:
		_save.regions[String(region.region_id)] = _capture_region(region)
	if _path.is_empty():
		return OK
	var error := _save.save_file(_path)
	if error != OK:
		push_warning("[save] não foi possível gravar %s: %s" % [_path, error_string(error)])
	return error


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


## Guarda o personagem na memória (vai para o arquivo no próximo `save_now`).
func _remember(player_id: int) -> void:
	var key := _network.player_key(player_id)
	var character := _session.get_player_entity(player_id) as Character
	if key.is_empty() or character == null or _session.get_inventory(player_id) == null:
		return
	var health := character.health
	var record := CharacterRecord.capture(_session.get_inventory(player_id),
		_session.get_equipment(player_id), _session.get_skills(player_id),
		_session.get_wallet(player_id), _session.get_recipe_book(player_id),
		health.max_health if health.is_dead() else health.current)
	record["effects"] = _session.get_effects(player_id).snapshot()
	record["abilities"] = _session.get_ability_book(player_id).snapshot()
	record["appearances"] = Array(_session.get_appearances(player_id).snapshot())
	record["looks"] = Array(_session.get_equipment(player_id).looks())
	var region := Region.of(character)
	if region:
		record["region"] = String(region.region_id)
	_save.players[key] = record


## Antes de o personagem sumir da sessão (a chave ainda é conhecida, ver Network).
func _on_player_left(player_id: int) -> void:
	_remember(player_id)
	save_now()


func _capture_region(region: Region) -> Dictionary:
	var nodes := {}
	var placed := []
	for node in region.entities.get_children():
		if node is ResourceNode:
			nodes[String(node.name)] = node.save_state()
		elif node is Structure and not node.is_queued_for_deletion():
			placed.append([String(node.data.id), node.position.x, node.position.y])
	return {"resource_nodes": nodes, "structures": placed}


## Estado lido do arquivo (não confiável): nós da região só por nome existente, estruturas só
## de tipos conhecidos e em coordenadas válidas.
func _restore_region(region: Region, state: Variant) -> void:
	if not state is Dictionary:
		return
	var nodes: Variant = state.get("resource_nodes")
	if nodes is Dictionary:
		for node in region.entities.get_children():
			if node is ResourceNode and nodes.has(String(node.name)):
				node.load_state(nodes[String(node.name)])
	var placed: Variant = state.get("structures")
	if not placed is Array:
		return
	for entry: Variant in (placed as Array).slice(0, MAX_STRUCTURES):
		if not (entry is Array and entry.size() == 3 and entry[0] is String):
			continue
		var structure := _structures.get_entry(StringName(entry[0])) as StructureData
		var at := Vector2(SaveValues.to_float(entry[1], -NetRules.MAX_COORDINATE,
			NetRules.MAX_COORDINATE, NAN), SaveValues.to_float(entry[2],
			-NetRules.MAX_COORDINATE, NetRules.MAX_COORDINATE, NAN))
		if structure and NetRules.is_valid_vector(at):
			_spawner.spawn_structure(region, structure, at)
