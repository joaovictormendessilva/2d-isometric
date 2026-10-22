extends TestCase
## Movimento do personagem: velocidade justa em todas as direções, colisão e input local.

const ROCK_SCENE := preload("res://scenes/props/rock.tscn")
const DIRECTIONS: Array[Vector2] = [
	Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
	Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]


func test_speed_per_direction_matches_stats() -> void:
	var characters := await _walk_one_second_in_every_direction()
	var stats := characters[0].stats
	for i in characters.size():
		var speed := stats.move_speed * Iso.move_speed_factor(DIRECTIONS[i], stats.horizontal_speed_factor)
		# 1 s de movimento menos o trecho de aceleração (v² / 2a).
		var expected := speed - speed ** 2 / (2.0 * stats.acceleration)
		var moved := Iso.ground_distance(Vector2.ZERO, characters[i].position)
		check_near(moved, expected, 2.0, "distância no chão na direção %s" % DIRECTIONS[i])


## Percepção (pedido do João): andar na horizontal não deve parecer mais rápido que na
## diagonal — comparamos a distância percorrida NA TELA.
func test_horizontal_screen_speed_close_to_diagonal() -> void:
	var characters := await _walk_one_second_in_every_direction()
	var horizontal := characters[DIRECTIONS.find(Vector2.RIGHT)].position.length()
	var diagonal := characters[DIRECTIONS.find(Vector2(1, 1))].position.length()
	check_near(horizontal / diagonal, 1.0, 0.1, "razão horizontal/diagonal na tela")


func _walk_one_second_in_every_direction() -> Array[Character]:
	var characters: Array[Character] = []
	for dir in DIRECTIONS:
		var c := spawn_character(Vector2.ZERO)
		c.set_move_intent(dir.normalized())
		characters.append(c)
	await physics_frames(60)
	return characters


## Pegadas redondas: ao empurrar contra a pedra o personagem desliza em volta dela (não
## trava), mas as pegadas nunca se sobrepõem.
func test_rock_footprints_never_overlap() -> void:
	var rock: Node2D = add_to_tree(ROCK_SCENE.instantiate())
	rock.position = Vector2(60, 0)
	var c := spawn_character(Vector2.ZERO)
	c.set_move_intent(Vector2.RIGHT)
	var min_gap := INF
	var touched := false
	for i in 90:
		await physics_frames(1)
		min_gap = minf(min_gap, Iso.ground_distance(c.position, rock.position))
		touched = touched or c.get_slide_collision_count() > 0
	var radii: float = rock.get_node("Footprint").radius + c.get_node("Footprint").radius
	check(touched, "personagem encostou na pedra")
	# Polígonos de 12 lados ficam um pouco dentro do círculo ideal (cos 15° ≈ 0,966).
	check(min_gap >= radii * 0.95, "pegadas não se sobrepõem (mín. %.2f, raios %.2f)" % [min_gap, radii])
	check(c.position.x > rock.position.x, "personagem contornou a pedra em vez de travar")


func test_local_input_moves_local_player() -> void:
	var game := add_to_tree(TestCase.MAIN_SCENE.instantiate())
	var session: GameSession = game.session
	var player := session.get_player_entity(game.local_player_id()) as Character
	check(session.get_player_count() == 1, "sessão com 1 jogador")
	check(player != null, "jogador local tem personagem")
	var start := player.position
	Input.action_press(&"move_right")
	await physics_frames(30)
	Input.action_release(&"move_right")
	check(player.position.x - start.x > 10.0, "seta para a direita move para a direita")
	check_near(player.position.y, start.y, 0.5, "sem deslocamento vertical")
