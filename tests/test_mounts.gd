extends TestCase
## Montarias (J3, ADR-035), estilo Albion: subir leva um tempo parado; montado, anda mais rápido,
## mas não ataca, não coleta nem lança; dano derruba. O host decide; a montaria sobrevive à
## viagem entre regiões.

const PORT := 24830
const MOUNT := &"riding_slime"


func test_riding_slime_goes_in_the_mount_slot_and_is_made_at_the_workbench() -> void:
	var mount := ItemDatabase.load_all().get_item(MOUNT) as MountData
	check(mount != null and mount.icon != null and mount.texture != null, "a montaria existe e tem desenho")
	check(mount.get_slot() == EquipmentData.Slot.MOUNT and mount.speed_percent > 0.0
		and mount.mount_time > 0.0, "vai no espaço de montaria e acelera")
	check(EquipmentLayout.load_default().slots.count(EquipmentData.Slot.MOUNT) == 1,
		"o personagem tem um espaço de montaria")
	var recipe := RecipeDatabase.load_all().get_recipe(MOUNT)
	check(recipe != null and recipe.result == mount
		and recipe.station == RecipeData.Station.WORKBENCH, "receita na bancada")


func test_mounting_takes_time_standing_still_then_rides_faster() -> void:
	var game := start_game()
	var player := _rider(game)
	var mount := player.mount
	var on_foot := player.move_speed()
	var state: PlayerStateSync = game.player_state
	state.request_toggle_mount()
	check(player.rider.state.phase == RideState.Phase.MOUNTING, "começou a subir")
	var start := player.position
	player.set_move_intent(Vector2.RIGHT)
	await physics_frames(roundi(mount.mount_time * 60.0) - 6)
	check(player.position.distance_to(start) < 0.5, "subindo, fica parado")
	check(not player.rider.is_mounted(), "ainda não subiu")
	await physics_frames(8)
	check(player.rider.is_mounted(), "subiu")
	check_near(player.move_speed(), on_foot * (1.0 + mount.speed_percent / 100.0), 0.01,
		"montado, anda mais rápido")
	await physics_frames(20)
	check(player.position.distance_to(start) > 10.0, "montado, anda")
	check(not player.request_attack(Vector2.RIGHT), "montado, não ataca")
	check(not player.can_act(), "montado, não lança habilidades")
	state.request_toggle_mount()
	check(player.rider.state.phase == RideState.Phase.ON_FOOT
		and is_equal_approx(player.move_speed(), on_foot), "desceu: velocidade normal")
	player.set_move_intent(Vector2.ZERO)


func test_without_a_mount_nothing_happens() -> void:
	var game := start_game()
	calm_monsters(game)
	(game.player_state as PlayerStateSync).request_toggle_mount()
	var player := (game.session as GameSession).get_player_entity(1) as Character
	check(player.rider.state.phase == RideState.Phase.ON_FOOT, "sem montaria vestida, fica a pé")


func test_damage_interrupts_mounting_and_knocks_off_the_mount() -> void:
	var game := start_game()
	var player := _rider(game)
	var state: PlayerStateSync = game.player_state
	state.request_toggle_mount()
	await physics_frames(5)
	_hurt(player)
	check(player.rider.state.phase == RideState.Phase.ON_FOOT, "apanhar interrompe a subida")
	# Atordoado não sobe, e a invulnerabilidade depois do golpe ignoraria o próximo.
	var recovery := maxf(player.stats.hit_stun, player.stats.invulnerability_time)
	await physics_frames(roundi(recovery * 60.0) + 2)
	await _mount_up(game, player)
	check(player.rider.is_mounted(), "subiu")
	_hurt(player)
	check(player.rider.state.phase == RideState.Phase.ON_FOOT, "apanhar montado derruba")


func test_taking_the_mount_off_dismounts() -> void:
	var game := start_game()
	var player := _rider(game)
	await _mount_up(game, player)
	var session := game.session as GameSession
	var equipment := session.get_equipment(1)
	EquipmentRules.click_slot(session.get_inventory(1), equipment,
		equipment.index_of_type(EquipmentData.Slot.MOUNT))
	check(player.mount == null and not player.rider.is_busy(), "tirou a montaria: desceu")


func test_stays_mounted_when_traveling() -> void:
	var game := start_game()
	var player := _rider(game)
	await _mount_up(game, player)
	game._travel(1, &"forest", &"to_meadow")
	await physics_frames(2)
	var arrived := (game.session as GameSession).get_player_entity(1) as Character
	check(arrived != player and arrived.rider.is_mounted(), "chegou à floresta montado")


## Coop: o cliente pede para montar e o host decide; todos veem montado. Montado, o host recusa
## o ataque do cliente; levar dano no host derruba também no cliente.
func test_client_mounts_through_host() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(connected, "cliente conectou")
	calm_monsters(host)
	var client_id: int = client.local_player_id()
	var host_session := host.session as GameSession
	var on_host := host_session.get_player_entity(client_id) as Character
	var on_client := (client.session as GameSession).get_player_entity(client_id) as Character
	var requests: PlayerStateSync = client.player_state

	requests.request_toggle_mount()
	await physics_frames(10)
	check(not on_host.rider.is_busy(), "sem montaria: o host não deixa subir")

	var inventory := host_session.get_inventory(client_id)
	inventory.add(MOUNT, 1)
	EquipmentRules.equip_from_inventory(inventory, host_session.get_equipment(client_id),
		slot_of(inventory, MOUNT))
	check(await wait_until(func() -> bool: return on_client.mount != null, 30),
		"a montaria chegou ao cliente")
	requests.request_toggle_mount()
	check(await wait_until(func() -> bool:
		return on_client.rider.state.phase == RideState.Phase.MOUNTING, 30),
		"o cliente vê que está subindo")
	check(await wait_until(func() -> bool:
		return on_host.rider.is_mounted() and on_client.rider.is_mounted(), 120),
		"o host completou a subida e o cliente está montado")
	check(on_client.move_speed() > on_client.stats.move_speed, "no cliente, anda mais rápido")

	(on_client.net as NetSync)._request_attack.rpc_id(1, Vector2.RIGHT)  # forjado: montado
	await physics_frames(10)
	check(not on_host.attacker.is_attacking(), "montado: o host recusa o ataque")

	_hurt(on_host)
	check(await wait_until(func() -> bool: return not on_client.rider.is_busy(), 30),
		"apanhou no host: desceu também no cliente")


## Jogo local com as criaturas paradas e o slime de montaria vestido (o host decide, como no jogo).
func _rider(game: Node) -> Character:
	calm_monsters(game)
	var session := game.session as GameSession
	var inventory := session.get_inventory(1)
	inventory.add(MOUNT, 1)
	EquipmentRules.equip_from_inventory(inventory, session.get_equipment(1), slot_of(inventory, MOUNT))
	return session.get_player_entity(1) as Character


func _mount_up(game: Node, player: Character) -> void:
	(game.player_state as PlayerStateSync).request_toggle_mount()
	await physics_frames(roundi(player.mount.mount_time * 60.0) + 2)


func _hurt(player: Character) -> void:
	player.health.apply_damage(DamageInfo.create(1, Vector2.RIGHT, 0.0, 0, 0))
