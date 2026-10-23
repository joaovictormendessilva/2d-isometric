class_name EffectBar
extends HBoxContainer
## HUD: buffs e debuffs do jogador local, acima da vida. Um quadrado por efeito com o ícone e os
## segundos que faltam; borda verde para buff, vermelha para debuff (mesmo significado de cor em
## todo o jogo). Some quando não há efeito. Só lê estado (ADR-025).

var _effects: ActiveEffects
var _slots: Array[Slot] = []


## Quadrado de efeito: o quadrado de item, sem cliques, com a borda na cor do tipo de efeito.
class Slot extends SlotView:
	var border := UiStyle.BORDER

	func _init() -> void:
		_build(0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_effect(effect: StatusEffectData, seconds: float) -> void:
		_icon.texture = effect.icon
		_amount.text = str(ceili(seconds))
		var color := UiStyle.DANGER if effect.harmful else UiStyle.POSITIVE
		if color != border:
			border = color
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), UiStyle.SLOT_BACK)
		draw_rect(Rect2(Vector2.ZERO, SIZE), border, false, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", UiStyle.GAP)


func setup(effects: ActiveEffects) -> void:
	_effects = effects
	effects.changed.connect(_refresh)
	_refresh()


## Quantos quadrados estão à mostra (testes).
func shown_count() -> int:
	return _slots.size()


func _refresh() -> void:
	var entries := _effects.entries()
	while _slots.size() < entries.size():
		var slot := Slot.new()
		add_child(slot)
		_slots.append(slot)
	while _slots.size() > entries.size():
		_slots.pop_back().queue_free()
	visible = not entries.is_empty()
	set_process(visible)
	_show(entries)


## Roda só com efeitos ativos (contagem dos segundos).
func _process(_delta: float) -> void:
	_show(_effects.entries())


func _show(entries: Array[ActiveEffects.Entry]) -> void:
	for index in mini(entries.size(), _slots.size()):
		_slots[index].show_effect(entries[index].data, entries[index].remaining)
