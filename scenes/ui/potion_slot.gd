class_name PotionSlot
extends HBoxContainer
## HUD: a poção que a tecla de poção bebe (o mesmo quadrado do inventário, com quantas há), a
## tecla e a espera entre poções (quadrado apagado com os segundos que faltam). Sem poções, o
## quadrado fica vazio e apagado, mas continua ali: o jogador sabe que a tecla existe. Só lê
## estado.

var _inventory: Inventory
var _items: ItemDatabase
var _cooldowns: Cooldowns
var _potion: ConsumableData
var _view := View.new()
var _wait := Label.new()
var _key := Label.new()


## Quadrado de item só para mostrar (sem cliques nem dica).
class View extends SlotView:
	func _init() -> void:
		_build(0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_view)
	_wait.size = SlotView.SIZE
	_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_view.add_child(_wait)
	_key.modulate.a = UiStyle.HINT_ALPHA
	add_child(_key)
	set_process(false)


func setup(inventory: Inventory, items: ItemDatabase, cooldowns: Cooldowns) -> void:
	_inventory = inventory
	_items = items
	_cooldowns = cooldowns
	_key.text = Texts.format(&"HUD_POTION_KEY", [Texts.action_key(&"use_potion")])
	inventory.slot_changed.connect(_refresh.unbind(1))
	inventory.resized.connect(_refresh)
	cooldowns.started.connect(_refresh.unbind(2))
	_refresh()


func _refresh() -> void:
	var index := ConsumableRules.healing_slot(_inventory, _items)
	_potion = _items.get_item(_inventory.slot_item(index)) as ConsumableData if index >= 0 else null
	_show()


## Roda só durante a espera (contagem dos segundos).
func _process(_delta: float) -> void:
	_show()


## Durante a espera, os segundos ocupam o lugar da quantidade.
func _show() -> void:
	var left := _cooldowns.remaining(_potion.cooldown_group, NetRules.now()) if _potion else 0.0
	var waiting := left > 0.0
	set_process(waiting)
	_wait.text = str(ceili(left)) if waiting else ""
	var amount := 1 if waiting or _potion == null else _inventory.count(_potion.id)
	_view.show_item(_potion, amount, "")
	_view.modulate.a = 1.0 if _potion and not waiting else UiStyle.UNAVAILABLE_ALPHA
