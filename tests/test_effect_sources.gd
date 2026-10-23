extends TestCase
## Fontes de efeito (G1c): o slime venenoso (floresta) envenena quem o bote acerta; a poção de
## rapidez, vendida pelo mercador, acelera quem bebe. O host decide os dois.

const POISON_SLIME_SCENE := preload("res://scenes/actors/monsters/poison_slime.tscn")
const FOREST_PATH := "res://scenes/regions/forest/forest.tscn"
const MEADOW_PATH := "res://scenes/regions/meadow/meadow.tscn"
const POTION := &"swiftness_potion"


func test_poison_slimes_live_in_the_forest_only() -> void:
	var data := (POISON_SLIME_SCENE.instantiate() as Monster)
	check(data.data.on_hit_effects.any(func(effect: StatusEffectData) -> bool:
		return effect.id == &"poison"), "o golpe do slime venenoso envenena")
	check(data.data.stats == load("res://data/monsters/slime.tres").stats,
		"mesmos atributos do slime comum (um arquivo só)")
	data.free()
	for path: String in [FOREST_PATH, MEADOW_PATH]:
		var region: Region = add_to_tree(load(path).instantiate())
		var poisonous := region.get_monster_spawn_points().filter(func(point: MonsterSpawnPoint) -> bool:
			return point.monster_scene == POISON_SLIME_SCENE).size()
		if path == FOREST_PATH:
			check(poisonous >= 3, "a floresta tem slimes venenosos (%d)" % poisonous)
		else:
			check(poisonous == 0, "a campina não tem")
		region.free()
	await physics_frames(1)


## O bote que acerta envenena; o que erra (quem fugiu) não.
func test_poison_slime_lunge_poisons_who_it_hits() -> void:
	for runs: bool in [false, true]:
		var slime: Monster = add_to_tree(POISON_SLIME_SCENE.instantiate())
		var attack := slime.data.attack
		var player := spawn_character(Vector2.ZERO)
		player.position = Vector2(slime.footprint_radius() + player.footprint_radius()
			+ attack.engage_distance, 0)
		player.reset_physics_interpolation()
		check(slime.request_attack(Vector2.RIGHT), "começou o bote")
		if runs:
			player.position.x += 60.0
		await physics_frames(roundi((attack.windup + attack.lunge_hit_time) * 60.0) + 4)
		var poisoned := player.status_effects.effects.has(&"poison")
		check(poisoned != runs, "quem fugiu não é envenenado" if runs else "quem levou o bote está envenenado")
		slime.free()
		player.free()


func test_swiftness_potion_is_sold_and_described() -> void:
	var items := ItemDatabase.load_all()
	var potion := items.get_item(POTION) as ConsumableData
	check(potion != null and potion.effects.size() == 1 and potion.heal == 0, "poção só com efeito")
	check(potion.cooldown_group != (items.get_item(&"health_potion") as ConsumableData).cooldown_group,
		"não divide a espera com a poção de vida")
	var merchant := DataCatalog.new("res://data/npcs/").get_entry(&"merchant") as NpcData
	check(merchant.sells(POTION), "o mercador vende")
	var text := ItemTexts.describe(potion)
	check(text.contains(potion.effects[0].get_display_name()) and text.contains("25"),
		"a dica diz o efeito e o bônus (%s)" % text.replace("\n", " | "))


## Beber com vida cheia vale (não é cura); acelera; a tecla de poção (cura) não a escolhe.
func test_drinking_swiftness_potion_speeds_up() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var inventory := session.get_inventory(1)
	var player := session.get_player_entity(1) as Character
	var state: PlayerStateSync = game.player_state
	inventory.add(POTION, 2)
	var base := player.move_speed()
	var refusals := []
	state.use_refused.connect(refusals.append)
	state.request_quick_heal()
	check(refusals == [ConsumableRules.Check.NO_POTION], "a tecla de cura ignora a rapidez")
	state.request_use(slot_of(inventory, POTION))
	check(inventory.count(POTION) == 1, "bebeu uma, com a vida cheia")
	check(session.get_effects(1).has(&"swiftness"), "está com rapidez")
	check_near(player.move_speed(), base * 1.25, 0.01, "25% mais rápido")
	state.request_use(slot_of(inventory, POTION))
	check(refusals.back() == ConsumableRules.Check.COOLING_DOWN and inventory.count(POTION) == 1,
		"espera entre poções de rapidez")
