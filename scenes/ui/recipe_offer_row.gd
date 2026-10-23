class_name RecipeOfferRow
extends ListRow
## Uma receita que o NPC ensina (F3c): ícone do que ela fabrica, "Receita: <nome>" e o preço em
## moedas (vermelho se não der). Clique pede para aprender; quem decide é o host. Já aprendida,
## fica apagada com "Já aprendida" no lugar do preço. A dica diz onde fabricar e com o quê.

signal learn_requested(recipe_id: StringName)

const MISSING_COLOR := UiStyle.DANGER
const KNOWN_COLOR := UiStyle.POSITIVE
## Lugar da receita → texto "Fabrique ...: <ingredientes>".
const STATION_TEXTS := {
	RecipeData.Station.HAND: &"SHOP_RECIPE_AT_HAND",
	RecipeData.Station.WORKBENCH: &"SHOP_RECIPE_AT_WORKBENCH",
}
## Motivo de não poder aprender → chave de texto.
const CHECK_TEXTS := {
	TradeRules.Check.NOT_ENOUGH_COINS: &"SHOP_NOT_ENOUGH_COINS",
	TradeRules.Check.ALREADY_KNOWN: &"SHOP_RECIPE_KNOWN",
}

var recipe: RecipeData

var _npc: NpcData
var _price: HBoxContainer
var _known := Label.new()
var _description := ""


func setup(npc: NpcData, p_recipe: RecipeData, items: ItemDatabase) -> void:
	_npc = npc
	recipe = p_recipe
	build(recipe.result, Texts.format(&"SHOP_RECIPE_NAME", [recipe.result.get_display_name()]))
	_price = ListRow.chip(CoinLabel.COIN_ICON, npc.recipe_price(recipe.id))
	details.add_child(_price)
	_known.text = Texts.get_text(&"SHOP_RECIPE_KNOWN")
	_known.modulate = KNOWN_COLOR
	_known.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(_known)
	var ingredients := PackedStringArray()
	for item_id in recipe.ingredients:
		ingredients.append(Texts.format(&"RECIPE_INGREDIENT",
			[recipe.ingredients[item_id], items.get_item(item_id).get_display_name()]))
	_description = "%s\n%s" % [ItemTexts.describe(recipe.result),
		Texts.format(STATION_TEXTS[recipe.station], [", ".join(ingredients)])]
	activated.connect(func() -> void: learn_requested.emit(recipe.id))


func refresh(book: RecipeBook, wallet: Wallet) -> void:
	var state := TradeRules.check_learn(_npc, recipe, book, wallet)
	var known := state == TradeRules.Check.ALREADY_KNOWN
	_price.visible = not known
	_known.visible = known
	# Preço = rótulo do chip (ver ListRow.chip).
	_price.get_child(1).modulate = MISSING_COLOR \
		if state == TradeRules.Check.NOT_ENOUGH_COINS else UiStyle.ACCENT
	var tooltip := _description
	if state != TradeRules.Check.OK:
		tooltip += "\n" + Texts.get_text(CHECK_TEXTS.get(state, &"SHOP_NOT_SOLD"))
	set_available(state == TradeRules.Check.OK, tooltip)
