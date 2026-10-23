extends SceneTree
## Coop na mesma região (docs/03-desempenho.md, Etapa H3): custo do HOST e tráfego com 1, 2 e 4
## jogadores. O host roda nesta janela; cada cliente é OUTRO processo da Godot (sem janela), como
## outro computador, para o tempo medido ser só o do host. Todos andam em círculo em volta do
## primeiro ponto de criaturas da campina. Dois modos:
##   andando = criaturas paradas, ninguém golpeia (movimento e presença);
##   combate = criaturas ativas e todos golpeando sem parar (dano, recuo, mortes, drops).
##
## Mede, por quadro do host: lógica + física + desenho na CPU (monitores da Godot; sem
## `--fixed-fps`: o jogo corre em tempo real, como os clientes). E o tráfego do host (ENet).
##
## Uso (com janela, SEM --fixed-fps): Godot --path . -s res://tests/benchmark_coop.gd [-- 1 2 4]
## O próprio script abre os clientes com `-- --client=<n> --port=<p> --mode=<modo> --seconds=<s>`.

const PORT := 24810
const DEFAULT_COUNTS: Array[int] = [1, 2, 4]
const MODES: Array[String] = ["andando", "combate"]
const WARMUP_SECONDS := 6.0  # todos conectarem e chegarem ao círculo
const SAMPLE_SECONDS := 15.0
const CONNECT_TIMEOUT_FRAMES := 900
## Círculo no plano do chão em volta do ponto de criaturas; cada jogador numa fase.
const CIRCLE_RADIUS := 45.0
const TURN_SPEED := 0.8  # radianos por segundo
## Vida dos jogadores no combate: ninguém morre no meio da medição (só o host decide isso).
const HEALTH_MULTIPLIER := 1000.0

var _helper := TestCase.new()
var _options := {"client": "", "port": str(PORT), "mode": "andando", "seconds": "0"}


func _initialize() -> void:
	_helper.tree = self
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2 and _options.has(parts[0]):
			_options[parts[0]] = parts[1]
	if _options["client"].is_empty():
		_run_host.call_deferred()
	else:
		_run_client.call_deferred()


# --- Host (esta janela) ------------------------------------------------------------------------

func _run_host() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = Engine.physics_ticks_per_second  # 1 passo de física por quadro, em média
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var counts := DEFAULT_COUNTS
	var numbers := Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool: return a.is_valid_int())
	if not numbers.is_empty():
		counts.assign(numbers.map(func(a: String) -> int: return a.to_int()))
	var port := PORT
	for count in counts:
		for mode in MODES:
			port += 1  # porta nova a cada rodada: a anterior pode demorar a liberar
			await _measure_host(count, mode, port)
	quit()


func _measure_host(count: int, mode: String, port: int) -> void:
	var host := _helper.start_network_game("Main", Network.Role.HOST, port, "", true)
	await physics_frame
	var clients: Array[int] = []
	var seconds := WARMUP_SECONDS + SAMPLE_SECONDS + 5.0  # os clientes saem sozinhos depois
	for index in count - 1:
		clients.append(OS.create_process(OS.get_executable_path(), ["--headless", "--path",
			ProjectSettings.globalize_path("res://"), "-s", "res://tests/benchmark_coop.gd", "--",
			"--client=%d" % (index + 1), "--port=%d" % port, "--mode=" + mode,
			"--seconds=%d" % ceili(seconds)]))
	var session: GameSession = host.session
	var all_in := await _helper.wait_until(func() -> bool: return session.get_player_count() == count,
		CONNECT_TIMEOUT_FRAMES)
	if not all_in:
		push_error("[bench] só %d de %d jogadores entraram" % [session.get_player_count(), count])
		_stop(clients)
		return
	if mode == "andando":
		_helper.calm_monsters(host)
	var enet := (host.multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
	var cpu := FrameStats.new()
	var start := Time.get_ticks_msec()
	var sampling := false
	var sent := 0
	var received := 0
	while Time.get_ticks_msec() - start < (WARMUP_SECONDS + SAMPLE_SECONDS) * 1000.0:
		var elapsed := (Time.get_ticks_msec() - start) / 1000.0
		if not sampling and elapsed >= WARMUP_SECONDS:
			sampling = true
			enet.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)  # zera os contadores
			enet.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
		if mode == "combate":
			for player_id in session.get_player_ids():
				var body := session.get_player_entity(player_id) as Character
				if body:
					body.max_health_multiplier = HEALTH_MULTIPLIER
					body.health.set_current(body.health.max_health)
		_steer(host, _local_player(host), 0, elapsed, mode)
		await process_frame
		if sampling:
			cpu.record(_host_cpu_ms())
	sent = enet.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	received = enet.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	print("[bench] %d jogador(es), %s: CPU do host %s | host envia %.1f KB/s (%.1f por cliente), recebe %.1f KB/s | entidades %d | draw calls %d" % [
		count, mode, cpu.summary(), sent / 1024.0 / SAMPLE_SECONDS,
		sent / 1024.0 / SAMPLE_SECONDS / maxi(count - 1, 1), received / 1024.0 / SAMPLE_SECONDS,
		session.get_entity_count(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	_stop(clients)
	_helper.cleanup()
	await _helper.physics_frames(30)


## Lógica (process), física e desenho (CPU) do último quadro, em ms.
func _host_cpu_ms() -> float:
	return (Performance.get_monitor(Performance.TIME_PROCESS)
		+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0 \
		+ RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) \
		+ RenderingServer.get_frame_setup_time_cpu()


func _stop(clients: Array[int]) -> void:
	for pid in clients:
		if OS.is_process_running(pid):
			OS.kill(pid)


# --- Cliente (outro processo, sem janela) ------------------------------------------------------

func _run_client() -> void:
	var index := int(_options["client"])
	# Cada cliente é "outro computador": identidade própria (o host recusa a mesma duas vezes).
	PlayerProfile.path = "user://bench_profile_%d.cfg" % index
	var game := _helper.start_network_game("Client", Network.Role.CLIENT, int(_options["port"]))
	var connected := await _helper.wait_until(func() -> bool: return _local_player(game) != null,
		CONNECT_TIMEOUT_FRAMES)
	if not connected:
		push_error("[bench] cliente %d não conectou" % index)
		quit(1)
		return
	var start := Time.get_ticks_msec()
	var seconds := float(_options["seconds"])
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		var player := _local_player(game)  # renascer não recria o personagem; viajar recriaria
		if player:
			_steer(game, player, index, (Time.get_ticks_msec() - start) / 1000.0, _options["mode"])
		await physics_frame
	quit()


# --- Comum -------------------------------------------------------------------------------------

## Leva o jogador para o seu ponto no círculo (como alguém segurando as teclas) e, no combate,
## golpeia na direção em que anda.
func _steer(game: Node, player: Character, index: int, elapsed: float, mode: String) -> void:
	if player == null or not player.is_alive():
		return
	var region: Region = game.region
	var center := region.get_monster_spawn_points()[0].position
	var angle := TAU * index / 4.0 + elapsed * TURN_SPEED
	var target := center + Iso.ground_to_screen(Vector2.from_angle(angle) * CIRCLE_RADIUS)
	var direction := Iso.screen_to_ground(target - player.position)
	player.set_move_intent(direction.normalized() if direction.length() > 2.0 else Vector2.ZERO)
	if mode == "combate":
		player.request_attack(direction.normalized() if direction.length() > 0.1 else Vector2.RIGHT)


func _local_player(game: Node) -> Character:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) as Character
