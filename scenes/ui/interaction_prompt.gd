class_name InteractionPrompt
extends Node2D
## Rótulo sobre o NPC ("[E] Mercador"), o baú de dungeon ("[E] Abrir o baú") ou o ponto de
## coleta ao alcance do jogador LOCAL:
## "[E] Árvore de lenha", ou o que falta para coletar ("Carvalho antigo: precisa de ferramenta
## nível 2"). Assim tudo com que se interage se identifica quando o jogador chega perto. Só
## apresentação.

const READY_COLOR := UiStyle.ACCENT
const BLOCKED_COLOR := UiStyle.WARNING
const LABEL_SIZE := Vector2(240, 12)
## Distância entre o topo do desenho do ponto e o rótulo.
const MARGIN := 2.0
## Procura o ponto 10 vezes por segundo (busca física), não todo quadro.
const REFRESH_INTERVAL := 0.1

## Diz qual NPC está ao alcance (sem ela, só pontos de coleta).
var player_state: PlayerStateSync

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
	visible = false
	if not is_instance_valid(_character):
		return
	# Mesma prioridade da tecla de interagir (LocalPlayerInput): NPC, baú, pedra de portal e por fim
	# a coleta.
	var npc := player_state.npc_near(_character.player_id) if player_state else null
	if npc:
		_show_over(npc, Texts.format(&"PROMPT_TALK",
			[Texts.action_key(&"interact"), npc.data.get_display_name()]), READY_COLOR)
		return
	var chest := player_state.chest_near(_character.player_id) if player_state else null
	if chest:
		_show_over(chest, Texts.format(&"PROMPT_OPEN_CHEST", [Texts.action_key(&"interact")]),
			READY_COLOR)
		return
	var stone := player_state.waystone_near(_character.player_id) if player_state else null
	if stone and _character.channel and _character.channel.is_channeling():
		return  # já viajando por ela
	if stone:
		var key := &"PROMPT_USE_WAYSTONE" if stone.is_lit() else &"PROMPT_ACTIVATE_WAYSTONE"
		_show_over(stone, Texts.format(key, [Texts.action_key(&"interact")]), READY_COLOR)
		return
	var gatherer := _character.gatherer
	var node := gatherer.find_node() if gatherer and not gatherer.is_gathering() else null
	if node == null:
		return
	var refusal := GatheringTexts.refusal(node.data, gatherer.check(node))
	if refusal.is_empty():
		_show_over(node, Texts.format(&"PROMPT_GATHER",
			[Texts.action_key(&"interact"), node.data.get_display_name()]), READY_COLOR)
	else:
		_show_over(node, Texts.format(&"PROMPT_BLOCKED", [node.data.get_display_name(), refusal]),
			BLOCKED_COLOR)


## Rótulo logo acima do desenho de `target` (nó com um filho "Sprite").
func _show_over(target: Node2D, text: String, color: Color) -> void:
	var sprite: Sprite2D = target.get_node("Sprite")
	position = target.position + Vector2(0.0, sprite.get_rect().position.y - MARGIN)
	_label.text = text
	_label.modulate = color
	visible = true
