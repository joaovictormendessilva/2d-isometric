class_name DebugOverlay
extends Label
## Painel de debug (F3): FPS, tempo de quadro, draw calls, entidades, posição do jogador, velocidade,
## defesa, efeitos ativos e a qualidade dos efeitos (F4 troca, só com o painel aberto, até existir
## um menu de opções).

var session: GameSession
var player_id := 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug"):
		visible = not visible
	elif visible and event.is_action_pressed(&"cycle_effects_quality"):
		VfxQuality.shared().cycle()


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
		_quality_line(),
	])
	if session != null:
		lines.append("jogadores %d  |  entidades %d" % [
			session.get_player_count(), session.get_entity_count()])
		var player := session.get_player_entity(player_id) as Node2D
		if player != null:
			var g := Iso.screen_to_ground(player.position)
			lines.append("jogador %d  tela (%d, %d)  chão (%d, %d)" % [
				player_id, player.position.x, player.position.y, g.x, g.y])
		var character := player as Character
		if character != null:
			lines.append(_stats_line(character))
	text = "\n".join(lines)


func _quality_line() -> String:
	var quality := VfxQuality.shared()
	return "efeitos %s (F4 troca)  |  partículas %d / %d" % [quality.level().id,
		quality.in_use(), quality.level().particle_budget]


## Velocidade (base → atual), defesa e efeitos ativos com os segundos: conferir buffs e debuffs.
func _stats_line(character: Character) -> String:
	var effects := PackedStringArray()
	if character.status_effects:
		for entry in character.status_effects.effects.entries():
			effects.append("%s %.1fs" % [entry.data.id, entry.remaining])
	return "velocidade %d -> %d  |  defesa %d  |  efeitos: %s" % [character.stats.move_speed,
		character.move_speed(), character.health.defense if character.health else 0,
		", ".join(effects) if not effects.is_empty() else "nenhum"]
