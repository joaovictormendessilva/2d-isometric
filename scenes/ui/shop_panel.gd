class_name ShopPanel
extends Control
## Loja de um NPC para o jogador LOCAL (F3): abre com a tecla de interagir perto dele e
## mostra as moedas, o que ele vende e as receitas que ensina; clicar numa oferta compra uma
## unidade (ou aprende a receita). Vender é pelo inventário, que abre junto (botão direito num
## item: "Vender"; ver InventoryPanel).
## Fecha com a tecla de interagir de novo, junto com o inventário (I / Esc) ou ao se afastar.
## Não pausa o jogo. Cada ação é um pedido ao host (PlayerStateSync).

## A loja abriu ou fechou (o inventário acompanha; ver Main).
signal toggled(open: bool)

const SETTINGS_KEY := "shop"
## Sem posição guardada, abre à esquerda, no meio da altura (o inventário fica no centro).
const DEFAULT_PLACE := Vector2(0.02, 0.5)
const ROW_GAP := UiStyle.GAP
## Largura da dica (quebra em linhas): a da janela, sem esticá-la.
const HINT_WIDTH := 150.0
## Altura máxima da lista de ofertas: com mais itens, a lista rola (a janela cabe na tela de 360).
const MAX_OFFERS_HEIGHT := 180.0

var _inventory: Inventory
var _wallet: Wallet
var _book: RecipeBook
var _player_state: PlayerStateSync
var _player_id := 0
var _items: ItemDatabase
var _npc: Npc
var _window := DraggableWindow.new()
var _offers := VBoxContainer.new()
var _offers_scroll := ScrollContainer.new()
var _rows: Array[OfferRow] = []
## Receitas que o NPC ensina (seção escondida quando não ensina nenhuma).
var _recipe_section := VBoxContainer.new()
var _recipe_offers := VBoxContainer.new()
var _recipe_rows: Array[RecipeOfferRow] = []
var _refresh_queued := false


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # só a janela pega o mouse
	add_child(_window)


func setup(inventory: Inventory, wallet: Wallet, items: ItemDatabase,
		player_state: PlayerStateSync, player_id: int) -> void:
	_inventory = inventory
	_wallet = wallet
	_book = player_state.session.get_recipe_book(player_id)
	_items = items
	_player_state = player_state
	_player_id = player_id
	_window.setup("", SETTINGS_KEY, DEFAULT_PLACE)
	var coins := CoinLabel.new()
	coins.setup(wallet)
	_window.add_content(coins)
	_offers.add_theme_constant_override(&"separation", ROW_GAP)
	_offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offers_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_offers_scroll.add_child(_offers)
	_window.add_content(_offers_scroll)
	_recipe_section.add_theme_constant_override(&"separation", ROW_GAP)
	var recipes_title := Label.new()
	recipes_title.text = Texts.get_text(&"SHOP_RECIPES")
	recipes_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recipe_section.add_child(recipes_title)
	_recipe_offers.add_theme_constant_override(&"separation", ROW_GAP)
	_recipe_section.add_child(_recipe_offers)
	_window.add_content(_recipe_section)
	_window.add_content(HintLabel.create(Texts.get_text(&"SHOP_HINT"), HINT_WIDTH))
	inventory.slot_changed.connect(_queue_refresh.unbind(1))
	wallet.changed.connect(_queue_refresh.unbind(1))
	_book.learned.connect(_queue_refresh.unbind(2))


## NPC com quem o jogador está negociando (null = loja fechada).
func trading_with() -> Npc:
	return _npc if visible else null


## Quanto o NPC aberto paga por uma unidade de `item_id` (0 = loja fechada ou não compra).
func sell_price_of(item_id: StringName) -> int:
	var npc := trading_with()
	if npc == null or not npc.data.buys_items:
		return 0
	return TradeRules.sell_price(_items.get_item(item_id))


## Interagiu com `npc`: abre a loja dele, ou fecha se já estava aberta.
func talk_to(npc: Npc) -> void:
	if trading_with() == npc:
		close()
		return
	_npc = npc
	_build_offers()
	visible = true
	_window.fit_content()
	_refresh()
	toggled.emit(true)


func close() -> void:
	if not visible:
		return
	visible = false
	_npc = null
	toggled.emit(false)


## Longe do NPC (ou morto, ou em outra região), a conversa acaba.
func _process(_delta: float) -> void:
	if visible and _player_state.npc_near(_player_id) != _npc:
		close()


func _build_offers() -> void:
	for row in _rows:
		row.free()
	_rows.clear()
	for row in _recipe_rows:
		row.free()
	_recipe_rows.clear()
	_window.set_title(_npc.data.get_display_name())
	for item_id in _sorted_ids(_npc.data.offers):
		var row := OfferRow.new()
		row.setup(_npc.data, _items.get_item(item_id))
		row.buy_requested.connect(_player_state.request_buy)
		_offers.add_child(row)
		_rows.append(row)
	for recipe_id in _sorted_ids(_npc.data.recipe_offers):
		var recipe := _player_state.recipes.get_recipe(recipe_id)
		if recipe == null:
			continue  # dado errado (o teste de dados avisa); não quebra a loja
		var row := RecipeOfferRow.new()
		row.setup(_npc.data, recipe, _items)
		row.learn_requested.connect(_player_state.request_learn)
		_recipe_offers.add_child(row)
		_recipe_rows.append(row)
	_recipe_section.visible = not _recipe_rows.is_empty()
	# Loja curta: do tamanho das ofertas. Longa: altura máxima, rolando (com espaço para a barra).
	var content := _offers.get_combined_minimum_size()
	var scrolls := content.y > MAX_OFFERS_HEIGHT
	_offers_scroll.custom_minimum_size = Vector2(
		content.x + (UiStyle.SCROLL_BAR_WIDTH + UiStyle.GAP if scrolls else 0.0),
		minf(content.y, MAX_OFFERS_HEIGHT))
	_offers_scroll.scroll_vertical = 0


## Ids de uma tabela de preços em ordem estável na tela.
static func _sorted_ids(prices: Dictionary[StringName, int]) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(prices.keys())
	ids.sort()
	return ids


## Uma compra muda moedas e espaços: atualiza uma vez só, no fim do quadro.
func _queue_refresh() -> void:
	if visible and not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	for row in _rows:
		row.refresh(_inventory, _wallet)
	for row in _recipe_rows:
		row.refresh(_book, _wallet)
