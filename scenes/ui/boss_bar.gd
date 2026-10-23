class_name BossBar
extends VBoxContainer
## Barra de vida do chefe (F4) para o jogador LOCAL: nome e vida no alto da tela, enquanto ele
## estiver perto de um chefe vivo na mesma região. Some quando se afasta ou o chefe morre. Só
## lê estado (a vida vem do host como a de qualquer criatura). Enfurecido (fase 2), a barra fica
## laranja.

## Distância (chão) do jogador ao chefe para mostrar a barra: um pouco além da coleira dele.
const SHOW_RANGE := 280.0
const BAR_SIZE := Vector2(200, 6)
const TOP_MARGIN := 6.0

var _character: Character
var _boss: Monster
var _name := Label.new()
var _back := ColorRect.new()
var _fill := ColorRect.new()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	position.y = TOP_MARGIN
	add_theme_constant_override(&"separation", 0)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)
	_back.custom_minimum_size = BAR_SIZE
	_back.color = UiStyle.PANEL_BACK
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_back)
	_fill.color = UiStyle.HEALTH
	_fill.size = BAR_SIZE
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.add_child(_fill)


## A cada personagem do jogador local (recriado numa viagem).
func set_character(character: Character) -> void:
	_character = character


func _process(_delta: float) -> void:
	var boss := _nearest_boss()
	if boss != _boss:
		_boss = boss
		if boss:
			_name.text = boss.data.get_display_name()
	visible = _boss != null
	if _boss:
		_fill.color = UiStyle.ENRAGED if _boss.phase == 2 else UiStyle.HEALTH
		var health := _boss.health
		_fill.size.x = roundf(BAR_SIZE.x * health.current / maxf(health.max_health, 1))


## Chefe vivo mais perto do jogador, no mundo dele e dentro de SHOW_RANGE (ou null).
func _nearest_boss() -> Monster:
	if not is_instance_valid(_character):
		return null
	var best: Monster
	var best_distance := SHOW_RANGE
	for node in get_tree().get_nodes_in_group(Monster.BOSS_GROUP):
		var boss := node as Monster
		if boss.get_world_2d() != _character.get_world_2d() or not boss.is_alive():
			continue
		var distance := Iso.ground_distance(boss.position, _character.position)
		if distance <= best_distance:
			best = boss
			best_distance = distance
	return best
