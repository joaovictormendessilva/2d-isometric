extends SceneTree
## Confere um sprite de pixel art (skill `pixel-art-style`): conta cores, acha pixels soltos
## e semitransparentes, cores fora da paleta, e monta uma PRÉVIA lado a lado (original,
## em tons de cinza = contraste de valores, e silhueta), ampliada, para olhar.
##
## Rodar: G --headless --path . -s res://tools/art_check.gd -- <sprite.png> [opções]
##   --palette=<png>   cada pixel deste arquivo é uma cor permitida
##   --preview=<png>   onde salvar a prévia (padrão: não salva)
##   --scale=<n>       ampliação da prévia (padrão 6)
##   --max-colors=<n>  avisa acima disso (padrão 16)

const PREVIEW_BACK := Color(0.9, 0.2, 0.9)
const SILHOUETTE := Color(0.08, 0.08, 0.1)
const SILHOUETTE_BACK := Color(0.92, 0.92, 0.88)
const NEIGHBORS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
## Valores (luminância) mais próximos que isso contam como "o mesmo tom" na escala de cinza.
const VALUE_STEP := 0.06


func _initialize() -> void:
	var path := ""
	var options := {"palette": "", "preview": "", "scale": "6", "max-colors": "16"}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2 and options.has(parts[0]):
			options[parts[0]] = parts[1]
		elif not arg.begins_with("--"):
			path = arg
	var image := _load(path)
	if image == null:
		push_error("[art] não abriu a imagem: %s" % path)
		quit(1)
		return
	_report(image, path, options)
	if not options["preview"].is_empty():
		var preview := _preview(image, maxi(int(options["scale"]), 1))
		preview.save_png(options["preview"])
		print("prévia: %s" % options["preview"])
	quit(0)


func _report(image: Image, path: String, options: Dictionary) -> void:
	var colors := _color_counts(image)
	var partial := 0
	for color: Color in colors:
		if color.a > 0.0 and color.a < 1.0:
			partial += colors[color]
	var orphans := _orphans(image)
	var values := _distinct_values(colors.keys())
	print("== %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	print("cores: %d (limite sugerido %s)%s" % [colors.size(), options["max-colors"],
		"  <-- muitas cores: parece filtro/gradiente, não pixel art" \
			if colors.size() > int(options["max-colors"]) else ""])
	print("tons de valor distintos: %d (2 ou 3 = leitura fraca; ideal 4-6)" % values)
	print("pixels semitransparentes: %d%s" % [partial,
		"  <-- borda borrada (anti-alias); sprites devem ser opacos" if partial > 0 else ""])
	print("pixels soltos (sem vizinho da mesma cor): %d%s" % [orphans.size(),
		"  <-- ruído; agrupe em blocos" if orphans.size() > image.get_width() else ""])
	for i in mini(orphans.size(), 8):
		print("   solto em %s" % orphans[i])
	var sorted: Array = colors.keys()
	sorted.sort_custom(func(a: Color, b: Color) -> bool: return colors[a] > colors[b])
	print("cores mais usadas:")
	for i in mini(sorted.size(), 12):
		print("   #%s  %d px" % [(sorted[i] as Color).to_html(), colors[sorted[i]]])
	if not options["palette"].is_empty():
		var palette := _load(options["palette"])
		var allowed := _color_counts(palette) if palette else {}
		var outside := sorted.filter(func(c: Color) -> bool: return c.a > 0.0 and not allowed.has(c))
		print("fora da paleta: %d cor(es) %s" % [outside.size(),
			outside.map(func(c: Color) -> String: return "#" + c.to_html()) if outside else ""])


## Pixel opaco cuja cor não aparece em nenhum dos 8 vizinhos (contorno de 1 px conta como
## vizinho de si mesmo, então linhas não são "soltas").
func _orphans(image: Image) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a == 0.0:
				continue
			var alone := true
			for offset: Vector2i in NEIGHBORS:
				var n := Vector2i(x, y) + offset
				if bounds.has_point(n) and image.get_pixelv(n) == color:
					alone = false
					break
			if alone:
				result.append(Vector2i(x, y))
	return result


func _color_counts(image: Image) -> Dictionary:
	var counts := {}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0:
				counts[color] = counts.get(color, 0) + 1
	return counts


func _distinct_values(colors: Array) -> int:
	var values: Array[float] = []
	for color: Color in colors:
		var value := color.get_luminance()
		if not values.any(func(v: float) -> bool: return absf(v - value) < VALUE_STEP):
			values.append(value)
	return values.size()


## Original | cinza | silhueta, ampliados lado a lado (fundo magenta).
func _preview(image: Image, scale: int) -> Image:
	var size := image.get_size()
	var gray := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var silhouette := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	silhouette.fill(SILHOUETTE_BACK)
	for y in size.y:
		for x in size.x:
			var color := image.get_pixel(x, y)
			if color.a > 0.0:
				var v := color.get_luminance()
				gray.set_pixel(x, y, Color(v, v, v, color.a))
				silhouette.set_pixel(x, y, SILHOUETTE)
	var panels: Array[Image] = [image, gray, silhouette]
	var cell := size * scale
	var preview := Image.create(panels.size() * (cell.x + 2) + 2, cell.y + 4, false, Image.FORMAT_RGBA8)
	preview.fill(PREVIEW_BACK)
	for i in panels.size():
		var panel := panels[i].duplicate() as Image
		panel.convert(Image.FORMAT_RGBA8)
		panel.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
		preview.blend_rect(panel, Rect2i(Vector2i.ZERO, cell), Vector2i(2 + i * (cell.x + 2), 2))
	return preview


func _load(path: String) -> Image:
	if path.is_empty():
		return null
	# Caminho do sistema: lê o PNG cru (o original, não a versão importada pela Godot).
	if not path.contains(":"):
		path = "res://" + path
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image:
		image.convert(Image.FORMAT_RGBA8)
	return image
