extends TestCase
## Moedas e mercador (F3): carteira separada do inventário, compra e venda tudo-ou-nada, preços
## em dados e o host decidindo (só perto de um NPC).

const PORT := 24720
const NPCS_DIR := "res://data/npcs/"


## Preços coerentes: cada oferta é um item conhecido com preço positivo, e nada se compra por
## menos do que se vende (senão comprar e vender de novo daria moedas infinitas).
func test_npc_data_is_consistent() -> void:
	var items := ItemDatabase.load_all()
	var npcs := DataCatalog.new(NPCS_DIR)
	check(npcs.has(&"merchant"), "há o mercador em data/npcs/")
	for entry in npcs.entries():
		var npc := entry as NpcData
		for item_id in npc.offers:
			var item := items.get_item(item_id)
			check(item != null and npc.offers[item_id] > 0,
				"%s vende %s, item conhecido, preço positivo" % [npc.id, item_id])
			check(item == null or TradeRules.sell_price(item) < npc.offers[item_id],
				"%s: %s não volta mais moedas do que custa" % [npc.id, item_id])


func test_buy_spends_coins_and_gives_one_item() -> void:
	var npc := _merchant()
	var inventory := Inventory.new(4, ItemDatabase.load_all())
	var wallet := Wallet.new()
	var price := npc.price_of(&"stone_axe")
	check(TradeRules.check_buy(npc, &"stone_axe", inventory, wallet)
		== TradeRules.Check.NOT_ENOUGH_COINS, "sem moedas")
	wallet.add(price + 3)
	check(TradeRules.buy(npc, &"stone_axe", inventory, wallet), "comprou")
	check(inventory.count(&"stone_axe") == 1 and wallet.coins() == 3, "machado entrou, moedas saíram")
	check(not TradeRules.buy(npc, &"stone_axe", inventory, wallet), "sem moedas para o segundo")
	check(TradeRules.check_buy(npc, &"gel", inventory, wallet) == TradeRules.Check.NOT_SOLD,
		"o mercador não vende gosma")


func test_buy_with_full_inventory_changes_nothing() -> void:
	var npc := _merchant()
	var inventory := Inventory.new(1, ItemDatabase.load_all())
	var wallet := Wallet.new()
	wallet.add(1000)
	inventory.add(&"wood", 5)
	check(TradeRules.check_buy(npc, &"stone_axe", inventory, wallet)
		== TradeRules.Check.INVENTORY_FULL, "sem espaço")
	check(not TradeRules.buy(npc, &"stone_axe", inventory, wallet), "não comprou")
	check(wallet.coins() == 1000 and inventory.count(&"stone_axe") == 0, "nada mudou")


func test_sell_takes_from_the_slot_and_pays_the_item_price() -> void:
	var items := ItemDatabase.load_all()
	var npc := _merchant()
	var inventory := Inventory.new(4, items)
	var wallet := Wallet.new()
	inventory.add(&"gel", 10)
	var price := TradeRules.sell_price(items.get_item(&"gel"))
	check(price > 0, "gosma tem preço de venda")
	check(TradeRules.sell(npc, inventory, 0, 4, wallet, items), "vendeu 4")
	check(inventory.count(&"gel") == 6 and wallet.coins() == 4 * price, "tirou 4, pagou 4")
	check(TradeRules.sell(npc, inventory, 0, 6, wallet, items), "vendeu o resto")
	check(inventory.slot_item(0) == Inventory.EMPTY, "espaço esvaziou")
	for bad: Array in [[0, 1], [1, 1], [-1, 1], [99, 1]]:
		check(not TradeRules.sell(npc, inventory, bad[0], bad[1], wallet, items),
			"espaço vazio ou inválido (%s) não vende" % [bad])
	inventory.add(&"gel", 3)
	for amount in [0, -2, 4]:
		check(not TradeRules.sell(npc, inventory, 0, amount, wallet, items),
			"quantidade %d não vende" % amount)
	check(inventory.count(&"gel") == 3 and wallet.coins() == 10 * price, "nada mudou")


## Item sem preço de venda não é comprado; carteira no teto não recebe (nada se perde).
func test_sell_refusals_change_nothing() -> void:
	var items := ItemDatabase.load_all()
	var npc := _merchant()
	var inventory := Inventory.new(4, items)
	var wallet := Wallet.new()
	inventory.set_slot(0, &"item_sem_preco", 1)
	check(TradeRules.check_sell(npc, inventory, 0, 1, wallet, items) == TradeRules.Check.NOT_BOUGHT,
		"item sem preço não é comprado")
	inventory.set_slot(1, &"gel", 5)
	wallet.add(Wallet.MAX_COINS)
	check(TradeRules.check_sell(npc, inventory, 1, 1, wallet, items) == TradeRules.Check.WALLET_FULL,
		"carteira cheia")
	check(inventory.count(&"gel") == 5 and wallet.coins() == Wallet.MAX_COINS, "nada mudou")


func test_wallet_is_all_or_nothing() -> void:
	var wallet := Wallet.new()
	var earned := []
	wallet.earned.connect(earned.append)
	check(not wallet.add(0) and not wallet.add(-5) and not wallet.spend(1), "valores ruins recusados")
	check(wallet.add(10) and wallet.spend(4) and wallet.coins() == 6, "ganha e gasta")
	check(not wallet.add(Wallet.MAX_COINS), "passar do teto não guarda nada")
	check(wallet.coins() == 6 and earned == [10], "só o ganho real avisa")
	wallet.replicate(-3)
	check(wallet.coins() == 0, "valor replicado negativo vira zero")


## O mercador fica na campina, perto da entrada, mas fora de alcance de quem acabou de chegar:
## longe não negocia; perto, compra e vende (offline = host).
func test_merchant_in_the_meadow_trades_only_up_close() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var player_id: int = game.local_player_id()
	var state: PlayerStateSync = game.player_state
	var character := session.get_player_entity(player_id) as Character
	var merchant := _merchant_node(game)
	check(merchant != null and merchant.data.id == &"merchant", "há um mercador na campina")
	if merchant == null:
		return
	var inventory := session.get_inventory(player_id)
	var wallet := session.get_wallet(player_id)
	wallet.add(100)
	check(state.npc_near(player_id) == null, "na entrada, o mercador está fora de alcance")
	state.request_buy(&"stone_axe")
	check(wallet.coins() == 100 and inventory.count(&"stone_axe") == 0, "longe não compra")

	character.position = merchant.position + Iso.ground_to_screen(Vector2(-20, 0))
	character.reset_physics_interpolation()
	check(state.npc_near(player_id) == merchant, "perto, o mercador negocia")
	state.request_buy(&"stone_axe")
	check(inventory.count(&"stone_axe") == 1
		and wallet.coins() == 100 - merchant.data.price_of(&"stone_axe"), "perto compra")
	var index := _slot_of(inventory, &"stone_axe")
	state.request_sell(index, 1)
	check(inventory.count(&"stone_axe") == 0, "e vende")


## Coop: o cliente compra e vende pedindo ao host, que confere distância, preço e índices; as
## moedas oficiais (e o aviso do ganho) chegam ao cliente.
func test_client_trades_through_host() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(connected, "cliente conectou")
	calm_monsters(host)
	await physics_frames(10)
	var client_id: int = client.local_player_id()
	var on_host := (host.session as GameSession).get_inventory(client_id)
	var on_client := (client.session as GameSession).get_inventory(client_id)
	var host_wallet := (host.session as GameSession).get_wallet(client_id)
	var client_wallet := (client.session as GameSession).get_wallet(client_id)
	var earned := []
	client_wallet.earned.connect(earned.append)
	host_wallet.add(50)
	on_host.add(&"gel", 5)
	var state: PlayerStateSync = client.player_state
	check(await wait_until(func() -> bool: return client_wallet.coins() == 50, 30),
		"moedas do host chegam ao cliente")
	earned.clear()  # os 50 também foram um ganho; daqui em diante, só a venda

	state.request_sell(0, 5)  # longe do mercador
	await physics_frames(10)
	check(on_host.count(&"gel") == 5 and host_wallet.coins() == 50, "longe, o host recusa")

	var merchant := _merchant_node(client)
	var character := (client.session as GameSession).get_player_entity(client_id) as Character
	await glide_to(character, merchant.position + Iso.ground_to_screen(Vector2(-20, 0)))
	await physics_frames(10)  # a posição chega ao host
	state.request_sell(0, 99)
	state.request_sell(-1, 1)
	state.request_buy(&"gel")  # o mercador não vende gosma
	state.request_buy(&"../../data/items/wood")
	await physics_frames(10)
	check(on_host.count(&"gel") == 5 and host_wallet.coins() == 50, "pedidos inválidos não mudam nada")

	var gel_price := TradeRules.sell_price((host.items as ItemDatabase).get_item(&"gel"))
	state.request_sell(0, 2)
	var sold := await wait_until(func() -> bool: return on_client.count(&"gel") == 3, 30)
	check(sold and client_wallet.coins() == 50 + 2 * gel_price, "vendeu 2 pelo host")
	check(earned == [2 * gel_price], "o cliente recebeu o aviso do ganho")
	var axe_price := merchant.data.price_of(&"stone_axe")
	state.request_buy(&"stone_axe")
	var bought := await wait_until(func() -> bool: return on_client.count(&"stone_axe") == 1, 30)
	check(bought and client_wallet.coins() == 50 + 2 * gel_price - axe_price, "comprou pelo host")
	check(host_wallet.coins() == client_wallet.coins(), "carteira igual nos dois lados")


## Loja na tela: abre perto do mercador junto com o inventário; oferta sem moedas fica apagada;
## clicar compra; o menu do botão direito oferece vender; longe, a loja e o inventário fecham.
func test_shop_window_buys_sells_and_closes_when_far() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var player_id: int = game.local_player_id()
	var character := session.get_player_entity(player_id) as Character
	var inventory := session.get_inventory(player_id)
	var wallet := session.get_wallet(player_id)
	var shop: ShopPanel = game.get_node("UI/ShopPanel")
	var panel: InventoryPanel = game.get_node("UI/InventoryPanel")
	var merchant := _merchant_node(game)
	character.position = merchant.position + Iso.ground_to_screen(Vector2(-20, 0))
	character.reset_physics_interpolation()
	shop.talk_to(merchant)
	check(shop.visible and panel.visible, "a loja abre com o inventário")
	var rows: Array[OfferRow] = []
	rows.assign(shop.find_children("*", "OfferRow", true, false))
	check(rows.size() == merchant.data.offers.size(), "uma linha por oferta")
	var axe: OfferRow = rows.filter(func(row: OfferRow) -> bool: return row.item.id == &"stone_axe")[0]
	check(not axe._available, "sem moedas: apagada")
	axe._gui_input(left_click())
	check(inventory.count(&"stone_axe") == 0, "clicar apagada não compra")

	wallet.add(100)
	inventory.add(&"gel", 4)
	await physics_frames(1)
	check(axe._available, "com moedas: acesa")
	axe._gui_input(left_click())
	check(inventory.count(&"stone_axe") == 1, "clicar comprou")
	var gel_price := shop.sell_price_of(&"gel")
	check(gel_price > 0, "a loja aberta compra gosma")
	var menu: SlotMenu = panel.find_children("*", "SlotMenu", true, false)[0]
	panel._on_menu_requested(_slot_of(inventory, &"gel"))
	check(menu._sell_one.visible and menu._sell_all.visible, "menu oferece vender 1 e tudo")
	menu._sell_all.pressed.emit()
	check(inventory.count(&"gel") == 0 and wallet.coins() == 100
		- merchant.data.price_of(&"stone_axe") + 4 * gel_price, "vendeu a pilha")

	character.position = (game.region as Region).get_spawn_position()
	character.reset_physics_interpolation()
	await physics_frames(2)
	check(not shop.visible and not panel.visible, "longe, a loja e o inventário fecham")
	check(shop.sell_price_of(&"gel") == 0, "sem loja aberta, nada de vender")


func _merchant() -> NpcData:
	return DataCatalog.new(NPCS_DIR).get_entry(&"merchant") as NpcData


func _merchant_node(game: Node) -> Npc:
	for node in (game.region as Region).entities.get_children():
		if node is Npc:
			return node
	return null


func _slot_of(inventory: Inventory, item_id: StringName) -> int:
	for index in inventory.capacity():
		if inventory.slot_item(index) == item_id:
			return index
	return -1

