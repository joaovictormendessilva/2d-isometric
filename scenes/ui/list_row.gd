class_name ListRow
extends PanelContainer
## Linha clicável de lista da interface (receita, oferta de loja, receita à venda): ícone e nome em
## cima e, embaixo, o que a subclasse puser em `details` (ingredientes, preço). Borda clara ao
## passar o mouse; apagada quando indisponível (o motivo vai na dica). Clique numa linha
## disponível emite `activated`; quem decide o resultado é o host.

signal activated

const ICON_SIZE := Vector2(16, 16)
const UNAVAILABLE_ALPHA := UiStyle.UNAVAILABLE_ALPHA

## Linha de baixo, para a subclasse preencher.
var details := HBoxContainer.new()

var _style := StyleBoxFlat.new()
var _available := false


## Monta a linha com o ícone e o nome de `item` (ou `title`, se dado).
func build(item: ItemData, title: String = "") -> void:
	_style.bg_color = UiStyle.SLOT_BACK
	_style.border_color = UiStyle.BORDER
	_style.set_border_width_all(1)
	_style.set_content_margin_all(2)
	add_theme_stylebox_override(&"panel", _style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon := make_icon(item)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_label := Label.new()
	name_label.text = title if not title.is_empty() else item.get_display_name()
	column.add_child(name_label)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(details)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


## Acesa ou apagada; `tooltip` explica (o que é e, se indisponível, o que falta).
func set_available(available: bool, tooltip: String) -> void:
	_available = available
	modulate.a = 1.0 if available else UNAVAILABLE_ALPHA
	tooltip_text = tooltip


## Ícone pequeno com quantidade ao lado (ingrediente, preço em moedas).
static func chip(texture: Texture2D, amount: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	var icon := ItemIcon.icon(ICON_SIZE)
	icon.custom_minimum_size = ICON_SIZE
	icon.texture = texture
	box.add_child(icon)
	var label := Label.new()
	label.text = str(amount)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return box


static func make_icon(item: ItemData) -> TextureRect:
	var icon := ItemIcon.icon(ICON_SIZE)
	icon.custom_minimum_size = ICON_SIZE
	icon.texture = item.icon
	return icon


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		if _available:
			activated.emit()
		accept_event()  # mesmo indisponível: o clique é da janela, não do mundo


func _set_hovered(value: bool) -> void:
	_style.border_color = UiStyle.BORDER_HOVER if value else UiStyle.BORDER
	queue_redraw()
