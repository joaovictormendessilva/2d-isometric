class_name EventBanner
extends VBoxContainer
## Aviso de evento no alto da tela, abaixo da barra do chefe (ADR-036): título e, embaixo, a
## região. Entra com um pulo curto, fica alguns segundos e some. Um aviso novo substitui o atual.
## Só apresentação; o texto vem do BossEvents.

const TOP_MARGIN := 34.0
const HOLD_TIME := 4.0
const FADE_TIME := 0.5
## Entrada: começa um pouco acima e desce (px), em `POP_TIME`.
const POP_OFFSET := 6.0
const POP_TIME := 0.15
## Cor do título por tipo de aviso: chegou (destaque), foi embora (neutro), derrotado (ganho).
const TITLE_COLORS := {
	BossEvents.Announcement.APPEARED: UiStyle.ACCENT,
	BossEvents.Announcement.LEFT: UiStyle.TEXT_SOFT,
	BossEvents.Announcement.DEFEATED: UiStyle.POSITIVE,
}
const TITLE_KEYS := {
	BossEvents.Announcement.APPEARED: &"EVENT_BOSS_APPEARED",
	BossEvents.Announcement.LEFT: &"EVENT_BOSS_LEFT",
	BossEvents.Announcement.DEFEATED: &"EVENT_BOSS_DEFEATED",
}

var regions: DataCatalog

var _title := Label.new()
var _where := Label.new()
var _tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_theme_constant_override(&"separation", 0)
	for label in [_title, _where]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
	_where.modulate = Color(1, 1, 1, UiStyle.HINT_ALPHA)


func show_event(kind: BossEvents.Announcement, event: BossEventData, region_id: StringName) -> void:
	var boss_name := event.boss_data().get_display_name()
	_title.text = Texts.format(TITLE_KEYS[kind], [boss_name])
	_title.add_theme_color_override(&"font_color", TITLE_COLORS[kind])
	var region := regions.get_entry(region_id) as RegionData
	_where.text = Texts.format(&"EVENT_WHERE", [region.get_display_name()])
	if _tween:
		_tween.kill()
	visible = true
	modulate.a = 1.0
	position.y = TOP_MARGIN - POP_OFFSET
	_tween = create_tween()
	_tween.tween_property(self, "position:y", TOP_MARGIN, POP_TIME).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(hide)


func current_text() -> String:
	return _title.text if visible else ""
