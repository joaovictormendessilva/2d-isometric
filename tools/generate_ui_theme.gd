extends SceneTree
## Gera `assets/ui/theme.tres` a partir dos tokens de `UiStyle` (fonte única das cores e
## espaços da interface). Rodar: G --headless --path . -s res://tools/generate_ui_theme.gd

const THEME_PATH := "res://assets/ui/theme.tres"


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font_size = UiStyle.FONT_SIZE
	theme.set_color(&"font_outline_color", &"Label", UiStyle.TEXT_OUTLINE)
	theme.set_constant(&"outline_size", &"Label", UiStyle.TEXT_OUTLINE_SIZE)
	theme.set_constant(&"separation", &"VBoxContainer", 0)
	theme.set_constant(&"separation", &"HBoxContainer", UiStyle.ROW_GAP)
	theme.set_stylebox(&"panel", &"PanelContainer",
		_box(UiStyle.PANEL_BACK, UiStyle.BORDER, UiStyle.WINDOW_MARGIN))
	_button(theme)
	_scroll_bar(theme)
	var error := ResourceSaver.save(theme, THEME_PATH)
	print("[ui-theme] %s: %s" % [THEME_PATH, error_string(error)])
	quit(error)


## Botões no estilo dos espaços do inventário: borda clara ao passar o mouse, dourada ao
## apertar ou com foco (teclado/controle), apagados quando desligados.
func _button(theme: Theme) -> void:
	var margin := UiStyle.BUTTON_MARGIN
	theme.set_stylebox(&"normal", &"Button", _box(UiStyle.SLOT_BACK, UiStyle.BORDER, margin))
	theme.set_stylebox(&"hover", &"Button", _box(UiStyle.SLOT_BACK, UiStyle.BORDER_HOVER, margin))
	theme.set_stylebox(&"pressed", &"Button", _box(UiStyle.PANEL_BACK, UiStyle.ACCENT, margin))
	var disabled := _box(UiStyle.SLOT_BACK, UiStyle.BORDER, margin)
	disabled.bg_color.a *= UiStyle.UNAVAILABLE_ALPHA
	theme.set_stylebox(&"disabled", &"Button", disabled)
	var focus := _box(Color.TRANSPARENT, UiStyle.ACCENT, margin)
	focus.draw_center = false
	theme.set_stylebox(&"focus", &"Button", focus)
	theme.set_color(&"font_color", &"Button", UiStyle.TEXT)
	theme.set_color(&"font_hover_color", &"Button", UiStyle.ACCENT)
	theme.set_color(&"font_pressed_color", &"Button", UiStyle.ACCENT)
	theme.set_color(&"font_focus_color", &"Button", UiStyle.TEXT)
	theme.set_color(&"font_disabled_color", &"Button",
		Color(UiStyle.TEXT, UiStyle.UNAVAILABLE_ALPHA))
	theme.set_color(&"font_outline_color", &"Button", UiStyle.TEXT_OUTLINE)
	theme.set_constant(&"outline_size", &"Button", UiStyle.TEXT_OUTLINE_SIZE)


## Barra de rolagem fina: trilho escuro, puxador com as cores de borda (claro ao passar o
## mouse, dourado ao arrastar).
func _scroll_bar(theme: Theme) -> void:
	var thin := Vector2(UiStyle.SCROLL_BAR_WIDTH / 2.0, 0)
	theme.set_stylebox(&"scroll", &"VScrollBar", _box(UiStyle.SLOT_BACK, UiStyle.SLOT_BACK, thin))
	theme.set_stylebox(&"grabber", &"VScrollBar", _box(UiStyle.BORDER, UiStyle.BORDER, thin))
	theme.set_stylebox(&"grabber_highlight", &"VScrollBar",
		_box(UiStyle.BORDER_HOVER, UiStyle.BORDER_HOVER, thin))
	theme.set_stylebox(&"grabber_pressed", &"VScrollBar", _box(UiStyle.ACCENT, UiStyle.ACCENT, thin))


static func _box(back: Color, border: Color, margin: Vector2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = back
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	return box
