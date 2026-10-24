extends TestCase
## IA das criaturas: percebe, persegue e ataca jogadores próximos; ignora os distantes.


func test_slime_chases_and_hits_nearby_player() -> void:
	var session := GameSession.new()
	var player := spawn_character(Vector2.ZERO)
	register_player(session, player, 1)
	spawn_slime(Vector2(70, 0), session)
	await physics_frames(240)
	check(player.health.current < player.health.max_health,
		"slime alcançou e feriu o jogador (vida %d)" % player.health.current)


func test_slime_ignores_distant_player() -> void:
	var session := GameSession.new()
	var player := spawn_character(Vector2.ZERO)
	register_player(session, player, 1)
	var slime := spawn_slime(Vector2(300, 0), session)
	await physics_frames(120)
	check(Iso.ground_distance(slime.position, Vector2(300, 0))
		<= slime.data.wander_radius + MonsterBrain.HOME_TOLERANCE, "slime ficou perto de casa")
	check(player.health.current == player.health.max_health, "jogador intacto")


## O ataque do slime precisa ser lento o bastante para ser telegrafado (ver ActorFeedback).
func test_slime_attack_is_telegraphed() -> void:
	var slime := spawn_slime(Vector2.ZERO)
	check(slime.data.attack.windup >= ActorFeedback.TELEGRAPH_MIN_WINDUP,
		"preparação do bote (%.2f s) é visível" % slime.data.attack.windup)


## Apanhando durante a preparação, o slime pisca e VOLTA ao vermelho do aviso (antes o flash
## apagava o aviso e o bote parecia sair do nada).
func test_damage_flash_keeps_the_attack_warning() -> void:
	var slime := spawn_slime(Vector2.ZERO)
	var visual: CanvasItem = slime.get_node("Visual")
	slime.request_attack(Vector2.RIGHT)
	await physics_frames(5)
	slime.health.apply_damage(DamageInfo.create(1, Vector2.LEFT, 0.0, 0, 1))
	await physics_frames(roundi(ActorFeedback.FLASH_TIME * 60.0) + 2)
	check(visual.modulate.is_equal_approx(ActorFeedback.TELEGRAPH_COLOR),
		"depois do flash, continua vermelho (%s)" % visual.modulate)


## O bote é uma investida: acerta quem ficou parado a meia distância (fora do alcance do
## golpe parado) e erra quem se afastou durante o aviso. Vale para todo slime (e o Rei Slime).
func test_slime_lunge_reaches_who_stays_and_misses_who_runs() -> void:
	for runs: bool in [false, true]:
		var slime := spawn_slime(Vector2.ZERO)  # sem sessão: a IA não age, o teste comanda
		var attack := slime.data.attack
		var player := spawn_character(Vector2.ZERO)
		var start := slime.footprint_radius() + player.footprint_radius() + attack.engage_distance
		player.position = Vector2(start, 0)  # no eixo x, chão = tela
		player.reset_physics_interpolation()
		check(attack.engage_distance > attack.reach, "a investida começa de fora do alcance parado")
		check(slime.request_attack(Vector2.RIGHT), "começou o bote")
		if runs:
			player.position.x += 60.0
		await physics_frames(roundi((attack.windup + attack.lunge_hit_time) * 60.0) + 4)
		var hurt := player.health.current < player.health.max_health
		check(hurt != runs, "quem fugiu escapa; quem ficou leva" if runs else "quem ficou leva o bote")
		slime.free()
		player.free()


## Jogador parado logo depois da coleira: o slime desiste e volta para casa de vez, em vez
## de oscilar na borda (perceber → passar da coleira → voltar → perceber de novo...).
## Voltando, ele é imune (não vira alvo fácil) e, em casa, recupera a vida toda.
func test_slime_evades_at_leash_immune_and_heals_at_home() -> void:
	var session := GameSession.new()
	var player := spawn_character(Vector2(50, 0))
	register_player(session, player, 1)
	var slime := spawn_slime(Vector2.ZERO, session)
	var brain: MonsterBrain = slime.get_node("Brain")
	var leash := slime.data.leash_radius
	var stop_x := leash + slime.data.aggro_radius * 0.5  # no eixo x, chão = tela
	player.skills = SkillProgress.new()
	var sword := player.attacker.attack.mastery
	player.strike(slime, DamageInfo.create(10, Vector2.RIGHT, 0, 0, 1), sword)

	# Atrai o slime ficando um pouco à frente dele (fora do alcance) e para depois da coleira.
	var frames := 0
	while not brain.is_returning() and frames < 20 * 60:
		player.position = Vector2(minf(slime.position.x + 50.0, stop_x), 0)
		await physics_frames(1)
		frames += 1
	check(brain.is_returning(), "slime desistiu ao passar da coleira")
	var before := slime.health.current
	check(not slime.health.apply_damage(DamageInfo.create(10, Vector2.RIGHT, 0, 0, 1)),
		"golpe no slime em retirada não pega")
	check(slime.health.current == before, "vida não mudou durante a retirada")

	frames = 0
	while brain.is_returning() and frames < 20 * 60:
		await physics_frames(1)
		frames += 1
	check(not brain.is_returning(), "slime chegou em casa sem voltar a perseguir")
	check(Iso.ground_distance(slime.position, Vector2.ZERO) <= MonsterBrain.HOME_TOLERANCE,
		"está em casa")
	check(slime.health.current == slime.health.max_health, "recuperou a vida toda")
	check(not slime.health.is_immune(), "voltou a poder ser atingido")
	# O dano de antes da retirada não vale mais: matar agora sem ferir paga nada (ADR-038).
	slime.health.apply_damage(DamageInfo.create(999, Vector2.RIGHT, 0, 0, 1))
	await physics_frames(2)
	check(slime.health.is_dead() and player.skills.xp(sword.id) == 0,
		"ferir e deixar voltar para casa não rende experiência")


## Segurar o ataque não pode travar o slime: o bote telegrafado sai mesmo apanhando, então
## quem só aperta o botão sem desviar leva dano.
func test_holding_attack_does_not_stun_lock_slime() -> void:
	var session := GameSession.new()
	var player := spawn_character(Vector2.ZERO)
	register_player(session, player, 1)
	var slime := spawn_slime(Vector2(40, 0), session)
	var frames := 0
	while slime.is_alive() and frames < 15 * 60:
		var to_slime := Iso.screen_to_ground(slime.position - player.position)
		player.set_move_intent(to_slime.normalized())
		player.request_attack(to_slime)
		await physics_frames(1)
		frames += 1
	check(not slime.is_alive(), "o jogador venceu o duelo")
	check(player.health.current < player.health.max_health,
		"o slime acertou ao menos um bote (vida %d)" % player.health.current)


## Voltando para casa (imune), a criatura fica semitransparente mesmo que um flash de dano ou o
## fim de um golpe aconteça logo depois (antes, o efeito curto devolvia a cor opaca).
func test_immune_creature_stays_translucent_after_flash() -> void:
	var slime := spawn_slime(Vector2.ZERO)
	var visual: CanvasItem = slime.get_node("Visual")
	slime.request_attack(Vector2.RIGHT)
	await physics_frames(2)
	slime.health.set_immune(true)
	slime.attacker.attack_finished.emit()  # golpe interrompido logo depois de ficar imune
	await physics_frames(roundi(ActorFeedback.IMMUNE_FADE_TIME * 60.0) + 4)
	check(is_equal_approx(visual.modulate.a, ActorFeedback.IMMUNE_MODULATE.a),
		"continua semitransparente (a=%.2f)" % visual.modulate.a)
