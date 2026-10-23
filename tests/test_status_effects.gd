extends TestCase
## Buffs e debuffs (G1a, ADR-025): efeitos em dados com duração, bônus e ticks; o host aplica e
## cobra; os clientes recebem a lista; o veneno não atordoa; o save guarda o que ainda dura.

const PORT := 24770
const SAVE_DIR := "user://test_saves/"
const SAVE_PATH := SAVE_DIR + "effects_world.json"


func test_effect_data_is_consistent() -> void:
	var effects := EffectDatabase.shared()
	check(effects.get_effect(&"poison") != null and effects.get_effect(&"swiftness") != null,
		"veneno e rapidez existem")
	for entry in effects.entries():
		var effect := entry as StatusEffectData
		check(effect.duration > 0.0 and effect.duration <= ActiveEffects.MAX_SECONDS,
			"%s: duração dentro dos limites" % effect.id)
		check(effect.damage_per_tick >= 0 and effect.heal_per_tick >= 0,
			"%s: ticks não negativos" % effect.id)
		check(not effect.has_ticks() or effect.tick_interval >= 0.1, "%s: ritmo sensato" % effect.id)


func test_ticks_expiry_and_refresh() -> void:
	var poison := EffectDatabase.shared().get_effect(&"poison")
	var active := ActiveEffects.new()
	var changes := [0]
	active.changed.connect(func() -> void: changes[0] += 1)
	active.apply(poison, 7)
	var ticks: Array[ActiveEffects.Entry] = []
	for frame in roundi(poison.duration * 60.0):
		ticks.append_array(active.advance(1.0 / 60.0))
	check(ticks.size() == roundi(poison.duration / poison.tick_interval),
		"um tick por segundo até o fim (%d)" % ticks.size())
	check(ticks.all(func(entry: ActiveEffects.Entry) -> bool: return entry.source_player_id == 7),
		"o tick lembra quem envenenou")
	check(not active.has(&"poison") and changes[0] == 2, "acabou e avisou (começo e fim)")

	active.apply(poison)
	active.advance(poison.duration - 0.5)
	active.apply(poison)
	check_near(active.remaining(&"poison"), poison.duration, 0.001, "reaplicar renova o tempo cheio")
	check(active.entries().size() == 1, "não empilha")


func test_bonuses_add_up_and_snapshot_is_validated() -> void:
	var effects := EffectDatabase.shared()
	var active := ActiveEffects.new()
	active.apply(effects.get_effect(&"swiftness"))
	active.apply(effects.get_effect(&"poison"))
	check(active.bonuses().move_speed_percent == 25.0, "rapidez soma +25%")
	var copy := ActiveEffects.new()
	copy.replicate(JSON.parse_string(JSON.stringify(active.snapshot())), effects)
	check(copy.has(&"poison") and copy.has(&"swiftness"), "a cópia tem os dois")
	check_near(copy.remaining(&"swiftness"), active.remaining(&"swiftness"), 0.001, "mesmo tempo")

	copy.replicate({"nao_existe": 5.0, "poison": 1e30, "swiftness": -3.0, 7: 2.0}, effects)
	check(copy.entries().size() == 1, "só o efeito conhecido com tempo positivo entra")
	check(copy.remaining(&"poison") <= effects.get_effect(&"poison").duration,
		"tempo absurdo vira no máximo a duração")
	copy.replicate({"poison": "muito"}, effects)
	check(copy.entries().is_empty(), "tempo que não é número é ignorado")
	copy.replicate("lixo", effects)
	check(copy.entries().is_empty(), "lista que não é dicionário: nenhum efeito")


## Veneno: tira vida a cada tick, ignora defesa e não atordoa, empurra nem dá invulnerabilidade.
func test_poison_hurts_without_stun() -> void:
	var character := spawn_character(Vector2(100, 100))
	var poison := EffectDatabase.shared().get_effect(&"poison")
	var start := character.health.current
	check(character.status_effects.apply(poison), "aplicou")
	await physics_frames(roundi(poison.tick_interval * 60.0) + 1)
	check(character.health.current == start - poison.damage_per_tick,
		"primeiro tick: -%d (%d)" % [poison.damage_per_tick, character.health.current])
	check(not character.health.is_invulnerable() and character._stun_left == 0.0,
		"sem invulnerabilidade nem atordoamento")
	check(character.ground_velocity == Vector2.ZERO, "sem empurrão")
	await physics_frames(roundi(poison.duration * 60.0))
	var expected := start - poison.damage_per_tick * roundi(poison.duration / poison.tick_interval)
	check(character.health.current == expected and not character.status_effects.effects.has(&"poison"),
		"acabou depois de todos os ticks (%d)" % character.health.current)


func test_swiftness_speeds_up_until_it_ends() -> void:
	var character := spawn_character(Vector2(100, 100))
	var swiftness := EffectDatabase.shared().get_effect(&"swiftness")
	var base := character.move_speed()
	character.status_effects.apply(swiftness)
	check_near(character.move_speed(), base * 1.25, 0.01, "25% mais rápido")
	character.status_effects.effects.advance(swiftness.duration)
	check_near(character.move_speed(), base, 0.01, "volta ao normal quando acaba")


func test_death_and_immunity_clear_effects() -> void:
	var character := spawn_character(Vector2(100, 100))
	var poison := EffectDatabase.shared().get_effect(&"poison")
	character.status_effects.apply(poison)
	character.health.apply_damage(DamageInfo.create(10_000, Vector2.RIGHT, 0.0, 0, 0))
	check(character.status_effects.effects.entries().is_empty(), "morrer limpa")
	check(not character.status_effects.apply(poison), "morto não recebe efeito")
	var slime := spawn_slime(Vector2(300, 100))
	await physics_frames(1)
	slime.status_effects.apply(poison)
	slime.health.set_immune(true)
	check(slime.status_effects.effects.entries().is_empty(), "ficar imune (voltar para casa) limpa")


## O personagem do jogador usa os efeitos da sessão (continuam depois de viajar) e o save guarda
## o que ainda dura.
func test_player_effects_live_in_the_session_and_save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var game := start_game(SAVE_PATH)
	calm_monsters(game)
	var session := game.session as GameSession
	var player := session.get_player_entity(1) as Character
	check(player.status_effects.effects == session.get_effects(1), "efeitos vêm da sessão")
	player.status_effects.apply(EffectDatabase.shared().get_effect(&"swiftness"))
	check((game.saves as SaveService).save_now() == OK, "grava")
	game.free()
	game = start_game(SAVE_PATH)
	session = game.session as GameSession
	player = session.get_player_entity(1) as Character
	check(session.get_effects(1).has(&"swiftness"), "rapidez volta do save")
	check(player.bonuses.move_speed_percent == 25.0, "e vale no personagem")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Coop: o host envenena e acelera o personagem do cliente; a lista chega ao cliente (que anda
## mais rápido) e o dano de veneno não o atordoa lá.
func test_effects_reach_the_client() -> void:
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
	var base := on_client.move_speed()
	var effects := EffectDatabase.shared()
	on_host.status_effects.apply(effects.get_effect(&"swiftness"))
	on_host.status_effects.apply(effects.get_effect(&"poison"))
	check(await wait_until(func() -> bool:
		return on_client.status_effects.effects.has(&"poison") \
			and on_client.status_effects.effects.has(&"swiftness"), 30),
		"os efeitos chegam ao cliente")
	check_near(on_client.move_speed(), base * 1.25, 0.01, "o cliente anda mais rápido")
	var start := on_client.health.current
	check(await wait_until(func() -> bool: return on_client.health.current < start, 120),
		"o veneno tira vida no cliente")
	check(on_client._stun_left == 0.0, "sem atordoar o dono")
	on_host.status_effects.effects.clear()
	check(await wait_until(func() -> bool:
		return on_client.status_effects.effects.entries().is_empty(), 30),
		"o fim chega ao cliente")
	check_near(on_client.move_speed(), base, 0.01, "velocidade normal de novo")


## G1b: o HUD mostra um quadrado por efeito do jogador local (some sem efeitos), o ator ganha
## partículas só dos efeitos que têm, e o aviso aparece uma vez por efeito novo.
func test_effects_are_shown_in_hud_and_on_the_actor() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var player := session.get_player_entity(1) as Character
	var bar: EffectBar = game.find_children("*", "EffectBar", true, false)[0]
	var vfx := player.get_node("Visual/EffectVfx") as StatusEffectVfx
	check(not bar.visible and bar.shown_count() == 0 and vfx.emitter_count() == 0, "sem efeitos: nada")
	var effects := EffectDatabase.shared()
	var feedback := game.find_children("*", "PlayerFeedback", true, false)[0] as PlayerFeedback
	feedback._queue.clear()
	var poison := effects.get_effect(&"poison")
	var swiftness := effects.get_effect(&"swiftness")
	player.status_effects.apply(poison)
	player.status_effects.apply(swiftness)
	check(bar.visible and bar.shown_count() == 2, "dois quadrados no HUD")
	check(vfx.emitter_count() == 2, "partículas dos dois efeitos")
	var texts := feedback._queue.map(func(message: Array) -> String: return message[0])
	check(texts == [poison.get_display_name(), swiftness.get_display_name()],
		"um aviso por efeito novo (%s)" % [texts])
	feedback._queue.clear()
	player.status_effects.apply(poison)  # renovar
	check(feedback._queue.is_empty(), "renovar não repete o aviso")
	session.get_effects(1).clear()
	check(not bar.visible and bar.shown_count() == 0, "acabaram: o HUD esconde")
	await physics_frames(1)
	check(vfx.emitter_count() == 0, "e as partículas somem")
