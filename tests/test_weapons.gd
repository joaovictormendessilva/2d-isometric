extends TestCase
## Armas à distância (J2, ADR-033): o golpe do arco solta uma flecha que fere o primeiro inimigo
## no caminho; no coop, só a flecha do host fere e todos a veem.

const PORT := 24820
const BOW := &"bow"


func test_bow_is_a_two_handed_ranged_weapon_made_at_the_workbench() -> void:
	var bow := ItemDatabase.load_all().get_item(BOW) as WeaponData
	check(bow != null and bow.icon != null, "o arco existe e tem ícone")
	check(bow.grip == WeaponData.Grip.TWO_HAND and bow.off_hand_kinds == [OffHandData.Kind.QUIVER],
		"de 2 mãos; só aceita aljava")
	var flight := bow.attack.projectile
	check(flight != null and flight.look == ProjectileData.Look.ARROW and flight.speed > 0.0
		and flight.max_range > 0.0 and flight.hit_radius > 0.0, "o golpe é uma flecha")
	var recipe := RecipeDatabase.load_all().get_recipe(BOW)
	check(recipe != null and recipe.result == bow
		and recipe.station == RecipeData.Station.WORKBENCH, "receita na bancada")


func test_arrow_hits_only_the_first_monster_in_line() -> void:
	var game := start_game()
	var player := _archer(game)
	var bow := player.attacker.attack
	var slimes := _slimes(game, 3)
	var near := slimes[0]
	var far := slimes[1]
	var behind := slimes[2]
	_place(near, player.position + Iso.ground_to_screen(Vector2(60, 0)))
	_place(far, player.position + Iso.ground_to_screen(Vector2(110, 0)))
	_place(behind, player.position + Iso.ground_to_screen(Vector2(-15, 0)))
	await physics_frames(2)
	check(player.request_attack(Vector2.RIGHT), "atirou")
	check(await wait_until(func() -> bool: return near.health.current < near.health.max_health,
		roundi((bow.windup + 60.0 / bow.projectile.speed) * 60.0) + 6), "a flecha acertou o da frente")
	check(near.health.max_health - near.health.current == bow.damage, "dano do arco")
	await physics_frames(roundi(60.0 / bow.projectile.speed * 60.0) + 4)
	check(far.health.current == far.health.max_health, "o de trás não levou (parou no primeiro)")
	check(behind.health.current == behind.health.max_health, "quem está nas costas não leva")


func test_arrow_vanishes_at_max_range() -> void:
	var game := start_game()
	var player := _archer(game)
	var bow := player.attacker.attack
	player.request_attack(Vector2.UP)
	await physics_frames(roundi(bow.windup * 60.0) + 2)
	check(_arrows(game.region) == 1, "a flecha voa")
	await physics_frames(roundi(bow.projectile.max_range / bow.projectile.speed * 60.0) + 4)
	check(_arrows(game.region) == 0, "chegou ao alcance e sumiu")


## Coop: o cliente veste o arco (o host decide) e atira; a flecha do host fere o slime, e o host
## e o cliente veem a flecha voar.
func test_client_shoots_through_host() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(connected, "cliente conectou")
	calm_monsters(host)
	await physics_frames(10)
	var client_id: int = client.local_player_id()
	var host_session := host.session as GameSession
	var on_host := host_session.get_player_entity(client_id) as Character
	var on_client := (client.session as GameSession).get_player_entity(client_id) as Character
	var inventory := host_session.get_inventory(client_id)
	inventory.add(BOW, 1)
	check(EquipmentRules.equip_from_inventory(inventory, host_session.get_equipment(client_id),
		slot_of(inventory, BOW)), "o host veste o arco no cliente")
	var bow := on_host.attacker.attack
	check(bow.projectile != null, "no host, o golpe do cliente é o do arco")
	check(await wait_until(func() -> bool: return on_client.attacker.attack == bow, 30),
		"o arco chegou ao cliente")

	var slime := first_monster(host)
	slime.position = on_host.position + Iso.ground_to_screen(Vector2(50, 0))
	slime.reset_physics_interpolation()
	await physics_frames(10)  # o cliente vê o slime no lugar novo
	check(on_client.request_attack(Vector2.RIGHT), "o cliente atira na hora")
	check(await wait_until(func() -> bool:
		return _arrows(host.region) > 0 and _arrows(client.region) > 0, 60),
		"a flecha voa no host e no cliente")
	check(await wait_until(func() -> bool: return slime.health.current < slime.health.max_health, 90),
		"a flecha do host feriu o slime")


## Jogo local com as criaturas paradas e o jogador de arco vestido (o host decide, como no jogo).
func _archer(game: Node) -> Character:
	calm_monsters(game)
	var session := game.session as GameSession
	var inventory := session.get_inventory(1)
	inventory.add(BOW, 1)
	EquipmentRules.equip_from_inventory(inventory, session.get_equipment(1), slot_of(inventory, BOW))
	return session.get_player_entity(1) as Character


func _slimes(game: Node, count: int) -> Array[Monster]:
	var found: Array[Monster] = []
	for node in (game.region as Region).entities.get_children():
		if node is Monster and found.size() < count:
			found.append(node)
	return found


func _place(monster: Monster, at: Vector2) -> void:
	monster.position = at
	monster.reset_physics_interpolation()


## Flechas voando na região (projéteis ficam na camada de entidades).
func _arrows(region: Region) -> int:
	return region.entities.get_children().filter(func(n: Node) -> bool:
		return n is Projectile and not n.is_queued_for_deletion()).size()
