class_name Screenshot
extends RefCounted
## Captura de tela pela linha de comando (`--screenshot=<caminho.png>`): usada pelo jogo
## (main.gd) e pela tela de partida (GameStart, com `--match-screen`).

const ARG := "--screenshot="


## Caminho pedido na linha de comando; vazio = não é captura.
static func path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(ARG):
			return arg.trim_prefix(ARG)
	return ""


static func capture_and_quit(node: Node, file: String) -> void:
	await RenderingServer.frame_post_draw
	node.get_viewport().get_texture().get_image().save_png(file)
	print("[main] screenshot: %s" % file)
	node.get_tree().quit()
