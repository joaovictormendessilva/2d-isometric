class_name MatchMenu
extends ColorRect
## Tela de partida (Etapa I3): jogar sozinho, hospedar na rede local ou entrar numa partida
## (IP + código), sem linha de comando. Só escolhe: quem abre o jogo é GameStart, que mostra
## aqui o andamento ("Conectando...") e, se a partida acabar, o motivo.
## Teclado/controle: setas escolhem, Enter/A confirma, Esc/B volta do formulário.

signal chosen(role: Network.Role, address: String, code: String)

## Último IP digitado (conforto: o host costuma ser o mesmo computador). O código não é
## guardado: muda a cada partida.
const SETTINGS_SECTION := "match"
const SETTINGS_ADDRESS := "address"
const BUTTON_WIDTH := 170
const FIELD_WIDTH := 120
const ADDRESS_MAX_LENGTH := 15
const CODE_MAX_LENGTH := 12  # aceita espaços e hífen além das letras

var _choices := VBoxContainer.new()
var _join_form := VBoxContainer.new()
var _address := LineEdit.new()
var _code := LineEdit.new()
var _join_button: Button
var _join_hint := Label.new()
var _message := Label.new()


func _ready() -> void:
	color = UiStyle.SCREEN_BACK
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := _column()
	center.add_child(column)
	var title := Label.new()
	title.text = Texts.get_text(&"MENU_TITLE")
	title.modulate = UiStyle.ACCENT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var panel := PanelContainer.new()
	column.add_child(panel)
	var pages := VBoxContainer.new()
	panel.add_child(pages)
	pages.add_child(_choices)
	pages.add_child(_join_form)
	_build_choices()
	_build_join_form()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = BUTTON_WIDTH + 60
	column.add_child(_message)
	_show_choices()


## Mostra o aviso (motivo de a partida ter acabado) e volta às escolhas.
func show_message(text: String) -> void:
	_message.text = text
	_message.modulate = UiStyle.WARNING
	_set_enabled(true)
	_show_choices()


## Partida abrindo: tudo desligado, com o andamento embaixo.
func show_busy(text: String) -> void:
	_message.text = text
	_message.modulate = UiStyle.TEXT_SOFT
	_set_enabled(false)


func _unhandled_input(event: InputEvent) -> void:
	if _join_form.visible and event.is_action_pressed(&"ui_cancel"):
		_show_choices()
		get_viewport().set_input_as_handled()


func _build_choices() -> void:
	_style_column(_choices)
	_choices.add_child(_button(&"MENU_SOLO", _choose.bind(Network.Role.OFFLINE)))
	_choices.add_child(_button(&"MENU_HOST", _choose.bind(Network.Role.HOST_LAN)))
	_choices.add_child(_button(&"MENU_JOIN", _show_join_form))
	_choices.add_child(_button(&"MENU_QUIT", get_tree().quit))


func _build_join_form() -> void:
	_style_column(_join_form)
	_join_form.add_child(_field(&"MENU_ADDRESS", _address, &"MENU_ADDRESS_EXAMPLE",
		ADDRESS_MAX_LENGTH))
	_join_form.add_child(_field(&"MENU_CODE", _code, &"MENU_CODE_EXAMPLE", CODE_MAX_LENGTH))
	_address.text = UserSettings.get_value(SETTINGS_SECTION, SETTINGS_ADDRESS, "")
	_address.text_submitted.connect(func(_text: String) -> void: _code.grab_focus())
	_code.text_submitted.connect(_submit_join.unbind(1))
	for field: LineEdit in [_address, _code]:
		field.text_changed.connect(_refresh_join.unbind(1))
	_join_hint.modulate = Color(UiStyle.TEXT, UiStyle.HINT_ALPHA)
	_join_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_form.add_child(_join_hint)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_join_form.add_child(buttons)
	_join_button = _button(&"MENU_JOIN_CONFIRM", _submit_join)
	buttons.add_child(_join_button)
	buttons.add_child(_button(&"MENU_BACK", _show_choices))
	for button: Button in buttons.get_children():
		button.custom_minimum_size.x = (BUTTON_WIDTH - UiStyle.ROW_GAP) / 2


func _show_choices() -> void:
	_join_form.visible = false
	_choices.visible = true
	(_choices.get_child(0) as Control).grab_focus.call_deferred()


func _show_join_form() -> void:
	_message.text = ""
	_choices.visible = false
	_join_form.visible = true
	_refresh_join()
	(_code if _address.text.is_valid_ip_address() else _address).grab_focus.call_deferred()


## O que falta para entrar (IP válido, código completo): botão apagado com o porquê.
func _join_problem() -> String:
	if not _address.text.strip_edges().is_valid_ip_address():
		return Texts.get_text(&"MENU_NEED_ADDRESS")
	if MatchCode.normalize(_code.text).length() != MatchCode.LENGTH:
		return Texts.format(&"MENU_NEED_CODE", [MatchCode.LENGTH])
	return ""


func _refresh_join() -> void:
	var problem := _join_problem()
	_join_hint.text = problem
	_join_button.disabled = not problem.is_empty()


func _submit_join() -> void:
	if not _join_problem().is_empty() or _join_button.disabled:
		return
	var address := _address.text.strip_edges()
	UserSettings.set_value(SETTINGS_SECTION, SETTINGS_ADDRESS, address)
	_choose(Network.Role.CLIENT, address, MatchCode.normalize(_code.text))


func _choose(role: Network.Role, address: String = "", code: String = "") -> void:
	chosen.emit(role, address, code)


func _set_enabled(enabled: bool) -> void:
	for page: Control in [_choices, _join_form]:
		for node in page.find_children("*", "BaseButton", true, false):
			(node as BaseButton).disabled = not enabled
	_address.editable = enabled
	_code.editable = enabled
	if enabled:
		_refresh_join()


func _column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", UiStyle.ROW_GAP * 2)
	return column


func _style_column(page: VBoxContainer) -> void:
	page.add_theme_constant_override(&"separation", UiStyle.ROW_GAP)


func _field(label_key: StringName, field: LineEdit, example_key: StringName,
		max_length: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = Texts.get_text(label_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	field.placeholder_text = Texts.get_text(example_key)
	field.max_length = max_length
	field.custom_minimum_size.x = FIELD_WIDTH
	row.add_child(field)
	return row


func _button(key: StringName, action: Callable) -> Button:
	var button := Button.new()
	button.text = Texts.get_text(key)
	button.custom_minimum_size.x = BUTTON_WIDTH
	button.pressed.connect(action)
	return button
