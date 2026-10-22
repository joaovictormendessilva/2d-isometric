extends SceneTree
## Mede o custo de quadro da região inicial (com suas criaturas) e o personagem andando em
## círculo, para a câmera rolar o cenário.
##
## Uso (com janela, para medir também o desenho):
##   Godot --path . --fixed-fps 60 -s res://tests/benchmark_region.gd

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 1200
const TURN_SPEED := 1.5  # radianos por segundo de jogo


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	game.detach_local_input()
	var player := (game.session as GameSession).get_player_entity(game.LOCAL_PLAYER_ID) as Character

	var stats := FrameStats.new()
	var draw_calls := 0.0
	for frame in WARMUP_FRAMES + SAMPLE_FRAMES:
		await process_frame
		var recording := frame >= WARMUP_FRAMES
		stats.tick(recording)
		player.set_move_intent(Vector2.from_angle(frame / 60.0 * TURN_SPEED))
		if recording:
			draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	print("[bench] região: %s | draw calls %.1f" % [stats.summary(), draw_calls / SAMPLE_FRAMES])
	print("[bench] memória estática %.1f MB | nós %d | entidades %d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		(game.session as GameSession).get_entity_count()])
	quit()
