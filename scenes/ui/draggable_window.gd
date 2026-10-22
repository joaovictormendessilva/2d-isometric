class_name DraggableWindow
extends PanelContainer
## Janela da interface que o jogador arrasta pela barra de título e que lembra onde ficou
## (`UserSettings`). Não bloqueia o jogo: fora dela, mouse e teclado seguem para o mundo.
## Uso: `setup(título, chave)` e depois `add_content(nó)`. Sem posição guardada, a janela abre em
## `default_place` (fração do espaço livre da tela: 0,5 x 0,5 = centro).

const SETTINGS_SECTION := "windows"

var _key := ""
var _default_place := Vector2(0.5, 0.5)
var _column := VBoxContainer.new()
var _title := Label.new()
var _dragging := false
## Onde o ponteiro pegou a janela, em relação ao canto dela: a janela acompanha o ponteiro
## sem "escorregar" (posição absoluta, não somando deslocamentos).
var _grab_offset := Vector2.ZERO


func _ready() -> void:
	add_child(_column)
	_column.add_child(_title)
	add_to_group(LocalPlayerInput.MOUSE_CAPTURE_GROUP)


func setup(title: String, settings_key: String, default_place := Vector2(0.5, 0.5)) -> void:
	_key = settings_key
	_default_place = default_place
	_title.text = title
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_STOP  # a barra de título pega o clique
	_title.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_title.gui_input.connect(_on_title_input)
	resized.connect(_place, CONNECT_ONE_SHOT)  # posição só depois de saber o tamanho
	# Conteúdo que cresce depois (ex.: ofertas da loja) não empurra a janela para fora da tela.
	resized.connect(func() -> void: position = _clamped(position))


func set_title(title: String) -> void:
	_title.text = title


func add_content(node: Control) -> void:
	_column.add_child(node)


## Ajusta o tamanho ao conteúdo atual (contêineres crescem sozinhos, mas não encolhem).
func fit_content() -> void:
	reset_size.call_deferred()


## A janela contém este ponto da tela?
func contains_screen_point(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


## Enquanto é arrastada, o mouse é da janela (não ataca no mundo).
func captures_mouse() -> bool:
	return _dragging


func _place() -> void:
	var fallback := (get_viewport_rect().size - size) * _default_place
	position = _clamped(UserSettings.get_value(SETTINGS_SECTION, _key, fallback.round()))


func _on_title_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		_grab_offset = get_global_mouse_position() - position
		if not _dragging:
			UserSettings.set_value(SETTINGS_SECTION, _key, position)
	elif event is InputEventMouseMotion and _dragging:
		position = _clamped(get_global_mouse_position() - _grab_offset)


## A janela nunca sai da tela.
func _clamped(at: Vector2) -> Vector2:
	var limit := get_viewport_rect().size - size
	return Vector2(clampf(at.x, 0.0, maxf(limit.x, 0.0)), clampf(at.y, 0.0, maxf(limit.y, 0.0))).round()
