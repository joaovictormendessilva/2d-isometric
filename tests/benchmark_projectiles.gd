extends SceneTree
## Estresse de projéteis (docs/03-desempenho.md, Etapa H): N projéteis do Projétil arcano no ar
## ao mesmo tempo (quem some é reposto no quadro seguinte), em cada nível de qualidade dos efeitos
## (ADR-028). Dois cenários: "no ar" (sem alvos: voo, busca de alvo e desenho) e "com alvos"
## (slimes em volta que levam os acertos: dano, recuo e faíscas de impacto).
##
## Uso: Godot --path . --fixed-fps 60 -s res://tests/benchmark_projectiles.gd [-- 200 500 1000]

const PLAYER_SCENE := preload("res://scenes/actors/character/player.tscn")
const SLIME_SCENE := preload("res://scenes/actors/monsters/slime.tscn")
const BOLT: AbilityData = preload("res://data/abilities/arcane_bolt.tres")
const DEFAULT_COUNTS: Array[int] = [200, 500, 1000]
## Maior que um voo inteiro (alcance / velocidade = ~43 quadros), para encher antes de medir.
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 600
## Onde os projéteis nascem, no plano do chão em volta do jogador: espalha o voo pela tela.
const LAUNCH_RADIUS := 120.0
## Slimes do cenário "com alvos", em anel no plano do chão (ficam na tela).
const TARGET_COUNT := 40
const TARGET_RING := Vector2(50.0, 110.0)
## Ninguém morre no meio da medição (o teste mede projéteis, não respawn).
const HEALTH_MULTIPLIER := 100000.0

## Projéteis vivos na medição atual.
var _flying := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var counts := DEFAULT_COUNTS
	if not OS.get_cmdline_user_args().is_empty():
		counts.assign(Array(OS.get_cmdline_user_args()).map(func(a: String) -> int: return a.to_int()))
	var quality := VfxQuality.shared()
	for count in counts:
		for index in quality.level_count():
			quality.set_level(index, false)
			await _measure(count, 0, "no ar, %s" % quality.level().id)
			await _measure(count, TARGET_COUNT, "com alvos, %s" % quality.level().id)
	quit()


func _measure(count: int, targets: int, label: String) -> void:
	var arena := Node2D.new()
	arena.y_sort_enabled = true
	root.add_child(arena)

	var session := GameSession.new()
	var player: Character = PLAYER_SCENE.instantiate()
	player.entity_id = session.allocate_entity_id()
	player.max_health_multiplier = HEALTH_MULTIPLIER
	arena.add_child(player)
	session.register_entity(player.entity_id, player)
	session.add_player(1, player.entity_id)
	var camera := Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	player.add_child(camera)

	var rng := RandomNumberGenerator.new()
	rng.seed = count
	for i in targets:
		var slime: Monster = SLIME_SCENE.instantiate()
		slime.position = Iso.ground_to_screen(_random_ground_point(rng, TARGET_RING.x, TARGET_RING.y))
		slime.max_health_multiplier = HEALTH_MULTIPLIER
		(slime.get_node("Brain") as MonsterBrain).session = session
		slime.entity_id = session.allocate_entity_id()
		arena.add_child(slime)

	# Lançar todos de uma vez faria todos sumirem e renascerem juntos (ondas, não regime): o
	# aquecimento enche aos poucos, uma leva por quadro ao longo de um voo inteiro.
	var flight_frames := ceili(BOLT.projectile.max_range / BOLT.projectile.speed
		* Engine.physics_ticks_per_second)
	var per_frame := ceili(count / float(flight_frames))
	var stats := FrameStats.new()
	for frame in WARMUP_FRAMES + SAMPLE_FRAMES:
		var launches := 0
		while _flying < count and launches < per_frame:
			_launch(arena, player, rng)
			launches += 1
		await process_frame
		stats.tick(frame >= WARMUP_FRAMES)
	print("[bench] %d projéteis, %s: %s | partículas %d | draw calls %d | nós %d" % [
		count, label, stats.summary(), VfxQuality.shared().in_use(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	arena.free()
	_flying = 0


func _launch(arena: Node2D, caster: Character, rng: RandomNumberGenerator) -> void:
	var projectile := Projectile.new()
	projectile.setup(BOLT.projectile, caster, Vector2.from_angle(rng.randf() * TAU), BOLT.damage,
		BOLT.knockback, BOLT.hit_effects)
	projectile.position = caster.position \
		+ Iso.ground_to_screen(_random_ground_point(rng, 0.0, LAUNCH_RADIUS))
	# Some ao acertar ou no fim do alcance (queue_free): o laço repõe no quadro seguinte.
	projectile.tree_exiting.connect(func() -> void: _flying -= 1)
	arena.add_child(projectile)
	_flying += 1


func _random_ground_point(rng: RandomNumberGenerator, min_radius: float, max_radius: float) -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(min_radius, max_radius)
