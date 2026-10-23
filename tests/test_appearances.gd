extends TestCase
## Cosméticos e transmog (G3c, ADR-030): todo equipamento que passa pelas mãos do jogador vira
## aparência colecionada para sempre; cada espaço mostra o próprio item, outra aparência do mesmo
## tipo (mesmo vazio) ou nada. Atributos vêm do que está vestido; auras, do que aparece. O host
## decide; a coleção e as aparências vão no save e pela rede.

const PORT := 24800
const SAVE_DIR := "user://test_saves/"
const SAVE_PATH := SAVE_DIR + "appearances_world.json"
const CROWN := &"king_slime_crown"
const HELMET := &"copper_helmet"


func test_anything_equipment_that_passes_through_is_collected_forever() -> void:
	var session := GameSession.new(ItemDatabase.load_all())
	session.add_player(1, 1)
	var inventory := session.get_inventory(1)
	var collection := session.get_appearances(1)
	inventory.add(&"wood", 5)
	inventory.add(CROWN, 1)
	check(collection.has(CROWN) and not collection.has(&"wood"), "só equipamento entra na coleção")
	inventory.remove(CROWN, 1)
	check(collection.has(CROWN), "vendida ou destruída: continua colecionada")
	EquipmentRules.give_equipped(session.get_equipment(1),
		session.get_equipment(1).data_of(HELMET))
	check(collection.all() == [HELMET, CROWN], "vestido direto também conta (em ordem)")
	inventory.set_held(&"sword", 1)
	check(collection.has(&"sword"), "na mão também")


func test_look_rules() -> void:
	var items := ItemDatabase.load_all()
	var equipment := Equipment.new(EquipmentLayout.load_default(), items)
	var collection := AppearanceCollection.new()
	var head := equipment.index_of_type(EquipmentData.Slot.HEAD)
	var chest := equipment.index_of_type(EquipmentData.Slot.CHEST)
	check(not EquipmentRules.set_look(equipment, collection, head, CROWN), "sem colecionar: não")
	collection.collect(CROWN)
	check(not EquipmentRules.set_look(equipment, collection, chest, CROWN), "tipo errado: não")
	check(not EquipmentRules.set_look(equipment, collection, 99, CROWN), "espaço inválido: não")
	check(not EquipmentRules.set_look(equipment, collection, head, &"wood"), "não equipamento: não")
	check(EquipmentRules.set_look(equipment, collection, head, CROWN), "cabeça vazia: pode")
	check(equipment.shown(head).id == CROWN and equipment.item(head) == null,
		"aparece a coroa sem nada vestido")
	EquipmentRules.give_equipped(equipment, items.get_item(HELMET) as EquipmentData)
	check(equipment.shown(head).id == CROWN and equipment.item(head).id == HELMET,
		"veste o capacete, aparece a coroa")
	check(EquipmentRules.set_look(equipment, collection, head, Equipment.HIDDEN_LOOK)
		and equipment.shown(head) == null, "escondida: nada aparece")
	check(EquipmentRules.set_look(equipment, collection, head, Equipment.OWN_LOOK)
		and equipment.shown(head).id == HELMET, "a própria: o capacete")


## Atributos do que está vestido, aura do que aparece (a da coroa com qualquer capacete, ou sem
## nenhum); escondida apaga mesmo com a coroa vestida.
func test_aura_follows_the_appearance() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var player := session.get_player_entity(1) as Character
	var equipment := session.get_equipment(1)
	var head := equipment.index_of_type(EquipmentData.Slot.HEAD)
	var crown := equipment.data_of(CROWN)
	var helmet := equipment.data_of(HELMET)
	session.get_inventory(1).add(CROWN, 1)
	session.get_inventory(1).remove(CROWN, 1)
	var collection := session.get_appearances(1)
	check(EquipmentRules.set_look(equipment, collection, head, CROWN), "escolhe a coroa")
	check(player.auras == [crown.aura], "aura da coroa sem nada na cabeça")
	EquipmentRules.give_equipped(equipment, helmet)
	check(player.auras == [crown.aura], "com o capacete de cobre também")
	check(player.bonuses.defense == helmet.bonuses.defense, "atributos do capacete, não da coroa")
	equipment.replicate_slot(head, CROWN)
	EquipmentRules.set_look(equipment, collection, head, Equipment.HIDDEN_LOOK)
	check(player.auras.is_empty(), "coroa vestida e escondida: sem aura")
	EquipmentRules.set_look(equipment, collection, head, Equipment.OWN_LOOK)
	check(player.auras == [crown.aura], "a própria: aura de volta")


func test_collection_and_looks_are_saved() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var game := start_game(SAVE_PATH)
	var session := game.session as GameSession
	var equipment := session.get_equipment(1)
	var head := equipment.index_of_type(EquipmentData.Slot.HEAD)
	session.get_inventory(1).add(CROWN, 1)
	session.get_inventory(1).remove(CROWN, 1)
	EquipmentRules.set_look(equipment, session.get_appearances(1), head, CROWN)
	check((game.saves as SaveService).save_now() == OK, "grava")
	game.free()

	game = start_game(SAVE_PATH)
	session = game.session as GameSession
	check(session.get_appearances(1).has(CROWN), "a coleção volta (sem a coroa no inventário)")
	check(session.get_equipment(1).look(head) == CROWN, "a aparência escolhida volta")
	check((session.get_player_entity(1) as Character).auras.size() == 1, "com a aura")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Save de antes da G3c (sem coleção) coleciona o que o personagem tem; lixo é ignorado.
func test_old_and_garbage_saves() -> void:
	var items := ItemDatabase.load_all()
	var collection := AppearanceCollection.new()
	collection.replicate(["king_slime_crown", "wood", "nao_existe", 7, null], items)
	check(collection.all() == [CROWN], "só equipamento que existe")
	collection.replicate("lixo", items)
	check(collection.all().is_empty(), "lixo: coleção vazia")
	var equipment := Equipment.new(EquipmentLayout.load_default(), items)
	collection.collect(CROWN)
	EquipmentRules.restore_looks([&"x", "wood", "king_slime_crown", "-", "nao_existe", 3],
		equipment, collection)
	var head := equipment.index_of_type(EquipmentData.Slot.HEAD)
	for index in equipment.size():
		var expected := CROWN if index == head else &""
		if index == equipment.index_of_type(EquipmentData.Slot.CHEST):
			expected = Equipment.HIDDEN_LOOK
		check(equipment.look(index) == expected, "espaço %d: %s" % [index, expected])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var save := WorldSave.new()
	save.players[Network.HOST_KEY] = {"inventory": [["king_slime_crown", 1]], "equipment": [],
		"health": 50}
	check(save.save_file(SAVE_PATH) == OK, "grava um save antigo")
	var game := start_game(SAVE_PATH)
	check((game.session as GameSession).get_appearances(1).has(CROWN),
		"save antigo: a coroa do inventário vira aparência")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Coop: o cliente pede a aparência; o host confere com a coleção OFICIAL (pedido de aparência não
## colecionada é recusado); todos veem a aura; a coleção chega ao dono.
func test_client_chooses_look_through_host() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(connected, "cliente conectou")
	calm_monsters(host)
	await physics_frames(10)
	var client_id: int = client.local_player_id()
	var host_session := host.session as GameSession
	var client_session := client.session as GameSession
	var player_state: PlayerStateSync = client.player_state
	var head := host_session.get_equipment(client_id).index_of_type(EquipmentData.Slot.HEAD)

	player_state.request_set_look(head, CROWN)  # forjado: não colecionada
	player_state._request(&"_set_look_requested", [99, Equipment.HIDDEN_LOOK])  # espaço inválido
	await physics_frames(10)
	check(host_session.get_equipment(client_id).look(head) == Equipment.OWN_LOOK,
		"sem colecionar: o host recusa")

	host_session.get_inventory(client_id).add(CROWN, 1)
	host_session.get_inventory(client_id).remove(CROWN, 1)
	var client_inventory := client_session.get_inventory(client_id)
	var client_collection := client_session.get_appearances(client_id)
	check(await wait_until(func() -> bool:
		return client_collection.has(CROWN) and client_inventory.count(CROWN) == 0, 60),
		"a coleção chega ao dono")
	player_state.request_set_look(head, CROWN)
	var on_host := host_session.get_player_entity(client_id) as Character
	var on_client := client_session.get_player_entity(client_id) as Character
	check(await wait_until(func() -> bool:
		return on_host.auras.size() == 1 and on_client.auras.size() == 1, 60),
		"host e cliente veem a aura da coroa")
	var host_seen := client_session.get_equipment(host.local_player_id())
	check(host_seen.look(head) == Equipment.OWN_LOOK, "a aparência do host não mudou")


## Tela: botão direito num espaço lista a própria, as colecionadas do tipo e esconder; escolher
## pede ao host e o espaço ganha o selo; aviso de aparência nova.
func test_look_menu_in_the_equipment_column() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var equipment := session.get_equipment(1)
	var head := equipment.index_of_type(EquipmentData.Slot.HEAD)
	var panel: InventoryPanel = game.get_node("UI/InventoryPanel")
	panel.set_open(true)
	var column := panel.find_children("*", "EquipmentColumn", true, false)[0] as EquipmentColumn
	var slot := panel.find_children("*", "EquipmentSlot", true, false)[head] as EquipmentSlot
	check(column.look_choices(head).map(func(choice: Array) -> StringName: return choice[1])
		== [Equipment.HIDDEN_LOOK], "sem coleção: só esconder")

	var feedback := game.get_node("PlayerFeedback") as PlayerFeedback
	var queued_before: int = feedback._queue.size()
	session.get_inventory(1).add(CROWN, 1)
	check(feedback._queue.size() > queued_before, "aviso de aparência nova")
	session.get_inventory(1).add(HELMET, 1)
	var ids: Array = column.look_choices(head).map(func(choice: Array) -> StringName:
		return choice[1])
	check(ids == [HELMET, CROWN, Equipment.HIDDEN_LOOK], "capacete, coroa e esconder (%s)" % [ids])
	check(column.look_choices(equipment.index_of_type(EquipmentData.Slot.CHEST)).size() == 1,
		"no peito, a coroa não aparece")

	var badge := slot.get_child(slot.get_child_count() - 1) as Control
	check(not badge.visible, "aparência própria: sem selo")
	column._open_look_menu(head)
	var menu := panel._look_menu
	check(menu.visible and menu.choice_count() == 3, "o menu abre com 3 escolhas")
	(menu._column.get_child(1) as Button).pressed.emit()  # a coroa
	check(not menu.visible and equipment.look(head) == CROWN, "escolheu a coroa")
	check(badge.visible and slot.tooltip_text.contains(
		Texts.format(&"EQUIP_LOOK_SHOWN", [equipment.data_of(CROWN).get_display_name()])),
		"selo e dica mostram a coroa")
	check(column.look_choices(head)[0][1] == Equipment.OWN_LOOK, "agora dá para voltar à própria")
