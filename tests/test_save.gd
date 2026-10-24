extends TestCase
## Save do mundo (ADR-019): o host guarda o progresso de cada personagem (inventário, mão,
## equipamento, experiência, vida) e o estado da região (estruturas, pontos de coleta). O
## arquivo é dado não confiável: lixo é ignorado e arquivo ilegível nunca é sobrescrito.

const SAVE_DIR := "user://test_saves/"
const SAVE_PATH := SAVE_DIR + "world.json"
const PORT := 24710
const OTHER_PROFILE := "user://test_profile_other.cfg"
const SKILLS_DIR := "res://data/skills/"


func test_character_round_trip() -> void:
	var items := ItemDatabase.load_all()
	var skills := DataCatalog.new(SKILLS_DIR)
	var source := _character(items)
	var inventory: Inventory = source[0]
	var equipment: Equipment = source[1]
	var progress: SkillProgress = source[2]
	EquipmentRules.give_equipped(equipment, items.get_item(&"sword"))
	EquipmentRules.give_equipped(equipment, items.get_item(&"wooden_shield"))
	EquipmentRules.give_equipped(equipment, items.get_item(&"simple_backpack"))
	inventory.add(&"wood", 30)
	inventory.set_slot(15, &"copper_ore", 4)  # espaço que só existe com a mochila
	inventory.set_held(&"stone", 3)
	progress.add_xp(&"woodcutting", 120)
	(source[3] as Wallet).add(345)
	(source[4] as RecipeBook).learn(RecipeDatabase.load_all().get_recipe(&"health_potion"))
	var record := CharacterRecord.capture(inventory, equipment, progress, source[3], source[4], 37)
	record = JSON.parse_string(JSON.stringify(record))  # como no arquivo: números viram float

	var loaded := _character(items)
	var health := CharacterRecord.restore(record, loaded[0], loaded[1], loaded[2], loaded[3],
		loaded[4], skills, items, RecipeDatabase.load_all())
	inventory = loaded[0]
	equipment = loaded[1]
	check(health == 37, "vida volta (%d)" % health)
	check(equipment.weapon() and equipment.weapon().id == &"sword", "espada volta à mão")
	check(equipment.off_hand() and equipment.off_hand().id == &"wooden_shield", "escudo volta")
	check(inventory.capacity() == 18, "mochila devolve os espaços (%d)" % inventory.capacity())
	check(inventory.slot_item(15) == &"copper_ore" and inventory.slot_amount(15) == 4,
		"pilha volta ao mesmo espaço")
	check(inventory.count(&"wood") == 30, "madeira volta")
	check(inventory.held_item() == &"stone" and inventory.held_amount() == 3, "mão volta")
	check((loaded[2] as SkillProgress).xp(&"woodcutting") == 120, "experiência volta")
	check((loaded[3] as Wallet).coins() == 345, "moedas voltam")
	check(Array((loaded[4] as RecipeBook).all_learned()) == [&"health_potion"],
		"receita aprendida volta")


func test_bad_character_data_is_ignored() -> void:
	var items := ItemDatabase.load_all()
	var skills := DataCatalog.new(SKILLS_DIR)
	var record := {
		"inventory": [["nao_existe", 5], ["wood", 9999], ["wood", -1], ["wood", 2.5], "lixo",
			["stone", 3], [42, 1], ["wood", "muito"]],
		"held": ["sword", 2],
		"equipment": ["wooden_shield", "sword", "", "", "", "", "magnet_ring", "magnet_ring"],
		"skills": {"inexistente": 50, "mining": "muito", "woodcutting": -5},
		"coins": -20,
		"recipes": ["nao_existe", "stone_axe", 7, "health_potion"],
		"health": 1e300,
	}
	var loaded := _character(items)
	var inventory: Inventory = loaded[0]
	var equipment: Equipment = loaded[1]
	var health := CharacterRecord.restore(record, inventory, equipment, loaded[2], loaded[3],
		loaded[4], skills, items, RecipeDatabase.load_all())
	check(health == 0, "vida absurda vira vida cheia")
	check(inventory.get_counts() == {&"stone": 3} and inventory.slot_item(5) == &"stone",
		"só a pilha válida entra (%s)" % inventory.get_counts())
	check(not inventory.is_holding(), "pilha de espadas (limite 1) não entra na mão")
	check(equipment.weapon() == null and equipment.off_hand() == null,
		"escudo na mão principal e espada na secundária são recusados")
	check(equipment.equipped().size() == 1, "anel repetido é recusado")
	check((loaded[2] as SkillProgress).all_xp().is_empty(), "experiência inválida é ignorada")
	check((loaded[3] as Wallet).coins() == 0, "moedas negativas viram zero")
	check(Array((loaded[4] as RecipeBook).all_learned()) == [&"health_potion"],
		"só a receita que existe e se aprende entra")
	check(CharacterRecord.restore("lixo", inventory, equipment, loaded[2], loaded[3], loaded[4],
		skills, items, RecipeDatabase.load_all()) == 0,
		"registro que não é dicionário não faz nada")


func test_file_round_trip_keeps_backup() -> void:
	_clear_saves()
	var save := WorldSave.new()
	save.players["host"] = {"health": 10}
	save.regions["meadow"] = {"structures": []}
	check(save.save_file(SAVE_PATH) == OK, "grava")
	save.players["host"] = {"health": 20}
	check(save.save_file(SAVE_PATH) == OK, "grava de novo")
	var loaded := WorldSave.load_file(SAVE_PATH)
	check(loaded.players.get("host", {}).get("health") == 20.0, "lê o último")
	check(FileAccess.file_exists(SAVE_PATH + ".bak"), "o anterior fica como .bak")
	check(not FileAccess.file_exists(SAVE_PATH + ".tmp"), "não sobra temporário")


func test_unreadable_file_is_set_aside_not_overwritten() -> void:
	for content in ["{lixo", JSON.stringify({"version": WorldSave.VERSION + 1, "players": {}}),
			JSON.stringify(["não", "é", "save"])]:
		_clear_saves()
		_write(SAVE_PATH, content)
		var loaded := WorldSave.load_file(SAVE_PATH)
		check(loaded.players.is_empty() and loaded.regions.is_empty(), "começa um mundo novo")
		check(not FileAccess.file_exists(SAVE_PATH), "o arquivo ilegível sai do caminho")
		var aside := Array(DirAccess.get_files_at(SAVE_DIR)).filter(
			func(file: String) -> bool: return file.begins_with("world.json.corrupt-"))
		check(aside.size() == 1 and FileAccess.get_file_as_string(SAVE_DIR + aside[0]) == content,
			"e é guardado de lado intacto (%s)" % [aside])
	_clear_saves()


## Sair e voltar: inventário, equipamento, vida, experiência, bancada colocada e árvore esgotada.
func test_game_comes_back_as_it_was() -> void:
	_clear_saves()
	var game := start_game(SAVE_PATH)
	var session: GameSession = game.session
	var items: ItemDatabase = game.items
	var player := session.get_player_entity(1) as Character
	session.get_inventory(1).add(&"wood", 7)
	EquipmentRules.give_equipped(session.get_equipment(1), items.get_item(&"copper_helmet"))
	session.get_skills(1).add_xp(&"mining", 33)
	player.health.set_current(42)
	var tree_node := resource_node(game, &"lumber_tree")
	while not tree_node.is_depleted():
		tree_node.take_charge()
	var tree_name := NodePath(tree_node.name)
	var workbench: StructureData = (game.get_node("EntitySpawner") as EntitySpawner) \
		.structures.get_entry(&"workbench")
	var spot := free_spot_near(player, workbench)
	(game.get_node("EntitySpawner") as EntitySpawner).spawn_structure(game.region, workbench, spot)
	check((game.saves as SaveService).save_now() == OK, "grava")
	game.free()

	game = start_game(SAVE_PATH)
	session = game.session
	player = session.get_player_entity(1) as Character
	var equipment := session.get_equipment(1)
	check(session.get_inventory(1).count(&"wood") == 7, "madeira volta")
	check(equipment.item_of_type(EquipmentData.Slot.HEAD) != null, "elmo volta vestido")
	check(equipment.weapon() != null and equipment.weapon().id == &"sword", "espada continua")
	check(player.health.current == 42 and player.health.max_health > 100,
		"vida volta igual, com o máximo do elmo (%d/%d)" % [player.health.current,
			player.health.max_health])
	check(session.get_skills(1).xp(&"mining") == 33, "experiência volta")
	var tree_again := game.region.entities.get_node(tree_name) as ResourceNode
	check(tree_again.is_depleted(), "árvore continua esgotada")
	var placed := structures(game)
	check(placed.size() == 1 and placed[0].position == spot, "bancada continua no lugar")


## Reabrir o mundo (ou entrar no de outro) não anuncia o que o jogador já tinha: nada de
## "Habilidade aprendida", "Nível 3" ou "Veneno" ao carregar (achado do João, 2026-10-23).
func test_loading_announces_nothing_the_player_already_had() -> void:
	_clear_saves()
	var game := start_game(SAVE_PATH)
	_give_progress(game.session, 1)
	check((game.saves as SaveService).save_now() == OK, "grava")
	game.free()

	game = start_game(SAVE_PATH)
	calm_monsters(game)
	await physics_frames(10)
	check((game.session as GameSession).get_ability_book(1).knows(&"arcane_bolt"), "habilidade volta")
	check(feedback_texts(game).is_empty(), "host reabrindo: nenhum aviso (%s)" % [feedback_texts(game)])
	game.free()

	var host := start_network_game("Host", Network.Role.HOST, PORT, SAVE_PATH)
	calm_monsters(host)
	var client := await _join("Client")
	var client_id: int = client.local_player_id()
	_give_progress(host.session, client_id)
	client.get_parent().free()
	await wait_until(func() -> bool: return (host.session as GameSession).get_player_count() == 1)
	client = await _join("Client2")
	check(await wait_until(func() -> bool:
			return (client.session as GameSession).get_ability_book(client.local_player_id()) \
				.knows(&"arcane_bolt")), "o amigo recebe a habilidade de volta")
	await physics_frames(30)
	check(feedback_texts(client).is_empty(), "amigo voltando: nenhum aviso (%s)" % [feedback_texts(client)])

	var book := (host.session as GameSession).get_ability_book(client.local_player_id())
	book.learn(AbilityDatabase.shared().get_ability(&"arcane_blast"))
	check(await wait_until(func() -> bool: return feedback_texts(client).size() == 1),
		"habilidade nova de verdade avisa")


## Habilidade, experiência para passar de nível e um efeito ativo.
func _give_progress(session: GameSession, player_id: int) -> void:
	session.get_ability_book(player_id).learn(AbilityDatabase.shared().get_ability(&"arcane_bolt"))
	session.get_skills(player_id).add_xp(&"mining", 500)
	var character := session.get_player_entity(player_id) as Character
	character.status_effects.apply(EffectDatabase.shared().get_effect(&"swiftness"), player_id)


func test_new_world_starts_fresh() -> void:
	_clear_saves()
	var game := start_game(SAVE_PATH)
	var equipment := (game.session as GameSession).get_equipment(1)
	check(equipment.weapon() != null, "personagem novo ganha o equipamento inicial")
	check(structures(game).is_empty(), "sem estruturas")
	check(not FileAccess.file_exists(SAVE_PATH), "nada é gravado só por abrir")


## O amigo sai e volta com o mesmo perfil: recebe o próprio personagem. Outro perfil é outro
## personagem. O progresso fica no save do host; o cliente não grava nada.
func test_returning_client_gets_its_character_back() -> void:
	_clear_saves()
	var host := start_network_game("Host", Network.Role.HOST, PORT, SAVE_PATH)
	var client := await _join("Client")
	var client_id: int = client.local_player_id()
	(host.session as GameSession).get_inventory(client_id).add(&"copper_ore", 5)
	client.get_parent().free()
	check(await wait_until(func() -> bool: return (host.session as GameSession).get_player_count() == 1),
		"host percebe a saída")
	check(WorldSave.load_file(SAVE_PATH).players.size() == 2, "saída grava o amigo no save do host")

	client = await _join("Client2")
	client_id = client.local_player_id()
	check((host.session as GameSession).get_inventory(client_id).count(&"copper_ore") == 5,
		"host devolve o personagem do amigo")
	check(await wait_until(func() -> bool:
			return (client.session as GameSession).get_inventory(client_id).count(&"copper_ore") == 5),
		"e o amigo vê os próprios itens")
	client.get_parent().free()
	await wait_until(func() -> bool: return (host.session as GameSession).get_player_count() == 1)

	var own_profile := PlayerProfile.path
	PlayerProfile.path = OTHER_PROFILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OTHER_PROFILE))
	client = await _join("Client3")
	PlayerProfile.path = own_profile
	check((host.session as GameSession).get_inventory(client.local_player_id()).count(&"copper_ore") == 0,
		"outro perfil é outro personagem")


func test_same_player_twice_is_refused() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	await _join("Client")
	var twin := start_network_game("Twin", Network.Role.CLIENT, PORT)  # mesmo perfil
	await physics_frames(120)
	check((host.session as GameSession).get_player_count() == 2, "host recusou o repetido")
	check((twin.session as GameSession).get_player_entity(twin.local_player_id()) == null,
		"repetido não recebeu o mundo")
	check((twin.network as Network).status_text() == Texts.get_text(&"NET_REFUSED_SAME_PLAYER"),
		"repetido vê o motivo (\"%s\")" % (twin.network as Network).status_text())


# --- Auxiliares ------------------------------------------------------------------------------

## Inventário, equipamento e experiência de um personagem novo; o inventário acompanha as
## mochilas como no jogo (EntitySpawner). Referência fraca ao equipamento: a função ligada ao
## sinal dele não pode segurá-lo (ciclo que nunca seria liberado).
func _character(items: ItemDatabase) -> Array:
	var inventory := Inventory.new(Inventory.DEFAULT_SLOTS, items)
	var equipment := Equipment.new(EquipmentLayout.load_default(), items)
	var worn: WeakRef = weakref(equipment)
	equipment.slot_changed.connect(func(_index: int) -> void:
		inventory.resize(Inventory.DEFAULT_SLOTS
			+ StatBonuses.total((worn.get_ref() as Equipment).equipped()).inventory_slots))
	return [inventory, equipment, SkillProgress.new(), Wallet.new(), RecipeBook.new()]


func _join(instance_name: String) -> Node:
	var client := start_network_game(instance_name, Network.Role.CLIENT, PORT)
	var joined := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(joined, "%s entrou" % instance_name)
	await physics_frames(10)
	return client


func _clear_saves() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	for file in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_DIR + file))


static func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
