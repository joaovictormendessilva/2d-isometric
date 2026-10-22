class_name InteractionPrompt
extends Node2D
## Rótulo sobre o ponto de coleta ao alcance do jogador LOCAL: "[E] Árvore de lenha", ou o que
## falta para coletar ("Carvalho antigo: precisa de ferramenta nível 2"). Assim todo ponto
## coletável se identifica quando o jogador chega perto. Só apresentação.

const READY_COLOR := Color("e8c15a")
const BLOCKED_COLOR := Color("ff9f6b")
const LABEL_SIZE := Vector2(240, 12)
## Distância entre o topo do desenho do ponto e o rótulo.
const MARGIN := 2.0
## Procura o ponto 10 vezes por segundo (busca física), não todo quadro.
const REFRESH_INTERVAL := 0.1

var _character: Character
var _label := Label.new()
var _refresh_left := 0.0


func _ready() -> void:
	_label.size = LABEL_SIZE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.position = Vector2(-LABEL_SIZE.x / 2.0, -LABEL_SIZE.y)
	add_child(_label)
	visible = false


func setup(character: Character) -> void:
	_character = character


func _physics_process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = REFRESH_INTERVAL
	var gatherer := _character.gatherer if is_instance_valid(_character) else null
	var node := gatherer.find_node() if gatherer and not gatherer.is_gathering() else null
	visible = node != null
	if not visible:
		return
	var sprite: Sprite2D = node.get_node("Sprite")
	position = node.position + Vector2(0.0, sprite.get_rect().position.y - MARGIN)
	var refusal := GatheringTexts.refusal(node.data, gatherer.check(node))
	if refusal.is_empty():
		_label.text = Texts.format(&"PROMPT_GATHER",
			[Texts.action_key(&"interact"), node.data.get_display_name()])
		_label.modulate = READY_COLOR
	else:
		_label.text = Texts.format(&"PROMPT_BLOCKED", [node.data.get_display_name(), refusal])
		_label.modulate = BLOCKED_COLOR
