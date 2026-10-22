class_name DebugOverlay
extends Label
## Painel de debug (F3): FPS, tempo de quadro, draw calls, entidades e posição do jogador.

var session: GameSession
var player_id := 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible:
		return
	var lines := PackedStringArray([
		"FPS %d  |  quadro %.2f ms  |  física %.2f ms" % [
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0],
		"draw calls %d  |  nós %d" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)],
	])
	if session != null:
		lines.append("jogadores %d  |  entidades %d" % [
			session.get_player_count(), session.get_entity_count()])
		var player := session.get_player_entity(player_id) as Node2D
		if player != null:
			var g := Iso.screen_to_ground(player.position)
			lines.append("jogador %d  tela (%d, %d)  chão (%d, %d)" % [
				player_id, player.position.x, player.position.y, g.x, g.y])
	text = "\n".join(lines)
