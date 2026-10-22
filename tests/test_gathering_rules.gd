extends TestCase
## Regras de coleta (sem cena): níveis, ferramentas, requisitos, tempo e rendimento.

const WOODCUTTING := preload("res://data/skills/woodcutting.tres")
const LUMBER_TREE := preload("res://data/resource_nodes/lumber_tree.tres")
const OLD_OAK := preload("res://data/resource_nodes/old_oak.tres")
const COPPER_VEIN := preload("res://data/resource_nodes/copper_vein.tres")
const STONE_AXE := preload("res://data/items/stone_axe.tres")
const COPPER_AXE := preload("res://data/items/copper_axe.tres")
const STONE_PICKAXE := preload("res://data/items/stone_pickaxe.tres")
const BALANCE := preload("res://data/balance/gathering.tres")
const ROLLS := 2000


func test_levels_follow_the_xp_curve() -> void:
	check(WOODCUTTING.level_for_xp(0) == 1, "começa no nível 1")
	var to_two := WOODCUTTING.xp_to_next(1)
	check(WOODCUTTING.level_for_xp(to_two - 1) == 1 and WOODCUTTING.level_for_xp(to_two) == 2,
		"nível 2 com exatamente %d de experiência" % to_two)
	check(WOODCUTTING.xp_to_next(10) > WOODCUTTING.xp_to_next(2), "níveis altos pedem mais")
	for level in range(1, 20):
		check(WOODCUTTING.level_for_xp(WOODCUTTING.xp_for_level(level)) == level,
			"xp_for_level e level_for_xp concordam no nível %d" % level)
	check(WOODCUTTING.level_for_xp(10_000_000) == WOODCUTTING.max_level, "para no nível máximo")


func test_hands_gather_only_basic_nodes() -> void:
	check(GatheringRules.check(LUMBER_TREE, 1, null) == GatheringRules.Check.OK, "mãos coletam lenha")
	check(GatheringRules.check(COPPER_VEIN, 1, null) == GatheringRules.Check.OK, "mãos coletam cobre")
	check(GatheringRules.check(OLD_OAK, 10, null) == GatheringRules.Check.NEEDS_TOOL,
		"carvalho antigo exige ferramenta")
	check(GatheringRules.check(OLD_OAK, 10, STONE_AXE) == GatheringRules.Check.NEEDS_TOOL,
		"machado de pedra é fraco para o carvalho")
	check(GatheringRules.check(OLD_OAK, 1, COPPER_AXE) == GatheringRules.Check.NEEDS_LEVEL,
		"com o machado certo, ainda exige nível")
	check(GatheringRules.check(OLD_OAK, OLD_OAK.min_skill_level, COPPER_AXE) == GatheringRules.Check.OK,
		"ferramenta e nível certos: coleta")


func test_best_tool_matches_the_node_type() -> void:
	var tools: Array[ToolData] = [STONE_AXE, COPPER_AXE, STONE_PICKAXE]
	check(GatheringRules.best_tool(LUMBER_TREE, tools) == COPPER_AXE, "melhor machado para madeira")
	check(GatheringRules.best_tool(COPPER_VEIN, tools) == STONE_PICKAXE, "picareta para minério")
	var axes_only: Array[ToolData] = [STONE_AXE]
	check(GatheringRules.best_tool(COPPER_VEIN, axes_only) == null, "machado não serve para minério")


func test_tools_and_levels_make_gathering_faster() -> void:
	var hands := GatheringRules.gather_duration(LUMBER_TREE, 1, null, BALANCE)
	var axe := GatheringRules.gather_duration(LUMBER_TREE, 1, STONE_AXE, BALANCE)
	var skilled := GatheringRules.gather_duration(LUMBER_TREE, 10, STONE_AXE, BALANCE)
	check_near(hands, LUMBER_TREE.gather_time / BALANCE.hands_speed, 0.001, "mãos: tempo base dividido pela velocidade")
	check(axe < hands, "machado é mais rápido que as mãos (%.2f s < %.2f s)" % [axe, hands])
	check(skilled < axe, "nível maior é mais rápido (%.2f s < %.2f s)" % [skilled, axe])


func test_yield_uses_chances_and_level_bonus() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var stone_hits := 0
	var ore_low := 0
	var ore_high := 0
	for i in ROLLS:
		var low := GatheringRules.roll_yield(COPPER_VEIN, 1, rng)
		check(low.get(&"copper_ore", 0) >= 1, "minério sai sempre (chance 100%)")
		ore_low += low.get(&"copper_ore", 0)
		stone_hits += 1 if low.has(&"stone") else 0
		ore_high += GatheringRules.roll_yield(COPPER_VEIN, 30, rng).get(&"copper_ore", 0)
	check_near(float(stone_hits) / ROLLS, 0.5, 0.05, "pedra sai ~50% das vezes")
	check(ore_low == ROLLS, "nível 1: sem bônus de rendimento")
	check(ore_high > ROLLS * 1.4, "nível 30 rende mais (%d contra %d)" % [ore_high, ore_low])
