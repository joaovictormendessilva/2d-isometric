extends TestCase
## Conversões entre tela e plano do chão (ADR-006).


func test_round_trip() -> void:
	var v := Vector2(13.5, -7.25)
	check(Iso.ground_to_screen(Iso.screen_to_ground(v)).is_equal_approx(v), "ida e volta tela/chão")


func test_vertical_screen_distance_counts_double() -> void:
	# 10 px na vertical da tela = 20 px no chão; 20 px na horizontal = 20 px no chão.
	check_near(Iso.ground_distance(Vector2.ZERO, Vector2(0, 10)), 20.0, 0.001, "distância vertical")
	check_near(Iso.ground_distance(Vector2.ZERO, Vector2(20, 0)), 20.0, 0.001, "distância horizontal")


func test_ground_diagonal_follows_tile_edge() -> void:
	# A diagonal do chão deve andar na inclinação 2:1 das bordas do tile.
	var screen := Iso.ground_to_screen(Vector2(1, 1))
	var tile := Vector2(Iso.TILE_SIZE)
	check_near(screen.y / screen.x, tile.y / tile.x, 0.001, "inclinação da diagonal")
