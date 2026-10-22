extends Node2D
## Cena principal mínima da Etapa B: confirma que o projeto abre, que a resolução interna
## é 640x360 e que a escala inteira/filtro nearest estão ativos. Será substituída pelo
## protótipo isométrico da Etapa C.

const TILE_SIZE := Vector2(32, 16)  # ADR-007: tile isométrico 2:1
const GRID_RADIUS := 3
const COLOR_A := Color(0.24, 0.42, 0.30)
const COLOR_B := Color(0.20, 0.36, 0.26)


func _ready() -> void:
	var size := get_viewport_rect().size
	print("[main] ready: viewport %dx%d, renderer %s" % [
		size.x, size.y, RenderingServer.get_current_rendering_method()])
	queue_redraw()


func _draw() -> void:
	# Pequeno losango de tiles 32x16 no centro da tela, só para conferir a nitidez do pixel.
	var origin := get_viewport_rect().size / 2.0
	var half := TILE_SIZE / 2.0
	for gx in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for gy in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var center := origin + Vector2((gx - gy) * half.x, (gx + gy) * half.y)
			var points := PackedVector2Array([
				center + Vector2(0, -half.y),
				center + Vector2(half.x, 0),
				center + Vector2(0, half.y),
				center + Vector2(-half.x, 0),
			])
			draw_colored_polygon(points, COLOR_A if (gx + gy) % 2 == 0 else COLOR_B)
