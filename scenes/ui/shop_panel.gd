class_name ShopPanel
extends Control
## Loja de um NPC para o jogador LOCAL (F3): abre com a tecla de interagir perto dele e
## mostra as moedas e o que ele vende; clicar numa oferta compra uma unidade. Vender é pelo
## inventário, que abre junto (botão direito num item: "Vender"; ver InventoryPanel).
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

var _inventory: Inventory
var _wallet: Wallet
var _player_state: PlayerStateSync
var _player_id := 0
var _items: ItemDatabase
var _npc: Npc
var _window := DraggableWindow.new()
var _offers := VBoxContainer.new()
var _rows: Array[OfferRow] = []
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
	_items = items
	_player_state = player_state
	_player_id = player_id
	_window.setup("", SETTINGS_KEY, DEFAULT_PLACE)
	var coins := CoinLabel.new()
	coins.setup(wallet)
	_window.add_content(coins)
	_offers.add_theme_constant_override(&"separation", ROW_GAP)
	_window.add_content(_offers)
	_window.add_content(HintLabel.create(Texts.get_text(&"SHOP_HINT"), HINT_WIDTH))
	inventory.slot_changed.connect(_queue_refresh.unbind(1))
	wallet.changed.connect(_queue_refresh.unbind(1))


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
	_window.set_title(_npc.data.get_display_name())
	var ids: Array[StringName] = []
	ids.assign(_npc.data.offers.keys())
	ids.sort()  # ordem estável na tela
	for item_id in ids:
		var row := OfferRow.new()
		row.setup(_npc.data, _items.get_item(item_id))
		row.buy_requested.connect(_player_state.request_buy)
		_offers.add_child(row)
		_rows.append(row)


## Uma compra muda moedas e espaços: atualiza uma vez só, no fim do quadro.
func _queue_refresh() -> void:
	if visible and not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	for row in _rows:
		row.refresh(_inventory, _wallet)
