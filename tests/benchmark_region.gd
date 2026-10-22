extends SceneTree
## Mede o custo de quadro da região inicial com o personagem andando em círculo (a câmera
## rola o cenário). Sem vsync e sem limite de FPS, o tempo médio de quadro = custo real.
##
## Uso (com janela, para medir a renderização):
##   Godot --path . -s res://tests/benchmark_region.gd

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 1200
const TURN_SPEED := 1.5  # radianos por segundo da direção de caminhada


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	game.detach_local_input()
	var player := (game.session as GameSession).get_player_entity(game.LOCAL_PLAYER_ID) as Character

	var samples := PackedFloat32Array()
	var draw_calls := 0.0
	var angle := 0.0
	var last := Time.get_ticks_usec()
	for i in WARMUP_FRAMES + SAMPLE_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := (now - last) / 1000.0
		last = now
		angle += TURN_SPEED * frame_ms / 1000.0
		player.set_move_intent(Vector2.from_angle(angle))
		if i >= WARMUP_FRAMES:
			samples.append(frame_ms)
			draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	samples.sort()
	var total := 0.0
	for s in samples:
		total += s
	var avg := total / samples.size()
	print("[bench] renderer=%s quadros=%d" % [RenderingServer.get_current_rendering_method(), samples.size()])
	print("[bench] média %.3f ms (%.0f FPS) | p95 %.3f ms | pior %.3f ms | draw calls %.1f" % [
		avg, 1000.0 / avg, samples[int(samples.size() * 0.95)], samples[-1], draw_calls / samples.size()])
	print("[bench] memória estática %.1f MB | nós %d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	quit()
