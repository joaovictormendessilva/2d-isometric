extends SceneTree
## Verificações que precisam da imagem desenhada (os testes de `run_tests.gd` rodam sem tela e
## não enxergam pixels). Hoje: os textos do mundo (dano, itens ganhos, "[E] Coletar") aparecem
## na região inicial e continuam aparecendo depois de viajar para outra região.
##
## Uso (com janela): Godot --path . --fixed-fps 60 -s res://tests/render_checks.gd
## Sai com código 1 se alguma verificação falhar.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
## Cor que não existe no mapa (magenta): pixels perto dela só podem vir do texto de teste.
const MARK_COLOR := Color(1.0, 0.0, 1.0)
const MIN_MARK_PIXELS := 20
const TRAVEL_FRAMES := 60

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveService.default_path = ""  # não lê nem grava o save de quem joga
	var game: Node = MAIN_SCENE.instantiate()
	game.use_debug_starter_kit = false
	root.add_child(game)
	game.detach_local_input()
	await _check_world_text(game, "campina")

	var player := _player(game)
	player.position = (game.region as Region).get_passage(&"to_forest").global_position
	player.reset_physics_interpolation()
	for i in TRAVEL_FRAMES:
		await physics_frame
	if game.region.region_id != &"forest":
		_failures.append("não chegou na floresta")
	await _check_world_text(game, "floresta (depois de viajar)")

	for failure in _failures:
		print("  FALHA ", failure)
	print("[render] %s" % ("ok" if _failures.is_empty() else "%d falha(s)" % _failures.size()))
	quit(0 if _failures.is_empty() else 1)


func _check_world_text(game: Node, where: String) -> void:
	var numbers: DamageNumbers = game.get_node("WorldText/DamageNumbers")
	numbers.show_text(_player(game).position, "TESTE", MARK_COLOR, 5.0)
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var pixels := _count_mark_pixels(root.get_texture().get_image())
	if pixels < MIN_MARK_PIXELS:
		_failures.append("texto do mundo invisível na %s (%d pixels da cor de teste)" % [where, pixels])


func _count_mark_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.r > 0.8 and pixel.g < 0.3 and pixel.b > 0.8:  # o texto já começa a sumir
				count += 1
	return count


func _player(game: Node) -> Character:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) as Character
