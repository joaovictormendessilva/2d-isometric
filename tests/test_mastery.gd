extends TestCase
## Maestria por arma (J6a, ADR-038): ferir inimigos com uma arma ou magia dá experiência na
## maestria dela, pelo dano causado de fato; o nível aumenta o dano dela.

const PORT := 24860
const SKILLS_DIR := "res://data/skills/"
const ABILITIES_DIR := "res://data/abilities/"
const SWORD_MASTERY := preload("res://data/skills/sword_mastery.tres")
const ARCANE_BOLT := preload("res://data/abilities/arcane_bolt.tres")


## Toda arma e toda habilidade do jogador treinam uma maestria que está no catálogo (save e rede
## só aceitam ids do catálogo) e tem nome na tabela de textos.
func test_every_weapon_and_ability_trains_a_known_mastery() -> void:
	var skills := DataCatalog.new(SKILLS_DIR)
	var sources: Array[Array] = []
	for item in ItemDatabase.load_all().entries():
		if item is WeaponData:
			sources.append([item.id, (item as WeaponData).attack.mastery])
	for file in DirAccess.get_files_at(ABILITIES_DIR):
		var ability := load(ABILITIES_DIR + file.trim_suffix(".remap")) as AbilityData
		if ability:
			sources.append([ability.id, ability.mastery])
	check(sources.size() >= 5, "há armas e habilidades para conferir")
	for source in sources:
		var mastery := source[1] as MasteryData
		check(mastery != null, "%s treina uma maestria" % source[0])
		if mastery:
			check(skills.get_entry(mastery.id) == mastery, "%s está em data/skills/" % mastery.id)
			check(Texts.get_text(StringName("SKILL_" + String(mastery.id).to_upper()))
				!= "SKILL_" + String(mastery.id).to_upper(), "%s tem nome" % mastery.id)


func test_mastery_level_raises_damage_from_level_two_on() -> void:
	var mastery := SWORD_MASTERY
	check(mastery.scaled_damage(10, 1) == 10, "nível 1: dano da arma")
	check(mastery.damage_bonus_percent(1) == 0, "nível 1: sem bônus")
	check(mastery.scaled_damage(10, mastery.max_level) > 10, "no máximo, mais dano")
	check(mastery.scaled_damage(10, mastery.max_level + 50)
		== mastery.scaled_damage(10, mastery.max_level), "não passa do nível máximo")
	for level in range(1, mastery.max_level):
		check(mastery.scaled_damage(6, level + 1) >= mastery.scaled_damage(6, level),
			"nunca cai ao subir (nível %d)" % level)


## A experiência vem na morte, pelo dano que cada um causou (ferir e deixar curar não rende).
func test_mastery_xp_is_paid_when_the_target_dies() -> void:
	var player := spawn_character(Vector2.ZERO)
	player.skills = SkillProgress.new()
	var slime := spawn_slime(Vector2(20, 0))
	await physics_frames(1)
	var sword := player.attacker.attack
	check(sword.mastery == SWORD_MASTERY, "a espada inicial treina Espada")
	player.request_attack(Vector2.RIGHT)
	await physics_frames(10)
	check(slime.health.current < slime.health.max_health, "acertou")
	check(player.skills.xp(SWORD_MASTERY.id) == 0, "ferir ainda não paga")
	player.strike(slime, DamageInfo.create(999, Vector2.RIGHT, 0, 0, 1), SWORD_MASTERY)
	await physics_frames(1)
	check(player.skills.xp(SWORD_MASTERY.id) == SWORD_MASTERY.xp_for_damage(slime.health.max_health),
		"na morte: experiência = vida do alvo (%d)" % player.skills.xp(SWORD_MASTERY.id))


## Coop: cada um ganha pelo dano que causou, e o total nunca passa da vida do alvo, nem se ele
## se curou no meio da luta.
func test_kill_xp_is_split_by_damage_and_capped_by_health() -> void:
	var ledger := MasteryLedger.new()
	var a := SkillProgress.new()
	var b := SkillProgress.new()
	ledger.record(a, SWORD_MASTERY, 30)
	ledger.record(b, ARCANE_BOLT.mastery, 10)
	ledger.pay_out(100)
	check(a.xp(SWORD_MASTERY.id) == 30 and b.xp(ARCANE_BOLT.mastery.id) == 10, "cada um pela parte dele")
	ledger.record(a, SWORD_MASTERY, 150)
	ledger.record(b, ARCANE_BOLT.mastery, 50)
	ledger.pay_out(100)  # 200 de dano num alvo de 100 de vida: curou no meio
	check(a.xp(SWORD_MASTERY.id) == 30 + 75 and b.xp(ARCANE_BOLT.mastery.id) == 10 + 25,
		"curar não vira experiência: as partes encolhem juntas")
	ledger.pay_out(100)
	check(a.xp(SWORD_MASTERY.id) == 105, "pago uma vez só")


func test_overkill_damage_gives_no_extra_xp() -> void:
	var player := spawn_character(Vector2.ZERO)
	player.skills = SkillProgress.new()
	var slime := spawn_slime(Vector2(20, 0))
	await physics_frames(1)
	slime.health.set_current(3)
	player.request_attack(Vector2.RIGHT)
	await physics_frames(10)
	check(slime.health.is_dead(), "o golpe matou")
	check(player.skills.xp(SWORD_MASTERY.id) == SWORD_MASTERY.xp_for_damage(3),
		"só conta a vida que restava")


func test_higher_mastery_hits_harder() -> void:
	var player := spawn_character(Vector2.ZERO)
	player.skills = SkillProgress.new()
	var level := 10
	player.skills.replicate_xp(SWORD_MASTERY.id, SWORD_MASTERY.xp_for_level(level))
	var slime := spawn_slime(Vector2(20, 0))
	await physics_frames(1)
	var sword := player.attacker.attack
	player.request_attack(Vector2.RIGHT)
	await physics_frames(10)
	var expected := CombatRules.mitigate(SWORD_MASTERY.scaled_damage(sword.damage, level),
		slime.health.defense)
	check(expected > sword.damage, "o nível %d dá mais dano que a arma pura" % level)
	check(slime.health.max_health - slime.health.current == expected,
		"dano com o bônus da maestria (%d)" % (slime.health.max_health - slime.health.current))


## Magias: o projétil leva a maestria de quem lançou, e a experiência vai para ela, não para a
## arma na mão. No jogo inteiro (o projétil voa na região), com a experiência da sessão.
func test_spell_trains_its_own_mastery() -> void:
	var game := start_game()
	calm_monsters(game)
	var player := (game.session as GameSession).get_player_entity(1) as Character
	var slime := first_monster(game)
	slime.position = player.position + Iso.ground_to_screen(Vector2(40, 0))
	slime.reset_physics_interpolation()
	await physics_frames(2)
	check(player.skills == (game.session as GameSession).get_skills(1), "experiência da sessão")
	slime.health.set_current(1)  # o orbe mata
	check(player.request_cast(ARCANE_BOLT, Vector2(40, 0)), "lançou")
	var hit := await wait_until(func() -> bool: return slime.health.is_dead(), 60)
	check(hit, "o projétil acertou")
	await physics_frames(1)
	check(player.skills.xp(ARCANE_BOLT.mastery.id) > 0, "Arcano ganhou experiência")
	check(player.skills.xp(SWORD_MASTERY.id) == 0, "Espada não")


## Criaturas não têm maestria nem experiência: o golpe delas não muda.
func test_monsters_have_no_mastery() -> void:
	var slime := spawn_slime(Vector2.ZERO)
	await physics_frames(1)
	check(slime.skills == null and slime.attacker.attack.mastery == null, "sem maestria")
	check(slime.mastery_damage(7, SWORD_MASTERY) == 7, "sem experiência, dano puro")


func test_mastery_xp_is_saved_and_restored() -> void:
	var items := ItemDatabase.load_all()
	var layout := EquipmentLayout.load_default()
	var skills := SkillProgress.new()
	skills.add_xp(SWORD_MASTERY.id, 123)
	var record := CharacterRecord.capture(Inventory.new(4, items), Equipment.new(layout, items),
		skills, Wallet.new(), RecipeBook.new(), 50)
	var restored := SkillProgress.new()
	CharacterRecord.restore(JSON.parse_string(JSON.stringify(record)), Inventory.new(4, items),
		Equipment.new(layout, items), restored, Wallet.new(), RecipeBook.new(),
		DataCatalog.new(SKILLS_DIR), items, RecipeDatabase.load_all())
	check(restored.xp(SWORD_MASTERY.id) == 123, "a maestria volta do save")


## Coop: o golpe do cliente fere no host, o host decide a experiência e o cliente recebe o valor
## oficial (nenhuma mensagem do cliente muda experiência).
func test_client_mastery_xp_is_decided_by_the_host() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(connected, "cliente conectou")
	calm_monsters(host)
	await physics_frames(10)
	var client_id: int = client.local_player_id()
	var on_host := (host.session as GameSession).get_player_entity(client_id) as Character
	var on_client := (client.session as GameSession).get_player_entity(client_id) as Character
	var slime := first_monster(host)
	slime.position = on_host.position + Iso.ground_to_screen(Vector2(18, 0))
	slime.reset_physics_interpolation()
	slime.health.set_current(2)  # o golpe mata
	await physics_frames(10)  # o cliente vê o slime no lugar novo
	check(on_client.request_attack(Vector2.RIGHT), "o cliente golpeia")
	check(await wait_until(func() -> bool: return on_host.skills.xp(SWORD_MASTERY.id) > 0, 60),
		"o host deu experiência de Espada ao cliente")
	var decided := on_host.skills.xp(SWORD_MASTERY.id)
	check(decided == SWORD_MASTERY.xp_for_damage(2), "pelo dano causado (a vida que restava)")
	check(await wait_until(func() -> bool:
		return (client.session as GameSession).get_skills(client_id).xp(SWORD_MASTERY.id) == decided,
		60), "o cliente recebeu o valor do host")


## Subir de nível avisa o ganho de dano, e o HUD mostra a maestria da arma na mão.
func test_level_up_shows_the_damage_gain_and_the_hud_shows_the_weapon_mastery() -> void:
	var game := start_game()
	var skills := (game.session as GameSession).get_skills(1)
	var hud := game.get_node("UI/Hud") as Hud
	check(hud.masteries_in_use() == [SWORD_MASTERY], "HUD: a espada inicial")
	skills.add_xp(SWORD_MASTERY.id, SWORD_MASTERY.xp_to_next(1))
	var expected := Texts.format(&"FEEDBACK_MASTERY_LEVEL_UP",
		[SWORD_MASTERY.get_display_name(), 2, SWORD_MASTERY.damage_bonus_percent(2)])
	check(expected in feedback_texts(game), "aviso: %s" % expected)
