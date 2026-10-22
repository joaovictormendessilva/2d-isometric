extends SceneTree
## Custo no host de várias regiões ativas ao mesmo tempo (F2b, ADR-020): cada uma no seu
## próprio mundo (SubViewport com World2D próprio, física separada), com um jogador andando
## e as criaturas dela. Só a primeira é desenhada (a do jogador do host); as outras só
## simulam, como seria no coop com cada um numa região.
##
## Dois cenários por quantidade de regiões:
##   calmo   = criaturas dos pontos da região, jogador andando em círculo;
##   combate = além delas, `CHASERS` slimes perseguindo e atacando cada jogador.
##
## Uso (com janela): Godot --path . --fixed-fps 60 -s res://tests/benchmark_regions.gd [-- 1 2 4]

const REGION_SCENES: Array[PackedScene] = [
	preload("res://scenes/regions/meadow/meadow.tscn"),
	preload("res://scenes/regions/forest/forest.tscn"),
]
const PLAYER_SCENE := preload("res://scenes/actors/character/player.tscn")
const SLIME_SCENE := preload("res://scenes/actors/monsters/slime.tscn")
const DEFAULT_COUNTS: Array[int] = [1, 2, 4]
const CHASERS := 25
## Distância inicial dos perseguidores ao jogador, no plano do chão (dentro da agressão).
const RING_RADIUS := Vector2(40.0, 105.0)
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 900
const TURN_SPEED := 1.5  # radianos por segundo de jogo


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var counts := DEFAULT_COUNTS
	if not OS.get_cmdline_user_args().is_empty():
		counts.assign(Array(OS.get_cmdline_user_args()).map(func(a: String) -> int: return a.to_int()))
	for count in counts:
		for chasers in [0, CHASERS]:
			await _measure(count, chasers)
	quit()


func _measure(count: int, chasers: int) -> void:
	var holder := Node.new()
	root.add_child(holder)
	var players: Array[Character] = []
	var monsters := 0
	for index in count:
		var region: Region = REGION_SCENES[index % REGION_SCENES.size()].instantiate()
		if index == 0:
			holder.add_child(region)  # a região do host: desenhada na janela
		else:
			var world := SubViewport.new()
			world.render_target_update_mode = SubViewport.UPDATE_DISABLED
			holder.add_child(world)
			world.add_child(region)
		# Uma sessão por região: a IA só enxerga o jogador da própria região.
		var session := GameSession.new()
		players.append(_add_player(region, session, index == 0))
		for point in region.get_monster_spawn_points():
			_add_monster(region, session, point.monster_scene, point.position)
			monsters += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = index
		for i in chasers:
			var offset := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(RING_RADIUS.x, RING_RADIUS.y)
			_add_monster(region, session, SLIME_SCENE, players[-1].position + Iso.ground_to_screen(offset))
			monsters += 1

	var stats := FrameStats.new()
	for frame in WARMUP_FRAMES + SAMPLE_FRAMES:
		await process_frame
		stats.tick(frame >= WARMUP_FRAMES)
		for player in players:
			player.set_move_intent(Vector2.from_angle(frame / 60.0 * TURN_SPEED))
	print("[bench] %d região(ões), %s: %s | criaturas %d | nós %d | memória %.0f MB" % [count,
		"combate" if chasers > 0 else "calmo", stats.summary(), monsters,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	holder.free()


func _add_player(region: Region, session: GameSession, with_camera: bool) -> Character:
	var player: Character = PLAYER_SCENE.instantiate()
	player.entity_id = session.allocate_entity_id()
	player.player_id = 1
	player.max_health_multiplier = 1000.0  # sobrevive ao teste inteiro
	player.position = region.get_spawn_position()
	region.entities.add_child(player)
	session.register_entity(player.entity_id, player)
	session.add_player(1, player.entity_id)
	if with_camera:
		var camera := Camera2D.new()
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		player.add_child(camera)
	return player


func _add_monster(region: Region, session: GameSession, scene: PackedScene, at: Vector2) -> void:
	var monster: Monster = scene.instantiate()
	monster.position = at
	(monster.get_node("Brain") as MonsterBrain).session = session
	monster.entity_id = session.allocate_entity_id()
	region.entities.add_child(monster)
