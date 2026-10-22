class_name DraggableWindow
extends PanelContainer
## Janela da interface que o jogador arrasta pela barra de título e que lembra onde ficou
## (`UserSettings`). Não bloqueia o jogo: fora dela, mouse e teclado seguem para o mundo.
## Uso: `setup(título, chave)` e depois `add_content(nó)`.

const SETTINGS_SECTION := "windows"

var _key := ""
var _column := VBoxContainer.new()
var _title := Label.new()
var _dragging := false


func _ready() -> void:
	add_child(_column)
	_column.add_child(_title)


func setup(title: String, settings_key: String) -> void:
	_key = settings_key
	_title.text = title
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_STOP  # a barra de título pega o clique
	_title.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_title.gui_input.connect(_on_title_input)
	resized.connect(_place, CONNECT_ONE_SHOT)  # posição só depois de saber o tamanho


func add_content(node: Control) -> void:
	_column.add_child(node)


## Ajusta o tamanho ao conteúdo atual (contêineres crescem sozinhos, mas não encolhem).
func fit_content() -> void:
	reset_size.call_deferred()


## A janela (sem a barra de título) contém este ponto da tela?
func contains_screen_point(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


func _place() -> void:
	var centered := (get_viewport_rect().size - size) / 2.0
	position = _clamped(UserSettings.get_value(SETTINGS_SECTION, _key, centered.round()))


func _on_title_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		if not _dragging:
			UserSettings.set_value(SETTINGS_SECTION, _key, position)
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		position = _clamped(position + motion.relative)


## A janela nunca sai da tela.
func _clamped(at: Vector2) -> Vector2:
	var limit := get_viewport_rect().size - size
	return Vector2(clampf(at.x, 0.0, maxf(limit.x, 0.0)), clampf(at.y, 0.0, maxf(limit.y, 0.0))).round()
