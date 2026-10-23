extends SceneTree
## Estresse de auras (docs/03-desempenho.md, G3d): N personagens parados, todos na tela, primeiro
## sem aura (base) e depois com a aura da Coroa do Rei Slime, em cada nível de qualidade dos
## efeitos (ADR-028). A diferença entre as duas medições é o custo das auras.
##
## Uso: Godot --path . --fixed-fps 60 -s res://tests/benchmark_auras.gd [-- 10 30 60]

const PLAYER_SCENE := preload("res://scenes/actors/character/player.tscn")
const CROWN: EquipmentData = preload("res://data/items/king_slime_crown.tres")
const DEFAULT_COUNTS: Array[int] = [10, 30, 60]
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 600
## Distância entre personagens na grade (no plano da tela): 60 cabem em 640×360.
const SPACING := Vector2(44.0, 36.0)
const COLUMNS := 10


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var counts := DEFAULT_COUNTS
	if not OS.get_cmdline_user_args().is_empty():
		counts.assign(Array(OS.get_cmdline_user_args()).map(func(a: String) -> int: return a.to_int()))
	var quality := VfxQuality.shared()
	for count in counts:
		await _measure(count, false, "sem aura")
		for index in quality.level_count():
			quality.set_level(index, false)
			await _measure(count, true, String(quality.level().id))
	quit()


func _measure(count: int, with_auras: bool, label: String) -> void:
	var arena := Node2D.new()
	arena.y_sort_enabled = true
	root.add_child(arena)
	var origin := -Vector2(COLUMNS - 1, ceili(count / float(COLUMNS)) - 1) * SPACING / 2.0
	for i in count:
		var player: Character = PLAYER_SCENE.instantiate()
		player.position = origin + Vector2(i % COLUMNS, i / COLUMNS) * SPACING
		if with_auras:
			player.auras.assign([CROWN.aura])
		arena.add_child(player)
	var camera := Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	arena.add_child(camera)

	var stats := FrameStats.new()
	for frame in WARMUP_FRAMES + SAMPLE_FRAMES:
		await process_frame
		stats.tick(frame >= WARMUP_FRAMES)
	print("[bench] %d personagens, %s: %s | partículas %d | draw calls %d | nós %d" % [
		count, label, stats.summary(), VfxQuality.shared().in_use(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	arena.free()
