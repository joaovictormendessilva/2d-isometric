extends TestCase
## Receitas de NPC (F3c, ADR-023): receitas `must_learn` só se fabricam depois de aprendidas,
## compradas de um NPC; aprendidas, ficam com o personagem. O host decide (perto do NPC, preço
## dos dados dele) e avisa o dono.

const PORT := 24740
const NPCS_DIR := "res://data/npcs/"


## Toda receita ensinada existe, precisa ser aprendida e tem preço positivo; toda receita que
## precisa ser aprendida é ensinada por alguém (senão ninguém conseguiria fazê-la).
func test_recipe_offers_are_consistent() -> void:
	var recipes := RecipeDatabase.load_all()
	var taught := {}
	for entry in DataCatalog.new(NPCS_DIR).entries():
		var npc := entry as NpcData
		for recipe_id in npc.recipe_offers:
			var recipe := recipes.get_recipe(recipe_id)
			check(recipe != null and recipe.must_learn and npc.recipe_offers[recipe_id] > 0,
				"%s ensina %s: receita que se aprende, preço positivo" % [npc.id, recipe_id])
			taught[recipe_id] = true
	for entry in recipes.entries():
		var recipe := entry as RecipeData
		check(not recipe.must_learn or taught.has(recipe.id),
			"%s se aprende e algum NPC a ensina" % recipe.id)
	check(taught.has(&"health_potion"), "o mercador ensina a poção de vida")


## Sem moedas infinitas: comprar todos os ingredientes de NPCs, fabricar e vender o resultado não
## dá lucro. (Fabricar com o que foi COLETADO pode render mais que vender os materiais: é o
## trabalho do jogador.)
func test_buying_ingredients_to_craft_and_sell_never_profits() -> void:
	var cheapest := {}  # id do item -> menor preço de compra entre os NPCs
	for entry in DataCatalog.new(NPCS_DIR).entries():
		var npc := entry as NpcData
		for item_id in npc.offers:
			cheapest[item_id] = mini(cheapest.get(item_id, npc.offers[item_id]), npc.offers[item_id])
	for entry in RecipeDatabase.load_all().entries():
		var recipe := entry as RecipeData
		if not recipe.ingredients.keys().all(func(id: StringName) -> bool: return cheapest.has(id)):
			continue  # algum ingrediente só se coleta
		var cost := 0
		for item_id in recipe.ingredients:
			cost += cheapest[item_id] * recipe.ingredients[item_id]
		var value := TradeRules.sell_price(recipe.result) * recipe.result_amount
		check(value < cost, "%s: vende por %d, ingredientes custam %d" % [recipe.id, value, cost])


func test_learning_spends_coins_and_unlocks_crafting() -> void:
	var npc := DataCatalog.new(NPCS_DIR).get_entry(&"merchant") as NpcData
	var recipes := RecipeDatabase.load_all()
	var potion := recipes.get_recipe(&"health_potion")
	var inventory := Inventory.new(4, ItemDatabase.load_all())
	var wallet := Wallet.new()
	var book := RecipeBook.new()
	var stations: Array[RecipeData.Station] = [RecipeData.Station.HAND,
		RecipeData.Station.WORKBENCH]
	inventory.add(&"gel", 10)
	check(CraftingRules.check(potion, inventory, stations, book)
			== CraftingRules.Check.NOT_LEARNED, "sem aprender, não fabrica")
	check(not CraftingRules.craft(potion, inventory, stations, book) and inventory.count(&"gel") == 10,
		"nada muda")
	var price := npc.recipe_price(&"health_potion")
	check(TradeRules.check_learn(npc, potion, book, wallet) == TradeRules.Check.NOT_ENOUGH_COINS,
		"sem moedas")
	check(not TradeRules.learn(npc, potion, book, wallet) and not book.knows(potion), "não aprendeu")

	var learned := []
	book.learned.connect(func(id: StringName, is_new: bool) -> void: learned.append([id, is_new]))
	wallet.add(price + 5)
	check(TradeRules.learn(npc, potion, book, wallet), "aprendeu")
	check(book.knows(potion) and wallet.coins() == 5 and learned == [[&"health_potion", true]],
		"receita no livro, moedas gastas, aviso de nova")
	check(TradeRules.check_learn(npc, potion, book, wallet) == TradeRules.Check.ALREADY_KNOWN,
		"já sabe")
	wallet.add(100)
	check(not TradeRules.learn(npc, potion, book, wallet) and wallet.coins() == 105,
		"aprender de novo não cobra")
	check(CraftingRules.craft(potion, inventory, stations, book), "agora fabrica")
	check(inventory.count(&"health_potion") == 1
		and inventory.count(&"gel") == 10 - potion.ingredients[&"gel"], "poção feita com gosma")


func test_only_taught_recipes_can_be_learned() -> void:
	var npc := DataCatalog.new(NPCS_DIR).get_entry(&"merchant") as NpcData
	var recipes := RecipeDatabase.load_all()
	var book := RecipeBook.new()
	var wallet := Wallet.new()
	wallet.add(1000)
	var axe := recipes.get_recipe(&"stone_axe")
	check(book.knows(axe), "receita comum já se sabe")
	check(TradeRules.check_learn(npc, axe, book, wallet) == TradeRules.Check.NOT_TAUGHT,
		"receita comum não se compra")
	check(TradeRules.check_learn(npc, null, book, wallet) == TradeRules.Check.NOT_TAUGHT,
		"receita inexistente não se compra")
	var teaches_nothing := NpcData.new()
	check(TradeRules.check_learn(teaches_nothing, recipes.get_recipe(&"health_potion"), book,
		wallet) == TradeRules.Check.NOT_TAUGHT, "NPC que não ensina não ensina")
	check(wallet.coins() == 1000 and book.all_learned().is_empty(), "nada mudou")


## Coop: o cliente aprende pedindo ao host, que confere distância, receita e moedas; o livro do
## cliente recebe a receita (com o aviso) e ele passa a fabricá-la pelo host.
func test_client_learns_through_host() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(connected, "cliente conectou")
	calm_monsters(host)
	await physics_frames(10)
	var client_id: int = client.local_player_id()
	var host_session := host.session as GameSession
	var client_session := client.session as GameSession
	var host_book := host_session.get_recipe_book(client_id)
	var client_book := client_session.get_recipe_book(client_id)
	var host_wallet := host_session.get_wallet(client_id)
	var potion := (host.recipes as RecipeDatabase).get_recipe(&"health_potion")
	var learned := []
	client_book.learned.connect(func(id: StringName, is_new: bool) -> void:
		learned.append([id, is_new]))
	host_wallet.add(100)
	var state: PlayerStateSync = client.player_state
	state.request_learn(&"health_potion")  # longe do mercador
	await physics_frames(10)
	check(not host_book.knows(potion) and host_wallet.coins() == 100, "longe, o host recusa")

	var merchant := merchant_node(client)
	var character := client_session.get_player_entity(client_id) as Character
	await glide_to(character, merchant.position + Iso.ground_to_screen(Vector2(-20, 0)))
	await physics_frames(10)  # a posição chega ao host
	state.request_learn(&"stone_axe")
	state.request_learn(&"../../data/recipes/health_potion")
	await physics_frames(10)
	check(host_book.all_learned().is_empty() and host_wallet.coins() == 100,
		"pedidos inválidos não mudam nada")

	state.request_learn(&"health_potion")
	check(await wait_until(func() -> bool: return client_book.knows(potion), 30),
		"o cliente recebeu a receita")
	check(host_book.knows(potion)
		and host_wallet.coins() == 100 - merchant.data.recipe_price(&"health_potion"),
		"o host cobrou o preço dos dados dele")
	check(learned == [[&"health_potion", true]], "o cliente recebeu o aviso de receita nova")
	var on_host := host_session.get_inventory(client_id)
	on_host.add(&"gel", 3)
	state.request_craft(&"health_potion")
	check(await wait_until(func() -> bool:
		return client_session.get_inventory(client_id).count(&"health_potion") == 1, 30),
		"fabricou a poção pelo host")


## Loja na tela: a seção "Receitas" mostra a poção com o preço; clicar aprende; depois fica
## apagada como "Já aprendida". Na lista de fabricação, a poção fica apagada até aprender.
func test_shop_window_teaches_and_crafting_list_follows() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var player_id: int = game.local_player_id()
	var character := session.get_player_entity(player_id) as Character
	var shop: ShopPanel = game.get_node("UI/ShopPanel")
	var panel: InventoryPanel = game.get_node("UI/InventoryPanel")
	var merchant := merchant_node(game)
	character.position = merchant.position + Iso.ground_to_screen(Vector2(-20, 0))
	character.reset_physics_interpolation()
	shop.talk_to(merchant)
	var rows: Array[RecipeOfferRow] = []
	rows.assign(shop.find_children("*", "RecipeOfferRow", true, false))
	check(rows.size() == merchant.data.recipe_offers.size(), "uma linha por receita ensinada")
	var crafting: Array[RecipeRow] = []
	crafting.assign(panel.find_children("*", "RecipeRow", true, false))
	var potion_row: RecipeRow = crafting.filter(func(row: RecipeRow) -> bool:
		return row.recipe.id == &"health_potion")[0]
	check(not potion_row._available, "na lista de fabricação, a poção está apagada")
	check(potion_row.tooltip_text.contains(Texts.get_text(&"CRAFT_NOT_LEARNED")),
		"a dica diz que é preciso aprender")
	var row := rows[0]
	check(not row._available, "sem moedas: apagada")
	session.get_wallet(player_id).add(100)
	await physics_frames(1)
	check(row._available, "com moedas: acesa")
	row._gui_input(left_click())
	await physics_frames(1)
	check(session.get_recipe_book(player_id).knows(row.recipe), "clicar aprendeu")
	check(not row._available and row._known.visible and not row._price.visible,
		"aprendida: apagada, \"Já aprendida\" no lugar do preço")
	check(not potion_row.tooltip_text.contains(Texts.get_text(&"CRAFT_NOT_LEARNED")),
		"a lista de fabricação deixou de pedir para aprender")
