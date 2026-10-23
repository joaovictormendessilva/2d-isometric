extends TestCase
## Ameaça (G2c): quem fere de longe vira alvo, a perseguição só acaba na coleira e, sem alvo, a
## criatura passeia perto de casa. Vale para toda criatura (o slime é só o banco de testes).


func test_threat_table_picks_highest_with_margin() -> void:
	var table := ThreatTable.new()
	check(table.pick(0) == 0, "sem ameaça, ninguém")
	table.notice(1)
	table.notice(1)
	check(is_equal_approx(table.get_threat(1), ThreatTable.NOTICE_THREAT), "perceber não acumula")
	table.add(2, 10)
	check(table.pick(1) == 2, "quem feriu passa quem só foi percebido")
	table.add(1, 10)
	check(table.pick(2) == 2, "ameaça parecida: fica no alvo atual (margem)")
	table.add(1, 5)
	check(table.pick(2) == 1, "passou da margem: troca")
	table.add(3, 0)
	check(table.get_threat(3) >= ThreatTable.NOTICE_THREAT, "golpe sem dano (defesa) ainda conta")
	table.remove(1)
	check(table.pick(1) == 2, "quem saiu da tabela não é escolhido")


## Atacada de fora do raio de agressão (projétil, flecha), a criatura vai atrás de quem atirou.
func test_creature_chases_who_hits_it_from_afar() -> void:
	var session := GameSession.new()
	var slime := spawn_slime(Vector2.ZERO, session)
	var start := slime.data.aggro_radius + 60.0
	var player := spawn_character(Vector2(start, 0))
	register_player(session, player, 1)
	await physics_frames(5)
	check(slime.get_node("Brain").target() == null, "longe: não percebe")
	slime.health.apply_damage(DamageInfo.create(5, Vector2.LEFT, 0.0, player.entity_id, 1))
	await physics_frames(180)
	check(slime.get_node("Brain").target() == player, "virou alvo quem atirou")
	check(slime.position.x > MonsterBrain.HOME_TOLERANCE + slime.data.wander_radius,
		"foi na direção de quem atirou (x=%.0f)" % slime.position.x)


## Perseguindo, a criatura não desiste só porque o jogador saiu do raio de agressão: só na coleira.
func test_chase_continues_outside_aggro_until_leash() -> void:
	var session := GameSession.new()
	var player := spawn_character(Vector2(40, 0))
	register_player(session, player, 1)
	var slime := spawn_slime(Vector2.ZERO, session)
	var brain: MonsterBrain = slime.get_node("Brain")
	await physics_frames(20)
	check(brain.target() == player, "percebeu quem chegou perto")
	player.position = Vector2(slime.position.x + slime.data.aggro_radius + 30.0, 0)
	await physics_frames(30)
	check(brain.target() == player, "fora do raio de agressão, continua perseguindo")
	check(not brain.is_returning(), "ainda não desistiu (dentro da coleira)")


## Dois jogadores: um colado na criatura, outro ferindo de longe. Ela vira para quem mais fere
## (mago/arqueiro não ficam em paz atrás do guerreiro).
func test_creature_turns_to_bigger_damage_dealer() -> void:
	var session := GameSession.new()
	var near := spawn_character(Vector2(30, 0))
	register_player(session, near, 1)
	var slime := spawn_slime(Vector2.ZERO, session)
	var far := spawn_character(Vector2(-slime.data.aggro_radius - 40.0, 0))
	register_player(session, far, 2)
	var brain: MonsterBrain = slime.get_node("Brain")
	await physics_frames(20)
	check(brain.target() == near, "começa no jogador de perto")
	slime.health.apply_damage(DamageInfo.create(8, Vector2.RIGHT, 0.0, far.entity_id, 2))
	await physics_frames(5)
	check(brain.target() == far, "trocou para quem feriu de longe")
	check(brain.threat_of(2) > brain.threat_of(1), "ameaça maior de quem feriu")


## Sem ninguém por perto, a criatura passeia, mas sem sair da própria área.
func test_creature_wanders_near_home() -> void:
	var session := GameSession.new()
	var slime := spawn_slime(Vector2.ZERO, session)
	var farthest := 0.0
	for _second in 12:
		await physics_frames(60)
		farthest = maxf(farthest, Iso.ground_distance(slime.position, Vector2.ZERO))
	check(farthest > MonsterBrain.HOME_TOLERANCE, "saiu do lugar (%.0f px)" % farthest)
	check(farthest <= slime.data.wander_radius + MonsterBrain.HOME_TOLERANCE,
		"ficou na própria área (%.0f px)" % farthest)
