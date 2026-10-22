extends TestCase
## Estruturas colocadas pelo jogador (bancada): colocar, recusas do host e receitas de
## bancada liberadas só por perto (ADR-017).


func test_placed_workbench_unlocks_its_recipes_nearby() -> void:
	var game := start_game()
	calm_monsters(game)
	var player_id: int = game.local_player_id()
	var state: PlayerStateSync = game.player_state
	var inventory := (game.session as GameSession).get_inventory(player_id)
	var character := (game.session as GameSession).get_player_entity(player_id) as Character
	var bench: PlaceableData = (game.items as ItemDatabase).get_item(&"workbench")
	inventory.add(&"workbench", 1)
	inventory.add(&"copper_ore", 10)
	inventory.add(&"wood", 10)
	var copper_axe := state.recipes.get_recipe(&"copper_axe")
	check(not CraftingRules.craft(copper_axe, inventory, state.stations_of(player_id)),
		"sem bancada: machado de cobre não sai")

	inventory.click_slot(0)  # pega a bancada
	var preview: PlacementPreview = game.get_node("World/PlacementPreview")
	check(preview.is_active() and preview.visible, "bancada na mão: prévia no chão")
	state.request_place(character.position)  # em cima do próprio jogador
	state.request_place(character.position + Vector2(400, 0))  # longe demais
	check(structures(game).is_empty() and inventory.held_item() == &"workbench",
		"lugar ocupado ou longe: nada colocado, a bancada continua na mão")

	state.request_place(free_spot_near(character, bench.structure))
	await physics_frames(2)
	check(structures(game).size() == 1 and not inventory.is_holding(), "bancada colocada e gasta")
	check(not preview.visible, "mão vazia: sem prévia")
	check(RecipeData.Station.WORKBENCH in state.stations_of(player_id), "perto da bancada")
	check(CraftingRules.craft(copper_axe, inventory, state.stations_of(player_id)),
		"perto da bancada: machado de cobre feito")

	character.position += Vector2(300, 0)
	check(RecipeData.Station.WORKBENCH not in state.stations_of(player_id), "longe: só a mão")
