class_name ItemIcon
extends RefCounted
## Ícone de item com quantidade no canto: o mesmo desenho no espaço do inventário e no item
## que está na mão (seguindo o mouse).


static func icon(size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Quantidade alinhada ao canto de baixo à direita de uma área de `size`.
static func amount_label(size: Vector2) -> Label:
	var label := Label.new()
	label.size = size
	label.position = Vector2(-1, 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Mostra `amount` de `item` (null = vazio). Quantidade só aparece em pilhas de 2 ou mais.
static func show_stack(rect: TextureRect, label: Label, item: ItemData, amount: int) -> void:
	rect.texture = item.icon if item else null
	label.text = str(amount) if item and amount > 1 else ""
