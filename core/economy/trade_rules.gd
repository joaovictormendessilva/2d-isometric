class_name TradeRules
extends RefCounted
## Regras de compra e venda com um NPC (sem nós): se o jogador pode e a troca em si, sempre
## tudo ou nada. Usadas pelo host para decidir e por todos para mostrar.

enum Check { OK, NOT_SOLD, NOT_ENOUGH_COINS, INVENTORY_FULL, NOT_BOUGHT, WALLET_FULL,
	NOT_TAUGHT, ALREADY_KNOWN }


## Comprar UMA unidade de `item_id` de `npc`.
static func check_buy(npc: NpcData, item_id: StringName, inventory: Inventory,
		wallet: Wallet) -> Check:
	if not npc.sells(item_id):
		return Check.NOT_SOLD
	if not wallet.can_afford(npc.price_of(item_id)):
		return Check.NOT_ENOUGH_COINS
	if not inventory.can_add(item_id, 1):
		return Check.INVENTORY_FULL
	return Check.OK


static func buy(npc: NpcData, item_id: StringName, inventory: Inventory, wallet: Wallet) -> bool:
	if check_buy(npc, item_id, inventory, wallet) != Check.OK:
		return false
	wallet.spend(npc.price_of(item_id))
	inventory.add(item_id, 1)
	return true


## Vender `amount` da pilha do espaço `index` do inventário para `npc`.
static func check_sell(npc: NpcData, inventory: Inventory, index: int, amount: int,
		wallet: Wallet, items: ItemDatabase) -> Check:
	if not npc.buys_items or not inventory.is_valid_slot(index) \
			or amount < 1 or amount > inventory.slot_amount(index):
		return Check.NOT_BOUGHT
	var price := sell_price(items.get_item(inventory.slot_item(index)))
	if price <= 0:
		return Check.NOT_BOUGHT
	if not wallet.can_receive(price * amount):
		return Check.WALLET_FULL
	return Check.OK


static func sell(npc: NpcData, inventory: Inventory, index: int, amount: int, wallet: Wallet,
		items: ItemDatabase) -> bool:
	if check_sell(npc, inventory, index, amount, wallet, items) != Check.OK:
		return false
	var price := sell_price(items.get_item(inventory.slot_item(index)))
	inventory.set_slot(index, inventory.slot_item(index), inventory.slot_amount(index) - amount)
	wallet.add(price * amount)
	return true


## Aprender `recipe` com `npc` (F3c): ele precisa ensiná-la e o jogador ainda não sabê-la.
static func check_learn(npc: NpcData, recipe: RecipeData, book: RecipeBook,
		wallet: Wallet) -> Check:
	if recipe == null or not recipe.must_learn or not npc.teaches(recipe.id):
		return Check.NOT_TAUGHT
	if book.knows(recipe):
		return Check.ALREADY_KNOWN
	if not wallet.can_afford(npc.recipe_price(recipe.id)):
		return Check.NOT_ENOUGH_COINS
	return Check.OK


static func learn(npc: NpcData, recipe: RecipeData, book: RecipeBook, wallet: Wallet) -> bool:
	if check_learn(npc, recipe, book, wallet) != Check.OK:
		return false
	wallet.spend(npc.recipe_price(recipe.id))
	book.learn(recipe)
	return true


## Quanto um NPC paga por uma unidade (0 = não compra).
static func sell_price(item: ItemData) -> int:
	return item.sell_price if item else 0
