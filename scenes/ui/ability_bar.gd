class_name AbilityBar
extends HBoxContainer
## HUD: as 4 teclas de habilidade do jogador local, embaixo no meio da tela (estilo V Rising). Cada
## quadrado mostra o ícone, a tecla e a recarga (escurece de cima para baixo e conta os segundos).
## Passar o mouse mostra o que a habilidade faz; botão direito escolhe qual habilidade aprendida vai
## na tecla (o host decide; ver AbilitySync). Só lê estado.

## Espaço embaixo da barra: a tecla de cada quadrado fica ali (o texto sobe um pouco no quadrado).
const BOTTOM_MARGIN := 12.0
const KEY_OVERLAP := 3.0

var _book: AbilityBook
var _abilities: AbilitySync
var _slots: Array[Slot] = []
var _menu := ChoiceMenu.new()


## Quadrado de uma tecla: o quadrado de item, com a tecla no canto e a recarga por cima.
class Slot extends SlotView:
	var ability: AbilityData
	var cooldown_left := 0.0
	var _key := Label.new()
	var _seconds := Label.new()
	## Sombra da recarga por cima do ícone: cobre de cima para baixo o que ainda falta.
	var _shade := ColorRect.new()

	func _init(p_index: int, key_text: String) -> void:
		_build(p_index)
		_shade.color = Color(UiStyle.PANEL_BACK, 1.0 - UiStyle.UNAVAILABLE_ALPHA)
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_shade)
		_key.text = key_text
		_key.size.x = SIZE.x
		_key.position = Vector2(0, SIZE.y - KEY_OVERLAP)
		_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_key.modulate.a = UiStyle.HINT_ALPHA
		add_child(_key)
		_seconds.size = SIZE
		_seconds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_seconds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_seconds)

	func show_ability(p_ability: AbilityData, seconds: float) -> void:
		if p_ability != ability:
			ability = p_ability
			_icon.texture = ability.icon if ability else null
			tooltip_text = AbilityTexts.describe(ability)
		# Comparação exata: "aproximada" achava 0,000005 igual a 0 e o fim da recarga não
		# apagava o último segundo da tela (o "1" ficava parado; teste do João, 2026-10-23).
		if seconds != cooldown_left:
			cooldown_left = seconds
			_seconds.text = str(ceili(seconds)) if seconds > 0.0 else ""
			var fraction := clampf(seconds / ability.cooldown, 0.0, 1.0) if ability else 0.0
			_shade.size = Vector2(SIZE.x, roundf(SIZE.y * fraction))

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			menu_requested.emit(index)
			accept_event()



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", UiStyle.GAP)
	set_process(false)  # até o setup
	for index in AbilityBook.SLOTS:
		var slot := Slot.new(index, Texts.action_key(LocalPlayerInput.ABILITY_ACTIONS[index]))
		slot.menu_requested.connect(_open_menu)
		add_child(slot)
		_slots.append(slot)
	# Com os quadrados já dentro (tamanho mínimo conhecido): embaixo, no meio.
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE,
		BOTTOM_MARGIN)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func setup(book: AbilityBook, abilities: AbilitySync) -> void:
	_book = book
	_abilities = abilities
	get_parent().add_child(_menu)
	book.changed.connect(_show)
	set_process(true)
	_show()


## Botão direito numa tecla: as habilidades aprendidas (pôr aqui) e "Esvaziar".
func _open_menu(index: int) -> void:
	var choices := []
	for ability in _book.learned():
		if ability != _book.in_slot(index):
			choices.append([ability.get_display_name(),
				_abilities.request_set_slot.bind(index, ability.id)])
	if _book.in_slot(index):
		choices.append([Texts.get_text(&"ABILITY_MENU_CLEAR"),
			_abilities.request_set_slot.bind(index, &"")])
	if not choices.is_empty():
		_menu.open(choices, get_viewport().get_mouse_position())


## Roda todo quadro só para contar as recargas (4 quadrados; barato).
func _process(_delta: float) -> void:
	_show()


func _show() -> void:
	var now := NetRules.now()
	for index in _slots.size():
		var ability := _book.in_slot(index)
		_slots[index].show_ability(ability,
			_book.cooldowns.remaining(ability.id, now) if ability else 0.0)
