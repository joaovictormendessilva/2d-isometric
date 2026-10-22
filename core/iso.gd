class_name Iso
## Conversões entre coordenadas de TELA e o "plano do chão" (ADR-006).
##
## A tela mostra o chão achatado pela metade na vertical (tile 32x16, proporção 2:1).
## No plano do chão, Y vale o dobro do Y de tela, então distâncias, velocidades, alcances e
## áreas calculadas aqui são iguais em todas as direções. Use estas funções sempre que um
## número de gameplay depender de distância ou direção — nunca a distância de tela direta.

const Y_SCALE := 2.0
## Tamanho do tile isométrico em pixels de tela (ADR-007).
const TILE_SIZE := Vector2i(32, 16)


static func screen_to_ground(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * Y_SCALE)


static func ground_to_screen(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y / Y_SCALE)


## Distância "justa" entre dois pontos de tela, medida no plano do chão.
static func ground_distance(a: Vector2, b: Vector2) -> float:
	return screen_to_ground(b - a).length()
