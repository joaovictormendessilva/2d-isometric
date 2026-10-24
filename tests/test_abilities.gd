extends TestCase
## Habilidades (G2a, ADR-026): aprendidas por tomo e postas nas teclas 1–4; lançar decidido pelo
## host com recarga; o projétil acerta o primeiro inimigo no caminho; a explosão (G2d) fere todos
## na área mirada depois do aviso no chão; coop e save.

const PORT := 24780
const BOLT := &"arcane_bolt"
const TOME := &"tome_arcane_bolt"
const BLAST := &"arcane_blast"
const SAVE_DIR := "user://test_saves/"
const SAVE_PATH := SAVE_DIR + "abilities_world.json"


func test_ability_data_is_consistent() -> void:
	var abilities := AbilityDatabase.shared()
	check(abilities.get_ability(BOLT) != null, "projétil arcano existe")
	for entry in abilities.entries():
		var ability := entry as AbilityData
		check(ability.icon != null, "%s tem ícone" % ability.id)
		check(ability.cooldown > 0.0 and ability.cooldown <= Cooldowns.MAX_SECONDS,
			"%s: recarga dentro dos limites" % ability.id)
		check(ability.damage > 0, "%s: tem dano" % ability.id)
		match ability.shape:
			AbilityData.Shape.PROJECTILE:
				var flight := ability.projectile
				check(flight != null and flight.speed > 0.0 and flight.hit_radius > 0.0
					and flight.max_range > 0.0, "%s: voa" % ability.id)
			AbilityData.Shape.AREA:
				check(ability.max_range > 0.0 and ability.area_radius > 0.0 and ability.area_delay > 0.0,
					"%s: área com aviso" % ability.id)
		check(_tome_for(ability.id) != null, "%s: algum tomo à venda ensina" % ability.id)
	var tome := ItemDatabase.load_all().get_item(TOME) as ConsumableData
	check(tome != null and tome.teaches_ability.id == BOLT, "o tomo ensina o projétil")
	var merchant := load("res://data/npcs/merchant.tres") as NpcData
	check(merchant.sells(TOME), "o mercador vende o tomo")


func test_book_learns_into_free_slots_and_swaps() -> void:
	var bolt := AbilityDatabase.shared().get_ability(BOLT)
	var book := AbilityBook.new()
	check(book.learn(bolt) and book.in_slot(0) == bolt, "aprendeu e já foi para a tecla 1")
	check(not book.learn(bolt), "aprender de novo não muda nada")
	check(book.set_slot(2, bolt) and book.in_slot(2) == bolt and book.in_slot(0) == null,
		"mudar de tecla move (troca com a vazia)")
	check(not book.set_slot(9, bolt) and not book.set_slot(-1, bolt), "espaço fora: recusa")
	var unknown := AbilityData.new()
	unknown.id = &"nao_aprendida"
	check(not book.set_slot(1, unknown), "habilidade não aprendida não entra")

	var copy := AbilityBook.new()
	copy.replicate(JSON.parse_string(JSON.stringify(book.snapshot())), AbilityDatabase.shared())
	check(copy.knows(BOLT) and copy.in_slot(2) == bolt, "cópia igual (rede/save)")
	var bolt_id := String(BOLT)
	copy.replicate({"learned": ["nao_existe", 7, bolt_id], "slots": [bolt_id, bolt_id, "x", 3, "y"]},
		AbilityDatabase.shared())
	check(copy.learned().size() == 1 and copy.in_slot(0) == bolt and copy.in_slot(1) == null,
		"lixo ignorado: só a habilidade que existe, sem repetir espaço")
	copy.replicate({"learned": [], "slots": [bolt_id]}, AbilityDatabase.shared())
	check(copy.in_slot(0) == null, "espaço com habilidade não aprendida fica vazio")


func test_cast_rules_and_cooldown() -> void:
	var bolt := AbilityDatabase.shared().get_ability(BOLT)
	var book := AbilityBook.new()
	check(AbilityRules.check_cast(book, 0, true, 0.0) == AbilityRules.Check.EMPTY_SLOT, "tecla vazia")
	book.learn(bolt)
	check(AbilityRules.check_cast(book, 0, false, 0.0) == AbilityRules.Check.CANNOT_ACT, "ocupado")
	check(AbilityRules.cast(book, 0, true, 10.0) == bolt, "lançou")
	check(AbilityRules.cast(book, 0, true, 10.5) == null
		and AbilityRules.check_cast(book, 0, true, 10.5) == AbilityRules.Check.COOLING_DOWN,
		"recarregando")
	check(AbilityRules.check_cast(book, 0, true, 10.0 + bolt.cooldown) == AbilityRules.Check.OK,
		"depois da recarga, pode")


## Jogo sozinho: lê o tomo (aprende, tecla 1), lança no slime à frente e acerta só ele.
func test_tome_teaches_and_bolt_hits_the_first_monster() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var inventory := session.get_inventory(1)
	var player := session.get_player_entity(1) as Character
	var state: PlayerStateSync = game.player_state
	var abilities: AbilitySync = game.abilities
	var book := session.get_ability_book(1)
	var refusals := []
	abilities.cast_refused.connect(refusals.append)
	abilities.request_cast(1, 0, Vector2.RIGHT)
	check(refusals == [AbilityRules.Check.EMPTY_SLOT], "sem habilidade: avisa")
	inventory.add(TOME, 2)
	state.request_use(slot_of(inventory, TOME))
	check(book.knows(BOLT) and book.in_slot(0) != null and inventory.count(TOME) == 1,
		"leu um tomo: aprendeu e foi para a tecla 1")
	var use_refusals := []
	state.use_refused.connect(use_refusals.append)
	state.request_use(slot_of(inventory, TOME))
	check(use_refusals == [ConsumableRules.Check.ALREADY_KNOWN] and inventory.count(TOME) == 1,
		"segundo tomo: já conhece, não gasta")

	var bolt := book.in_slot(0)
	var monsters := _monsters(game)
	var near := monsters[0]
	near.position = player.position + Iso.ground_to_screen(Vector2(60, 0))
	near.reset_physics_interpolation()
	var far := monsters[1]
	far.position = player.position + Iso.ground_to_screen(Vector2(110, 0))
	far.reset_physics_interpolation()
	await physics_frames(2)
	abilities.request_cast(1, 0, Vector2.RIGHT)
	check(player.caster.is_casting(), "começou a preparar")
	abilities.request_cast(1, 0, Vector2.RIGHT)
	check(refusals.back() == AbilityRules.Check.COOLING_DOWN, "recarga: avisa")
	var flight := roundi((bolt.cast_time + 60.0 / bolt.projectile.speed) * 60.0) + 6
	check(await wait_until(func() -> bool: return near.health.current < near.health.max_health,
		flight), "acertou o primeiro slime")
	await physics_frames(roundi(60.0 / bolt.projectile.speed * 60.0) + 4)
	check(far.health.current == far.health.max_health, "o de trás não levou (parou no primeiro)")
	check(near.health.max_health - near.health.current == bolt.damage, "dano do projétil")


## Saiu do alcance sem acertar ninguém: some.
func test_bolt_vanishes_at_max_range() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var book := session.get_ability_book(1)
	var bolt := AbilityDatabase.shared().get_ability(BOLT)
	book.learn(bolt)
	(game.abilities as AbilitySync).request_cast(1, 0, Vector2.UP)
	var region: Region = game.region
	var flying := func() -> int:
		return region.entities.get_children().filter(func(n: Node) -> bool:
			return n is Projectile and not n.is_queued_for_deletion()).size()
	await physics_frames(roundi(bolt.cast_time * 60.0) + 2)
	check(flying.call() == 1, "o projétil voa")
	await physics_frames(roundi(bolt.projectile.max_range / bolt.projectile.speed * 60.0) + 4)
	check(flying.call() == 0, "chegou ao alcance e sumiu")


func test_abilities_are_saved() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var game := start_game(SAVE_PATH)
	var bolt := AbilityDatabase.shared().get_ability(BOLT)
	var book := (game.session as GameSession).get_ability_book(1)
	book.learn(bolt)
	book.set_slot(3, bolt)
	check((game.saves as SaveService).save_now() == OK, "grava")
	game.free()
	game = start_game(SAVE_PATH)
	book = (game.session as GameSession).get_ability_book(1)
	check(book.knows(BOLT) and book.in_slot(3) == bolt, "volta aprendida e na tecla 4")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Coop: o cliente lê o tomo e lança; o host confere e o projétil DELE fere o slime; o host vê o
## lançamento do cliente. Pedidos forjados (espaço inválido, sem aprender) não lançam nada.
func test_client_casts_through_host() -> void:
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
	var on_host := host_session.get_player_entity(client_id) as Character
	var abilities: AbilitySync = client.abilities

	abilities._request(&"_cast_requested", [0, Vector2.RIGHT])  # forjado: nada aprendido
	abilities._request(&"_set_slot_requested", [0, BOLT])  # forjado: não aprendida
	await physics_frames(10)
	check(not on_host.caster.is_casting() and host_session.get_ability_book(client_id).in_slot(0) == null,
		"sem aprender: o host não lança nem equipa")

	host_session.get_inventory(client_id).add(TOME, 1)
	check(await wait_until(func() -> bool:
		return client_session.get_inventory(client_id).count(TOME) == 1, 30), "tomo chegou")
	(client.player_state as PlayerStateSync).request_use(
		slot_of(client_session.get_inventory(client_id), TOME))
	var client_book := client_session.get_ability_book(client_id)
	check(await wait_until(func() -> bool: return client_book.in_slot(0) != null, 30),
		"o livro aprendido chegou ao cliente")

	var slime := first_monster(host)
	slime.position = on_host.position + Iso.ground_to_screen(Vector2(50, 0))
	slime.reset_physics_interpolation()
	await physics_frames(10)  # o cliente vê o slime no lugar novo
	abilities._request(&"_cast_requested", [7, Vector2.RIGHT])  # forjado: espaço inválido
	await physics_frames(5)
	check(not on_host.caster.is_casting(), "espaço inválido: nada")
	abilities.request_cast(client_id, 0, Vector2.RIGHT)
	var on_client := client_session.get_player_entity(client_id) as Character
	check(on_client.caster.is_casting(), "o cliente lança na hora (previsão)")
	check(await wait_until(func() -> bool: return slime.health.current < slime.health.max_health, 90),
		"o projétil do host feriu o slime")
	check(not client_book.cooldowns.is_ready(BOLT, NetRules.now()), "a recarga está no cliente")

	# Explosão (G2d) com mira forjada longe demais: o host a põe no alcance máximo.
	var blast := AbilityDatabase.shared().get_ability(BLAST)
	host_session.get_ability_book(client_id).learn(blast)
	check(await wait_until(func() -> bool: return client_book.in_slot(1) == blast, 30),
		"a explosão chegou à tecla 2 do cliente")
	abilities._request(&"_cast_requested", [1, Vector2(5000, 0)])
	check(await wait_until(func() -> bool: return not _area_blasts(host).is_empty(), 60),
		"o host lançou a explosão")
	var landing: Vector2 = _area_blasts(host)[0].position
	check(Iso.ground_distance(landing, on_host.position) <= blast.max_range + 2.0,
		"mira forjada: limitada ao alcance")


## G2b: a barra mostra a habilidade da tecla e a recarga; o botão direito troca de tecla.
func test_ability_bar_shows_slots_and_moves_abilities() -> void:
	var game := start_game()
	calm_monsters(game)
	var bar: AbilityBar = game.find_children("*", "AbilityBar", true, false)[0]
	var book := (game.session as GameSession).get_ability_book(1)
	var bolt := AbilityDatabase.shared().get_ability(BOLT)
	check(bar._slots.size() == AbilityBook.SLOTS and bar._slots.all(
		func(slot: AbilityBar.Slot) -> bool: return slot.ability == null), "4 teclas vazias")
	bar._open_menu(1)
	check(not bar._menu.visible, "nada aprendido: sem menu")
	book.learn(bolt)
	check(bar._slots[0].ability == bolt and bar._slots[0].tooltip_text.contains(
		bolt.get_display_name()), "aprendeu: aparece na tecla 1, com dica")
	(game.abilities as AbilitySync).request_cast(1, 0, Vector2.UP)
	await physics_frames(2)
	check(bar._slots[0].cooldown_left > 0.0 and bar._slots[0]._seconds.text != "",
		"recarga contando na tecla")
	bar._open_menu(2)
	check(bar._menu.visible and bar._menu.choice_count() == 1, "tecla 3: oferece o projétil")
	(bar._menu._column.get_child(0) as Button).pressed.emit()
	check(book.in_slot(2) == bolt and book.in_slot(0) == null and bar._slots[2].ability == bolt,
		"mudou para a tecla 3")
	bar._open_menu(2)
	check(bar._menu.choice_count() == 1, "na própria tecla: só Esvaziar")
	(bar._menu._column.get_child(0) as Button).pressed.emit()
	check(book.in_slot(2) == null and book.knows(BOLT), "esvaziou (continua aprendida)")


## Fim da recarga num quadro que cai a microssegundos do zero: o último segundo some da tecla
## (antes, 0,000005 contava como "igual" a 0 e o "1" ficava parado).
func test_ability_bar_clears_the_last_second() -> void:
	var slot := AbilityBar.Slot.new(0, "1")
	var blast := AbilityDatabase.shared().get_ability(BLAST)
	slot.show_ability(blast, 0.000005)
	check(slot._seconds.text == "1", "falta um instante: mostra 1")
	slot.show_ability(blast, 0.0)
	check(slot._seconds.text == "" and slot._shade.size.y == 0.0, "recarga acabou: tecla limpa")
	slot.free()


## G2d: a explosão cai no ponto mirado depois do aviso e fere todos dentro do raio, só eles.
func test_blast_hits_everyone_in_the_area_after_the_warning() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var player := session.get_player_entity(1) as Character
	var blast := AbilityDatabase.shared().get_ability(BLAST)
	session.get_ability_book(1).learn(blast)
	var aim := Vector2(80, 0)
	var center := player.position + Iso.ground_to_screen(aim)
	var monsters := _monsters(game)
	var inside := monsters[0]
	var also_inside := monsters[1]
	var outside := monsters[2]
	_place(inside, center + Iso.ground_to_screen(Vector2(0, 8)))
	_place(also_inside, center + Iso.ground_to_screen(Vector2(-10, -6)))
	_place(outside, center + Iso.ground_to_screen(Vector2(blast.area_radius + 30.0, 0)))
	await physics_frames(2)
	(game.abilities as AbilitySync).request_cast(1, 0, aim)
	await physics_frames(roundi((blast.cast_time + blast.area_delay * 0.5) * 60.0))
	var blasts := _area_blasts(game)
	check(blasts.size() == 1 and blasts[0].position.distance_to(center) <= 1.0,
		"aviso no chão no ponto mirado")
	check(inside.health.current == inside.health.max_health, "durante o aviso: ninguém levou")
	await physics_frames(roundi(blast.area_delay * 0.5 * 60.0) + 4)
	check(inside.health.max_health - inside.health.current == blast.damage
		and also_inside.health.max_health - also_inside.health.current == blast.damage,
		"impacto: os dois de dentro levaram o dano da explosão")
	check(outside.health.current == outside.health.max_health, "o de fora não levou")
	await physics_frames(30)
	check(_area_blasts(game).is_empty(), "a onda sumiu e o aviso saiu da região")


## Mirar além do alcance: a explosão cai no limite dele, na mesma direção.
func test_blast_lands_at_max_range_when_aimed_too_far() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var player := session.get_player_entity(1) as Character
	var blast := AbilityDatabase.shared().get_ability(BLAST)
	session.get_ability_book(1).learn(blast)
	(game.abilities as AbilitySync).request_cast(1, 0, Vector2(0, -5000))
	await physics_frames(roundi(blast.cast_time * 60.0) + 2)
	var blasts := _area_blasts(game)
	var expected := player.position + Iso.ground_to_screen(Vector2(0, -blast.max_range))
	check(blasts.size() == 1 and blasts[0].position.distance_to(expected) <= 4.0,
		"caiu no alcance máximo")


func _place(monster: Monster, at: Vector2) -> void:
	monster.position = at
	monster.reset_physics_interpolation()


func _area_blasts(game: Node) -> Array[Node]:
	return (game.region as Region).ground_effects.get_children().filter(func(n: Node) -> bool:
		return n is AreaBlast and not n.is_queued_for_deletion())


func _tome_for(ability_id: StringName) -> ConsumableData:
	var merchant := load("res://data/npcs/merchant.tres") as NpcData
	for entry in ItemDatabase.load_all().entries():
		var tome := entry as ConsumableData
		if tome and tome.teaches_ability and tome.teaches_ability.id == ability_id \
				and merchant.sells(tome.id):
			return tome
	return null


func _monsters(game: Node) -> Array[Monster]:
	var found: Array[Monster] = []
	for node in (game.region as Region).entities.get_children():
		if node is Monster:
			found.append(node)
	return found
