extends SceneTree
## Estresse de itens no chão (docs/03-desempenho.md, Etapa H2): N drops pessoais (gosma) na
## região, no jogo completo (cena principal, sem rede). Cenários:
##   parados = itens pousados em volta, o dono parado fora do ímã de todos (custo de existir);
##   cheio   = o dono no meio dos itens com o inventário cheio (todos tentam ir até ele);
##   coleta  = o dono anda em círculo pegando; cada item pego renasce em outro ponto;
##   queda   = N itens criados no mesmo quadro (um chefe que solta muito): pior quadro.
## Depois, com rede (host + cliente neste processo, ENet em 127.0.0.1): bytes que o host envia
## ao cliente quando caem N drops do cliente e N drops do próprio host.
##
## Uso (com janela): Godot --path . --fixed-fps 60 -s res://tests/benchmark_drops.gd [-- 200 500]

const GEL: ItemData = preload("res://data/items/gel.tres")
const DEFAULT_COUNTS: Array[int] = [200, 500]
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 600
## Quadros medidos depois de uma queda (o salto dura `Pickup.POP_TIME`).
const BURST_FRAMES := 60
## Área dos itens: anel no plano do chão em volta do jogador (fica na tela).
const FIELD_RADIUS := 130.0
## "parados": nenhum item dentro do ímã do dono (raio 16 + folga).
const IDLE_MIN_RADIUS := 30.0
const DROP_CLEARANCE := 4.0
const TURN_SPEED := 1.5  # radianos por segundo de jogo (coleta)
const NET_PORT := 24790
## Tempo de rede medido depois de cada queda: o envio de N criações leva alguns quadros.
const NET_SETTLE_FRAMES := 120

var _helper := TestCase.new()


func _initialize() -> void:
	_helper.tree = self
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var counts := DEFAULT_COUNTS
	if not OS.get_cmdline_user_args().is_empty():
		counts.assign(Array(OS.get_cmdline_user_args()).map(func(a: String) -> int: return a.to_int()))
	for count in counts:
		for scenario in ["parados", "cheio", "coleta"]:
			await _measure(count, scenario)
		await _measure_burst(count)
	for count in counts:
		await _measure_network(count)
	quit()


func _measure(count: int, scenario: String) -> void:
	var game := await _start_offline()
	var player := _local_player(game)
	var inventory := _local_inventory(game)
	if scenario == "cheio":
		inventory.add(GEL.id, 1_000_000)  # todas as pilhas cheias: nada mais cabe
	var min_radius := IDLE_MIN_RADIUS if scenario == "parados" else 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = count
	var center := player.position
	var on_ground := [0]  # em lista: as funções abaixo mudam o valor
	var respawn := func(_pickup: Pickup) -> void: on_ground[0] -= 1
	for i in count:
		_drop(game, _spot(game, center, rng, min_radius), respawn)
		on_ground[0] += 1

	var stats := FrameStats.new()
	var angle := 0.0
	for frame in WARMUP_FRAMES + SAMPLE_FRAMES:
		if scenario == "coleta":
			angle += TURN_SPEED / Engine.physics_ticks_per_second
			player.set_move_intent(Vector2.from_angle(angle))
			inventory.remove(GEL.id, inventory.count(GEL.id))  # sempre há espaço
			while on_ground[0] < count:
				_drop(game, _spot(game, center, rng, 0.0), respawn)
				on_ground[0] += 1
		await process_frame
		stats.tick(frame >= WARMUP_FRAMES)
	_report("%d itens, %s" % [count, scenario], stats)
	_helper.cleanup()


## N itens criados no mesmo quadro, saltando de um ponto só (como o drop de um chefe).
func _measure_burst(count: int) -> void:
	var game := await _start_offline()
	var center := _local_player(game).position + Iso.ground_to_screen(Vector2(60.0, 0.0))
	var spawner := _spawner(game)
	var region: Region = game.region
	var space := region.entities.get_world_2d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = count
	var stats := FrameStats.new()
	stats.tick(false)
	var start := Time.get_ticks_usec()
	for i in count:
		var spot := GroundQuery.find_drop_spot(space, center, rng, EntitySpawner.DROP_DISTANCE_MIN,
			EntitySpawner.DROP_DISTANCE_MAX, EntitySpawner.DROP_CLEARANCE)
		spawner.spawn_pickup(region, GEL, 1, game.local_player_id(), center, spot)
	var spawn_ms := (Time.get_ticks_usec() - start) / 1000.0
	for frame in BURST_FRAMES:
		await process_frame
		stats.tick()
	_report("%d itens, queda (criação %.1f ms no quadro)" % [count, spawn_ms], stats)
	_helper.cleanup()


## Bytes do host para o cliente: N drops do cliente (ele precisa recebê-los) e N do host (o
## cliente não os vê).
func _measure_network(count: int) -> void:
	var host := _helper.start_network_game("Host", Network.Role.HOST, NET_PORT)
	var client := _helper.start_network_game("Client", Network.Role.CLIENT, NET_PORT)
	var connected := await _helper.wait_until(func() -> bool: return _local_player(client) != null)
	if not connected:
		push_error("[bench] o cliente não conectou")
		_helper.cleanup()
		return
	_helper.calm_monsters(host)
	await _helper.physics_frames(30)
	var enet := (host.multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
	var rng := RandomNumberGenerator.new()
	rng.seed = count
	var owners := {"do cliente": client.local_player_id(), "do host": host.local_player_id()}
	for label: String in owners:
		var owner_body := (host.session as GameSession).get_player_entity(owners[label]) as Character
		# Fundo: o mesmo tempo sem queda (movimento, vida...), descontado da queda.
		enet.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)  # zera o contador
		await _helper.physics_frames(NET_SETTLE_FRAMES)
		var background := enet.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
		var before := _helper.pickups(client).size()
		for i in count:
			_drop(host, _spot(host, owner_body.position, rng, IDLE_MIN_RADIUS), Callable(), owners[label])
		await _helper.physics_frames(NET_SETTLE_FRAMES)
		var burst := maxf(enet.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) - background, 0.0)
		await _helper.physics_frames(Engine.physics_ticks_per_second * 5)
		var steady := enet.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / 5.0
		print("[bench] rede, %d drops %s: queda +%.1f KB (%.0f B por item) | depois %.1f KB/s (fundo %.1f) | chegaram ao cliente %d" % [
			count, label, burst / 1024.0, burst / count, steady / 1024.0,
			background / 1024.0 * Engine.physics_ticks_per_second / NET_SETTLE_FRAMES,
			_helper.pickups(client).size() - before])
	_helper.cleanup()


func _start_offline() -> Node:
	var game := _helper.start_game()
	await _helper.physics_frames(10)
	_helper.calm_monsters(game)
	return game


## Item já pousado em `at` (origem = destino: sem salto), do jogador local por padrão.
func _drop(game: Node, at: Vector2, on_collected: Callable, owner_id: int = 0) -> void:
	var pickup := _spawner(game).spawn_pickup(game.region, GEL, 1,
		owner_id if owner_id != 0 else game.local_player_id(), at, at)
	if on_collected.is_valid():
		pickup.collected.connect(on_collected)


## Ponto andável aleatório no anel em volta de `center` (`GroundQuery`, como os drops do jogo).
func _spot(game: Node, center: Vector2, rng: RandomNumberGenerator, min_radius: float) -> Vector2:
	var space := (game.region as Region).entities.get_world_2d().direct_space_state
	for attempt in GroundQuery.SPOT_ATTEMPTS:
		var at := center + Iso.ground_to_screen(
			Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(min_radius, FIELD_RADIUS))
		if GroundQuery.is_walkable(space, at, DROP_CLEARANCE):
			return at
	return center + Iso.ground_to_screen(Vector2(min_radius, 0.0))


func _report(label: String, stats: FrameStats) -> void:
	print("[bench] %s: %s | draw calls %d | nós %d" % [label, stats.summary(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])


func _spawner(game: Node) -> EntitySpawner:
	return game.get_node("EntitySpawner")


func _local_player(game: Node) -> Character:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) as Character


func _local_inventory(game: Node) -> Inventory:
	return (game.session as GameSession).get_inventory(game.local_player_id())
