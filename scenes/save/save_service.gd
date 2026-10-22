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

## Arquivo do save; vazio = desligado. Testes e ferramentas de captura trocam o padrão para não
## mexer no mundo de quem joga.
static var default_path := DEFAULT_PATH

var _path := ""
var _save: WorldSave
var _session: GameSession
var _spawner: EntitySpawner
var _region: Region
var _network: Network
var _items: ItemDatabase
var _skills: DataCatalog
var _structures: DataCatalog


## Host: lê o save e devolve a região ao estado guardado. Chame antes de criar os jogadores.
func setup(path: String, session: GameSession, spawner: EntitySpawner, region: Region,
		network: Network, items: ItemDatabase, skills: DataCatalog, structures: DataCatalog) -> void:
	if path.is_empty() or not multiplayer.is_server():
		return
	_path = path
	_session = session
	_spawner = spawner
	_region = region
	_network = network
	_items = items
	_skills = skills
	_structures = structures
	_save = WorldSave.load_file(path)
	if _save == null:
		push_warning("[save] %s ilegível e não pôde ser guardado de lado: save desligado" % path)
		return
	_restore_region(_save.regions.get(String(region.region_id)))
	network.player_left.connect(_on_player_left)
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_TIME
	timer.timeout.connect(save_now)
	add_child(timer)
	timer.start()


func is_enabled() -> bool:
	return _save != null


## Host: o personagem acabou de ser criado. Quem já jogou neste mundo volta como estava
## (retorna true); quem é novo fica como está (false).
func restore_player(character: Character) -> bool:
	if not is_enabled():
		return false
	var record: Variant = _save.players.get(_network.player_key(character.player_id))
	if record == null:
		return false
	var player_id := character.player_id
	var health := CharacterRecord.restore(record, _session.get_inventory(player_id),
		_session.get_equipment(player_id), _session.get_skills(player_id), _skills, _items)
	if health > 0:
		character.health.set_current(health)
	return true


func save_now() -> Error:
	if not is_enabled():
		return OK
	for player_id in _session.get_player_ids():
		_remember(player_id)
	_save.regions[String(_region.region_id)] = _capture_region()
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
	_save.players[key] = CharacterRecord.capture(_session.get_inventory(player_id),
		_session.get_equipment(player_id), _session.get_skills(player_id),
		health.max_health if health.is_dead() else health.current)


## Antes de o personagem sumir da sessão (a chave ainda é conhecida, ver Network).
func _on_player_left(player_id: int) -> void:
	_remember(player_id)
	save_now()


func _capture_region() -> Dictionary:
	var nodes := {}
	var placed := []
	for node in _region.entities.get_children():
		if node is ResourceNode:
			nodes[String(node.name)] = node.save_state()
		elif node is Structure and not node.is_queued_for_deletion():
			placed.append([String(node.data.id), node.position.x, node.position.y])
	return {"resource_nodes": nodes, "structures": placed}


## Estado lido do arquivo (não confiável): nós da região só por nome existente, estruturas só
## de tipos conhecidos e em coordenadas válidas.
func _restore_region(state: Variant) -> void:
	if not state is Dictionary:
		return
	var nodes: Variant = state.get("resource_nodes")
	if nodes is Dictionary:
		for node in _region.entities.get_children():
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
			_spawner.spawn_structure(structure, at)
