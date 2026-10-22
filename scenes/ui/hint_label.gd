class_name HintLabel
extends RefCounted
## Dica de uso em texto apagado no pé de uma janela (inventário, loja). Quebra linhas na largura
## dada: sem largura, o texto mediria uma palavra por linha.


static func create(text: String, width: float) -> Label:
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = width
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, UiStyle.HINT_ALPHA)
	hint.text = text
	return hint
