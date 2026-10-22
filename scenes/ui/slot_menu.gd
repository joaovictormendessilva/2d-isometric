class_name SlotMenu
extends PanelContainer
## Menu do botão direito num espaço do inventário: "Equipar" (equipamentos), "Dividir" (pilhas
## de 2 ou mais), "Soltar" (a pilha inteira cai no chão) e, com uma loja aberta que compra o
## item, "Vender 1" e "Vender tudo" (com quanto rende). Fecha ao escolher, com Esc ou com um
## clique fora dele; esse clique não vira ataque (o menu está no grupo que segura o mouse).

signal equip_chosen(index: int)
signal split_chosen(index: int)
signal drop_chosen(index: int)
signal sell_chosen(index: int, amount: int)

var _index := 0
var _amount := 0
var _equip := Button.new()
var _split := Button.new()
var _drop := Button.new()
var _sell_one := Button.new()
var _sell_all := Button.new()


func _ready() -> void:
	visible = false
	add_to_group(LocalPlayerInput.MOUSE_CAPTURE_GROUP)
	var column := VBoxContainer.new()
	add_child(column)
	for entry: Array in [[_equip, &"SLOT_MENU_EQUIP", equip_chosen],
			[_split, &"SLOT_MENU_SPLIT", split_chosen], [_drop, &"SLOT_MENU_DROP", drop_chosen]]:
		var button: Button = entry[0]
		button.text = Texts.get_text(entry[1])
		button.pressed.connect(_choose.bind(entry[2]))
		column.add_child(button)
	_sell_one.pressed.connect(_sell.bind(false))
	_sell_all.pressed.connect(_sell.bind(true))
	column.add_child(_sell_one)
	column.add_child(_sell_all)


## Abre para o espaço `index` (com `amount` itens), perto de `at` (tela). `sell_price`: quanto
## a loja aberta paga por unidade (0 = sem venda).
func open(index: int, amount: int, equippable: bool, sell_price: int, at: Vector2) -> void:
	_index = index
	_amount = amount
	_equip.visible = equippable
	_split.visible = amount > 1
	_sell_one.visible = sell_price > 0
	_sell_one.text = Texts.format(&"SLOT_MENU_SELL_ONE", [sell_price])
	_sell_all.visible = sell_price > 0 and amount > 1
	_sell_all.text = Texts.format(&"SLOT_MENU_SELL_ALL", [sell_price * amount])
	visible = true
	reset_size()
	var limit := get_viewport_rect().size - size
	position = Vector2(clampf(at.x, 0.0, limit.x), clampf(at.y, 0.0, limit.y)).round()


func captures_mouse() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var button := event as InputEventMouseButton
	if button and button.pressed and not get_global_rect().has_point(button.position):
		# Adiado: neste mesmo clique o menu ainda conta como aberto (não ataca).
		hide.call_deferred()
	elif event.is_action_pressed(&"ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func _choose(chosen: Signal) -> void:
	hide()
	chosen.emit(_index)


func _sell(everything: bool) -> void:
	hide()
	sell_chosen.emit(_index, _amount if everything else 1)
