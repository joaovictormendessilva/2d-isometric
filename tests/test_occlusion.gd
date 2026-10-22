extends TestCase
## Objetos altos ficam semitransparentes quando o personagem local está atrás deles.

const TREE_SCENE := preload("res://scenes/props/tree.tscn")
const ROCK_SCENE := preload("res://scenes/props/rock.tscn")


func test_tree_fades_only_when_viewer_is_behind() -> void:
	var tree_prop: Node2D = add_to_tree(TREE_SCENE.instantiate())
	var sprite: Sprite2D = tree_prop.get_node("Sprite")
	var viewer := spawn_character(Vector2(0, -12))
	viewer.add_to_group(OccluderFade.VIEWER_GROUP)
	await physics_frames(20)
	check(sprite.modulate.a < 0.6, "árvore transparente com o personagem atrás (a=%.2f)" % sprite.modulate.a)

	viewer.position = Vector2(0, 10)  # na frente da base: a árvore volta ao normal
	await physics_frames(20)
	check(is_equal_approx(sprite.modulate.a, 1.0), "árvore opaca com o personagem na frente")


func test_other_characters_do_not_fade_trees() -> void:
	var tree_prop: Node2D = add_to_tree(TREE_SCENE.instantiate())
	spawn_character(Vector2(0, -12))  # sem o grupo de observador (ex.: outro jogador/monstro)
	await physics_frames(20)
	check(is_equal_approx((tree_prop.get_node("Sprite") as Sprite2D).modulate.a, 1.0),
		"só o personagem local deixa objetos transparentes")


func test_low_props_never_fade() -> void:
	var rock: Node2D = add_to_tree(ROCK_SCENE.instantiate())
	await physics_frames(1)
	check(not rock.has_node("Occluder"), "pedra é baixa demais para esconder alguém")
