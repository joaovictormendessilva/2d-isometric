class_name OfferRow
extends ListRow
## Um item à venda na loja de um NPC: ícone, nome e o preço em moedas (vermelho se não der).
## Clique pede para comprar UMA unidade; quem decide é o host. Apagada quando não dá agora (o
## motivo aparece ao passar o mouse).

signal buy_requested(item_id: StringName)

const MISSING_COLOR := UiStyle.DANGER
## Motivo de não poder comprar → chave de texto.
const CHECK_TEXTS := {
	TradeRules.Check.NOT_ENOUGH_COINS: &"SHOP_NOT_ENOUGH_COINS",
	TradeRules.Check.INVENTORY_FULL: &"SHOP_INVENTORY_FULL",
}

var item: ItemData

var _npc: NpcData
var _price: HBoxContainer


func setup(npc: NpcData, p_item: ItemData) -> void:
	_npc = npc
	item = p_item
	build(item)
	_price = ListRow.chip(CoinLabel.COIN_ICON, npc.price_of(item.id))
	details.add_child(_price)
	activated.connect(func() -> void: buy_requested.emit(item.id))


func refresh(inventory: Inventory, wallet: Wallet) -> void:
	var state := TradeRules.check_buy(_npc, item.id, inventory, wallet)
	# Preço = rótulo do chip (ver ListRow.chip).
	_price.get_child(1).modulate = MISSING_COLOR \
		if state == TradeRules.Check.NOT_ENOUGH_COINS else UiStyle.ACCENT
	var tooltip := ItemTexts.describe(item)
	if state != TradeRules.Check.OK:
		tooltip += "\n" + Texts.get_text(CHECK_TEXTS.get(state, &"SHOP_NOT_SOLD"))
	set_available(state == TradeRules.Check.OK, tooltip)
