extends TestCase
## Rede (Etapa D+): host e cliente no mesmo processo, cada um no próprio mundo físico,
## ligados por ENet em 127.0.0.1. Cobre os riscos de `docs/04-multiplayer.md` e as regras de
## segurança da ADR-013 (o host não aceita o que o cliente não pode decidir).

## Cada teste fecha a conexão ao terminar, então todos podem usar a mesma porta.
const PORT := 24700
const MOVE_FRAMES := 120


func test_client_receives_the_host_world() -> void:
	var games := await _start_pair()
	var host: Node = games[0]
	var client: Node = games[1]
	var host_session: GameSession = host.session
	var client_session: GameSession = client.session
	check(host_session.get_player_count() == 2, "host tem 2 jogadores")
	check(client_session.get_player_count() == 2, "cliente vê 2 jogadores")
	check(client_session.get_entity_count() == host_session.get_entity_count(),
		"mesmas entidades (host %d, cliente %d)" % [
			host_session.get_entity_count(), client_session.get_entity_count()])
	var monster := first_monster(host)
	var replica := _replica(client, monster)
	check(replica != null and replica.position.distance_to(monster.position) < 8.0,
		"criatura aparece no mesmo lugar no cliente")


## Movimento de quem está longe chega suave: um passo parecido por quadro, sem paradas e
## saltos (interpolação), e termina no mesmo lugar.
func test_host_player_movement_reaches_client_smoothly() -> void:
	var games := await _start_pair()
	var host_player := _local_player(games[0])
	var replica := _replica(games[1], host_player)
	host_player.set_move_intent(Vector2.RIGHT)
	var steps := PackedFloat32Array()
	var last := replica.position
	for i in MOVE_FRAMES:
		await tree.physics_frame
		steps.append(replica.position.distance_to(last))
		last = replica.position
	host_player.set_move_intent(Vector2.ZERO)
	await physics_frames(30)
	check(replica.position.distance_to(host_player.position) < 1.0,
		"parou no mesmo lugar (diferença %.1f px)" % replica.position.distance_to(host_player.position))
	var steady := steps.slice(40, MOVE_FRAMES)  # depois do atraso de interpolação e da aceleração
	var expected := host_player.stats.move_speed * Iso.move_speed_factor(Vector2.RIGHT,
		host_player.stats.horizontal_speed_factor) / Engine.physics_ticks_per_second
	check(_min(steady) > expected * 0.5 and _max(steady) < expected * 1.5,
		"passos de %.2f a %.2f px por quadro (esperado ~%.2f)" % [_min(steady), _max(steady), expected])


func test_client_movement_reaches_host() -> void:
	var games := await _start_pair()
	var client_player := _local_player(games[1])
	var on_host := _replica(games[0], client_player)
	client_player.set_move_intent(Vector2.LEFT)
	await physics_frames(MOVE_FRAMES)
	client_player.set_move_intent(Vector2.ZERO)
	await physics_frames(30)
	check(client_player.position.distance_to(_spawn(games[0])) > 50.0, "o cliente andou")
	check(on_host.position.distance_to(client_player.position) < 1.0,
		"host vê o cliente no mesmo lugar (diferença %.1f px)" % on_host.position.distance_to(client_player.position))


## Um cliente adulterado que se teletransporta é recusado e devolvido à última posição aceita.
func test_host_rejects_client_teleport() -> void:
	var games := await _start_pair()
	var client_player := _local_player(games[1])
	var on_host := _replica(games[0], client_player)
	var start := client_player.position
	client_player.position += Vector2(400, 0)
	await physics_frames(30)
	check(on_host.position.distance_to(start) < 4.0,
		"host não aceitou o salto (a %.0f px do início)" % on_host.position.distance_to(start))
	check(client_player.position.distance_to(start) < 4.0, "cliente foi corrigido de volta")


## O cliente não decide dano nem move o que não é dele.
func test_client_cannot_damage_or_move_others() -> void:
	var games := await _start_pair()
	var monster := first_monster(games[0])
	var replica := _replica(games[1], monster)
	var start := monster.position
	replica.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, 0))  # só local
	replica.net._owner_state.rpc_id(1, 999.0, start + Vector2(30, 0), Vector2.RIGHT)
	replica.net._request_attack.rpc_id(1, Vector2.RIGHT)
	await physics_frames(20)
	check(monster.health.current == monster.health.max_health, "vida no host intacta")
	check(replica.health.current == replica.health.max_health, "nem a cópia do cliente aceita dano local")
	check(monster.position.distance_to(start) < 2.0, "criatura não foi movida pelo cliente")
	check(not monster.attacker.is_attacking(), "criatura não atacou a pedido do cliente")


func test_client_sword_damage_is_applied_by_host_and_seen_by_client() -> void:
	var games := await _start_pair()
	var client_player := _local_player(games[1])
	var monster := _pinned_monster(games[0])
	monster.position = client_player.position + Vector2(18, 0)
	monster.reset_physics_interpolation()
	var replica := _replica(games[1], monster)
	await wait_until(func() -> bool: return replica.position.distance_to(monster.position) < 4.0)
	client_player.request_attack(Vector2.RIGHT)
	var hit := await wait_until(func() -> bool: return monster.health.current < monster.health.max_health, 60)
	check(hit, "o golpe do cliente feriu a criatura no host")
	await physics_frames(10)
	check(replica.health.current == monster.health.current,
		"cliente vê a mesma vida (cliente %d, host %d)" % [replica.health.current, monster.health.current])


func test_damage_to_client_player_comes_from_host() -> void:
	var games := await _start_pair()
	var client_player := _local_player(games[1])
	var on_host := _replica(games[0], client_player)
	on_host.health.apply_damage(DamageInfo.create(15, Vector2.RIGHT, 100, 0, 0))
	await physics_frames(10)
	check(client_player.health.current == on_host.health.current,
		"vida do cliente segue o host (cliente %d, host %d)" % [
			client_player.health.current, on_host.health.current])
	check(client_player.health.current < client_player.health.max_health, "o cliente sentiu o dano")


func test_client_player_dies_and_respawns_via_host() -> void:
	var games := await _start_pair()
	var client_player := _local_player(games[1])
	var on_host := _replica(games[0], client_player)
	client_player.set_move_intent(Vector2.LEFT)
	await physics_frames(40)
	client_player.set_move_intent(Vector2.ZERO)
	on_host.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, 0))
	var died := await wait_until(func() -> bool: return not client_player.is_alive(), 30)
	check(died, "cliente viu o próprio personagem morrer")
	var revived := await wait_until(func() -> bool: return client_player.is_alive(),
		roundi(EntitySpawner.PLAYER_RESPAWN_TIME * 60) + 30)
	check(revived, "renasceu por ordem do host")
	check(client_player.position.is_equal_approx(_spawn(games[1])), "no ponto de entrada")
	check(client_player.health.current == client_player.health.max_health, "com vida cheia")


func test_client_collects_own_personal_drop() -> void:
	var games := await _start_pair()
	var host: Node = games[0]
	var client: Node = games[1]
	var client_id: int = client.local_player_id()
	var monster := _pinned_monster(host)
	var client_player := _local_player(client)
	monster.position = client_player.position + Vector2(20, 0)
	monster.reset_physics_interpolation()
	await physics_frames(15)
	monster.health.apply_damage(DamageInfo.create(9999, Vector2.RIGHT, 0, 0, client_id))
	var drops_arrived := await wait_until(func() -> bool: return pickups(client).size() >= 2, 60)
	check(drops_arrived, "drops chegaram ao cliente")
	var own: Array = pickups(client).filter(func(p: Pickup) -> bool: return p.visible)
	check(own.size() == 1 and (own[0] as Pickup).owner_player_id == client_id,
		"cliente vê só o próprio drop")
	if own.size() != 1:
		return
	client_player.position = (own[0] as Pickup).position  # passo curto: dentro do limite de velocidade
	var collected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_inventory(client_id).count(&"gel") > 0, 120)
	check(collected, "o item coletado no host apareceu no inventário do cliente")
	check((host.session as GameSession).get_inventory(client_id).count(&"gel")
		== (client.session as GameSession).get_inventory(client_id).count(&"gel"),
		"cliente vê a mesma contagem que o host registrou para ele")


func test_host_keeps_running_when_client_leaves() -> void:
	var games := await _start_pair()
	var host: Node = games[0]
	(games[1] as Node).get_parent().free()  # cliente fecha o jogo
	var left := await wait_until(func() -> bool: return (host.session as GameSession).get_player_count() == 1)
	check(left, "host removeu o jogador que saiu")
	var host_player := _local_player(host)
	var start := host_player.position
	host_player.set_move_intent(Vector2.RIGHT)
	await physics_frames(30)
	check(host_player.position.distance_to(start) > 10.0, "host continua jogando")


func test_client_survives_host_leaving() -> void:
	var games := await _start_pair()
	var client: Node = games[1]
	(games[0] as Node).get_parent().free()  # host fecha o jogo
	await physics_frames(60)
	check((client.network as Network).status_text() == "Conexão com o host perdida",
		"cliente avisa que perdeu o host (\"%s\")" % (client.network as Network).status_text())


func test_wrong_protocol_is_refused() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var viewport := SubViewport.new()
	viewport.name = "Client"
	add_to_tree(viewport)
	tree.set_multiplayer(SceneMultiplayer.new(), viewport.get_path())
	var client := MAIN_SCENE.instantiate()
	client.configure_network_from_command_line = false
	var network: Network = client.get_node("Network")
	network.role = Network.Role.CLIENT
	network.port = PORT
	network._hello = "outro-jogo:1".to_utf8_buffer()
	viewport.add_child(client)
	client.detach_local_input()
	await physics_frames(120)
	check((host.session as GameSession).get_player_count() == 1, "host não aceitou o estranho")
	check(_local_player(client) == null, "estranho não recebeu o mundo")
	tree.set_multiplayer(null, viewport.get_path())


# --- Auxiliares ------------------------------------------------------------------------------

func _start_pair() -> Array[Node]:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool: return _local_player(client) != null)
	check(connected, "cliente conectou e recebeu o próprio personagem")
	await physics_frames(10)
	return [host, client]


func _local_player(game: Node) -> Character:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) as Character


## A mesma entidade em outra instância (mesmo ID de entidade).
func _replica(game: Node, entity: Character) -> Character:
	return (game.session as GameSession).get_entity(entity.entity_id) as Character


func _spawn(game: Node) -> Vector2:
	return (game.region as Region).get_spawn_position()


## Criatura com a IA desligada: o teste a posiciona onde quiser (longe de casa ela evadiria).
func _pinned_monster(game: Node) -> Monster:
	var monster := first_monster(game)
	monster.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED
	return monster


static func _min(values: PackedFloat32Array) -> float:
	var result := INF
	for v in values:
		result = minf(result, v)
	return result


static func _max(values: PackedFloat32Array) -> float:
	var result := -INF
	for v in values:
		result = maxf(result, v)
	return result
