extends SceneTree
## Captura uma animação do jogo como FOLHA DE QUADROS (contact sheet): roda um cenário, guarda
## um quadro a cada N passos e monta tudo numa imagem só, ampliada, em ordem (esquerda →
## direita, cima → baixo). Assim dá para enxergar movimento, ritmo e "juice" sem vídeo
## (skill `game-motion-capture`).
##
## Rodar (com janela; `--fixed-fps 60` = 1 passo de física por quadro, tempo exato):
##   G --path . --fixed-fps 60 -s res://tools/capture_frames.gd -- --out=<arquivo.png> [opções]
## Opções:
##   --scenario=<nome>  idle | walk | attack | gather | inventory  (padrão: attack)
##   --frames=<n>       quadros na folha (padrão 16)
##   --every=<n>        passos de física entre quadros (padrão 2 = 30 quadros/s)
##   --crop=<L>x<A>     recorte em volta do jogador, em pixels do jogo (padrão 96x72;
##                      0x0 = tela inteira)
##   --scale=<n>        ampliação de cada quadro (padrão 3)
##   --columns=<n>      quadros por linha (padrão 8)
##   --warmup=<n>       passos antes de começar (padrão 30)

const MAIN_SCENE := "res://scenes/main/main.tscn"
const SEPARATOR := Color(0.9, 0.2, 0.9)  # magenta: nunca confunde com a arte
const ATTACK_DIRECTION := Vector2.RIGHT
const WALK_DIRECTION := Vector2(1, 0.5)
## Distância (no chão) em que a criatura é posta à frente no cenário de ataque.
const TARGET_DISTANCE := 22.0

var _options := {
	"scenario": "attack", "frames": "16", "every": "2", "crop": "96x72", "scale": "3",
	"columns": "8", "warmup": "30", "out": "",
}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2 and _options.has(parts[0]):
			_options[parts[0]] = parts[1]
	if _options["out"].is_empty():
		push_error("[capture] faltou --out=<arquivo.png>")
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	UserSettings.path = "user://capture_settings.cfg"  # não mexe nas preferências de quem joga
	UserSettings.clear()
	var game: Node = load(MAIN_SCENE).instantiate()
	root.add_child(game)
	for i in int(_options["warmup"]):
		await physics_frame
	var character := (game.session as GameSession).get_player_entity(game.local_player_id()) as Character
	game.detach_local_input()
	var scenario: String = _options["scenario"]
	_prepare(game, character, scenario)

	var frames: Array[Image] = []
	var every := maxi(int(_options["every"]), 1)
	var step := 0
	while frames.size() < int(_options["frames"]):
		_act(character, scenario)
		await RenderingServer.frame_post_draw
		if step % every == 0:
			frames.append(_crop(root.get_texture().get_image(), _screen_position(character)))
		step += 1
	var sheet := _sheet(frames)
	var error := sheet.save_png(_options["out"])
	print("[capture] %s: %d quadros (%s), %s" % [_options["out"], frames.size(), scenario,
		error_string(error)])
	UserSettings.clear()
	quit(error)


## Monta o cenário uma vez (posições, alvos, janelas abertas).
func _prepare(game: Node, character: Character, scenario: String) -> void:
	match scenario:
		"attack":
			var monster := _nearest_monster(game, character)
			if monster:
				monster.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED
				monster.position = character.position + Iso.ground_to_screen(
					ATTACK_DIRECTION * TARGET_DISTANCE)
				monster.reset_physics_interpolation()
		"gather":
			var node := _nearest_resource_node(game, character)
			if node:
				character.position = node.approach_point(character.footprint_radius())
				character.reset_physics_interpolation()
		"inventory":
			(game.get_node("UI/InventoryPanel") as InventoryPanel).set_open(true)


## Intenções a cada passo (como o jogador segurando a tecla).
func _act(character: Character, scenario: String) -> void:
	match scenario:
		"walk":
			character.set_move_intent(WALK_DIRECTION)
		"attack":
			character.request_attack(Iso.screen_to_ground(ATTACK_DIRECTION))
		"gather":
			character.request_gather()


func _screen_position(character: Character) -> Vector2:
	return character.get_viewport().get_canvas_transform() * character.global_position


func _crop(image: Image, center: Vector2) -> Image:
	var size := _crop_size()
	if size == Vector2i.ZERO:
		return image
	# O jogador fica um pouco abaixo do centro: há mais coisa acima dos pés (corpo, efeitos).
	var origin := Vector2i(center) - Vector2i(size.x / 2, size.y * 2 / 3)
	origin = origin.clamp(Vector2i.ZERO, image.get_size() - size)
	return image.get_region(Rect2i(origin, size))


func _crop_size() -> Vector2i:
	var parts: PackedStringArray = _options["crop"].split("x")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2i.ZERO


## Junta os quadros numa grade ampliada (vizinho mais próximo: pixels nítidos), separados por
## uma linha magenta.
func _sheet(frames: Array[Image]) -> Image:
	var scale := maxi(int(_options["scale"]), 1)
	var columns := mini(maxi(int(_options["columns"]), 1), frames.size())
	var rows := ceili(frames.size() / float(columns))
	var cell := frames[0].get_size() * scale
	var sheet := Image.create(columns * (cell.x + 1) + 1, rows * (cell.y + 1) + 1, false,
		Image.FORMAT_RGBA8)
	sheet.fill(SEPARATOR)
	for i in frames.size():
		var frame := frames[i]
		frame.convert(Image.FORMAT_RGBA8)
		frame.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
		var at := Vector2i(i % columns, i / columns) * (cell + Vector2i.ONE) + Vector2i.ONE
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, cell), at)
	return sheet


func _nearest_monster(game: Node, character: Character) -> Monster:
	return _nearest(game, character, func(n: Node) -> bool: return n is Monster) as Monster


func _nearest_resource_node(game: Node, character: Character) -> ResourceNode:
	return _nearest(game, character, func(n: Node) -> bool:
		return n is ResourceNode and not n.is_depleted() and n.data.min_tool_tier == 0) as ResourceNode


func _nearest(game: Node, character: Character, accept: Callable) -> Node2D:
	var best: Node2D
	for node in (game.region as Region).entities.get_children():
		if accept.call(node) and (best == null or character.position.distance_to(node.position)
				< character.position.distance_to(best.position)):
			best = node
	return best
