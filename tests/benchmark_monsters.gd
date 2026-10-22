extends SceneTree
## Estresse de criaturas (docs/03-desempenho.md): N slimes perseguindo e atacando um jogador
## numa arena vazia.
##
## Uso: Godot --path . --fixed-fps 60 -s res://tests/benchmark_monsters.gd [-- 50 100 200]

const PLAYER_SCENE := preload("res://scenes/actors/character/player.tscn")
const SLIME_SCENE := preload("res://scenes/actors/monsters/slime.tscn")
const DEFAULT_COUNTS: Array[int] = [50, 100, 200]
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 600
## Distância inicial ao jogador, no plano do chão: dentro do raio de agressão do slime.
const RING_RADIUS := Vector2(40.0, 105.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var counts := DEFAULT_COUNTS
	if not OS.get_cmdline_user_args().is_empty():
		counts.assign(Array(OS.get_cmdline_user_args()).map(func(a: String) -> int: return a.to_int()))
	for count in counts:
		await _measure(count)
	quit()


func _measure(count: int) -> void:
	var arena := Node2D.new()
	arena.y_sort_enabled = true
	root.add_child(arena)

	var session := GameSession.new()
	var player: Character = PLAYER_SCENE.instantiate()
	player.entity_id = session.allocate_entity_id()
	player.max_health_multiplier = 1000.0  # sobrevive ao teste inteiro
	arena.add_child(player)
	session.register_entity(player.entity_id, player)
	session.add_player(1, player.entity_id)
	var camera := Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	player.add_child(camera)

	var rng := RandomNumberGenerator.new()
	rng.seed = count
	for i in count:
		var slime: Monster = SLIME_SCENE.instantiate()
		var offset := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(RING_RADIUS.x, RING_RADIUS.y)
		slime.position = Iso.ground_to_screen(offset)
		(slime.get_node("Brain") as MonsterBrain).session = session
		slime.entity_id = session.allocate_entity_id()
		arena.add_child(slime)

	var stats := FrameStats.new()
	for frame in WARMUP_FRAMES + SAMPLE_FRAMES:
		await process_frame
		stats.tick(frame >= WARMUP_FRAMES)
	print("[bench] %d slimes: %s | nós %d" % [
		count, stats.summary(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	arena.free()
