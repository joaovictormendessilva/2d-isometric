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
	check(slime.position.distance_to(Vector2(300, 0)) < 2.0, "slime ficou em casa")
	check(player.health.current == player.health.max_health, "jogador intacto")


## O ataque do slime precisa ser lento o bastante para ser telegrafado (ver ActorFeedback).
func test_slime_attack_is_telegraphed() -> void:
	var slime := spawn_slime(Vector2.ZERO)
	check(slime.data.attack.windup >= ActorFeedback.TELEGRAPH_MIN_WINDUP,
		"preparação do bote (%.2f s) é visível" % slime.data.attack.windup)
