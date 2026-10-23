class_name SlotMenu
extends ContextMenu
## Menu do botão direito num espaço do inventário: "Usar" (consumíveis, como a poção),
## "Equipar" (equipamentos), "Dividir" (pilhas
## de 2 ou mais), "Soltar" (a pilha inteira cai no chão) e, com uma loja aberta que compra o
## item, "Vender 1" e "Vender tudo" (com quanto rende). Fecha ao escolher (o resto: ContextMenu).

signal use_chosen(index: int)
signal equip_chosen(index: int)
signal split_chosen(index: int)
signal drop_chosen(index: int)
signal sell_chosen(index: int, amount: int)

var _index := 0
var _amount := 0
var _use := Button.new()
var _equip := Button.new()
var _split := Button.new()
var _drop := Button.new()
var _sell_one := Button.new()
var _sell_all := Button.new()


func _ready() -> void:
	super._ready()
	var column := VBoxContainer.new()
	add_child(column)
	for entry: Array in [[_use, &"SLOT_MENU_USE", use_chosen],
			[_equip, &"SLOT_MENU_EQUIP", equip_chosen],
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
func open(index: int, amount: int, usable: bool, equippable: bool, sell_price: int,
		at: Vector2) -> void:
	_index = index
	_amount = amount
	_use.visible = usable
	_equip.visible = equippable
	_split.visible = amount > 1
	_sell_one.visible = sell_price > 0
	_sell_one.text = Texts.format(&"SLOT_MENU_SELL_ONE", [sell_price])
	_sell_all.visible = sell_price > 0 and amount > 1
	_sell_all.text = Texts.format(&"SLOT_MENU_SELL_ALL", [sell_price * amount])
	_show_at(at)


func _choose(chosen: Signal) -> void:
	hide()
	chosen.emit(_index)


func _sell(everything: bool) -> void:
	hide()
	sell_chosen.emit(_index, _amount if everything else 1)
