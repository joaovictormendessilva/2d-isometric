extends TestCase
## Combate: arco da espada, facções, fórmulas, drops pessoais, morte e renascimento.

const SCALING := preload("res://data/balance/player_scaling.tres")


func test_sword_hits_only_monsters_inside_the_arc() -> void:
	var player := spawn_character(Vector2.ZERO)
	var in_front := spawn_slime(Vector2(20, 0))
	var behind := spawn_slime(Vector2(-20, 0))
	await physics_frames(1)
	check(player.request_attack(Vector2.RIGHT), "ataque começou")
	await physics_frames(10)
	var sword := player.attacker.attack
	check(in_front.health.current == in_front.health.max_health - sword.damage,
		"slime da frente perdeu %d de vida (vida %d)" % [sword.damage, in_front.health.current])
	check(in_front.position.x > 20.0, "slime da frente sofreu recuo")
	check(behind.health.current == behind.health.max_health, "slime de trás não foi atingido")


func test_same_faction_is_not_hit() -> void:
	var player := spawn_character(Vector2.ZERO)
	var ally := spawn_character(Vector2(15, 0))
	await physics_frames(1)
	player.request_attack(Vector2.RIGHT)
	await physics_frames(10)
	check(ally.health.current == ally.health.max_health, "aliado não leva dano")


func test_defense_has_diminishing_returns() -> void:
	check(CombatRules.mitigate(10, 0) == 10, "sem defesa: dano cheio")
	check(CombatRules.mitigate(10, 100) == 5, "100 de defesa: metade")
	check(CombatRules.mitigate(10, 10000) == 1, "dano mínimo é 1")
	check(CombatRules.mitigate(100, 50) > CombatRules.mitigate(100, 100) + 10,
		"os primeiros pontos de defesa valem mais que os seguintes")


func test_monster_health_scales_with_player_count() -> void:
	check_near(CombatRules.monster_health_multiplier(1, SCALING), 1.0, 0.001, "1 jogador")
	check_near(CombatRules.monster_health_multiplier(2, SCALING), 1.5, 0.001, "2 jogadores")
	check_near(CombatRules.monster_health_multiplier(4, SCALING), 2.5, 0.001, "4 jogadores")


## Com 2 jogadores, cada um recebe o próprio drop; só o dono coleta, e só o local vê o seu.
func test_monster_drops_are_personal_and_collectable() -> void:
	var game := start_game()
	var session: GameSession = game.session
	var spawner: EntitySpawner = game.get_node("EntitySpawner")
	var second_player := spawner.spawn_player(2)
	var monster := _first_monster(game)
	monster.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, 1))
	await physics_frames(2)

	var pickups := _pickups(game)
	var owners := pickups.map(func(p: Pickup) -> int: return p.owner_player_id)
	check(1 in owners and 2 in owners, "um drop para cada jogador (donos %s)" % [owners])
	for p: Pickup in pickups:
		check(p.visible == (p.owner_player_id == game.local_player_id()), "só o drop do jogador local aparece")

	# O jogador 2 pisa no drop do jogador 1: esse fica. O dele (ao lado) é atraído e coletado.
	var drop_of_1: Pickup = pickups.filter(func(p: Pickup) -> bool: return p.owner_player_id == 1)[0]
	var drop_of_2: Pickup = pickups.filter(func(p: Pickup) -> bool: return p.owner_player_id == 2)[0]
	second_player.position = drop_of_1.position
	await physics_frames(20)
	check(is_instance_valid(drop_of_1), "drop alheio não é coletado")
	check(not is_instance_valid(drop_of_2), "o dono coleta o próprio drop")
	check(session.get_inventory(2).count(&"gel") > 0, "gosma foi para o inventário do jogador 2")
	check(session.get_inventory(1).count(&"gel") == 0, "inventário do jogador 1 não mudou")


func test_player_dies_and_respawns_at_entry() -> void:
	var game := start_game()
	var region: Region = game.region
	var player := (game.session as GameSession).get_player_entity(game.local_player_id()) as Character
	player.position += Vector2(40, 0)
	player.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, 0))
	check(not player.is_alive(), "jogador morreu")
	await physics_frames(roundi(EntitySpawner.PLAYER_RESPAWN_TIME * 60) + 10)
	check(player.is_alive(), "jogador renasceu")
	check(player.health.current == player.health.max_health, "com vida cheia")
	check(player.position.is_equal_approx(region.get_spawn_position()), "no ponto de entrada")


func test_monster_respawns_after_death() -> void:
	var game := start_game()
	var session: GameSession = game.session
	var before := session.get_entity_count()
	var monster := _first_monster(game)
	monster.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, 1))
	check(session.get_entity_count() == before - 1, "criatura morta sai do registro")
	await physics_frames(26 * 60)  # tempo máximo de renascimento gerado: 25 s
	check(session.get_entity_count() == before, "criatura renasceu")


func _first_monster(game: Node) -> Monster:
	for node in (game.region as Region).entities.get_children():
		if node is Monster:
			return node
	return null


func _pickups(game: Node) -> Array:
	return (game.region as Region).entities.get_children().filter(func(n: Node) -> bool: return n is Pickup)


## Morrer no meio da preparação cancela o ataque: nada de bote "fantasma" depois da morte
## (o bote do slime não é interrompido por golpes, mas a morte encerra tudo).
func test_death_cancels_pending_attack() -> void:
	var slime := spawn_slime(Vector2.ZERO)
	await physics_frames(1)
	check(slime.request_attack(Vector2.RIGHT), "bote começou")
	var struck := [false]
	slime.attacker.attack_struck.connect(func(_d: Vector2, _a: MeleeAttackData) -> void: struck[0] = true)
	await physics_frames(5)
	slime.health.apply_damage(DamageInfo.create(9999, Vector2.LEFT, 0, 0, 1))
	var at_death := slime.position
	await physics_frames(roundi(slime.data.attack.windup * 60) + 10)
	check(not struck[0], "o bote não saiu depois da morte")
	check(slime.position.distance_to(at_death) < 1.0,
		"o corpo não avançou (andou %.1f px)" % slime.position.distance_to(at_death))
