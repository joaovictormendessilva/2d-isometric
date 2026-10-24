extends TestCase
## Tela de partida (Etapa I3): escolher sozinho/hospedar/entrar sem linha de comando, a tela
## por cima enquanto o jogo abre e de volta com o motivo se a partida não abrir ou o host cair.
## Cada GameStart fica num SubViewport com a própria API de rede (como outro computador).

const START_SCENE := preload("res://scenes/main/game_start.tscn")
## O formulário da tela entra sempre na porta padrão; o host de teste fica só neste PC.
const PORT := NetRules.DEFAULT_PORT
const CODE := "K7MQ4PXA"


func test_network_and_capture_arguments_skip_the_screen() -> void:
	check(GameStart._starts_directly(PackedStringArray(["--join=127.0.0.1", "--code=AB"])),
		"--join vai direto ao jogo")
	check(GameStart._starts_directly(PackedStringArray(["--host"])), "--host vai direto")
	check(GameStart._starts_directly(PackedStringArray(["--screenshot=a.png"])), "captura vai direto")
	check(not GameStart._starts_directly(PackedStringArray(["--lang=en", "--hostile"])),
		"idioma (e argumento parecido) mostra a tela")


func test_join_needs_an_address_and_a_full_code() -> void:
	var menu := add_to_tree(MatchMenu.new()) as MatchMenu
	menu._show_join_form()
	check(menu._join_button.disabled, "sem IP: Entrar apagado")
	check(menu._join_hint.text == Texts.get_text(&"MENU_NEED_ADDRESS"), "e diz que falta o IP")
	_type(menu._address, "192.168.0.10")
	_type(menu._code, "k7mq-4px")
	check(menu._join_hint.text == Texts.format(&"MENU_NEED_CODE", [MatchCode.LENGTH]),
		"código curto: diz quantas letras")
	var picked := []
	menu.chosen.connect(func(role: Network.Role, address: String, code: String) -> void:
		picked.append([role, address, code]))
	menu._submit_join()
	check(picked.is_empty(), "Enter com o código incompleto não entra")
	_type(menu._code, "k7mq-4pxa")
	check(not menu._join_button.disabled, "tudo certo: Entrar aceso")
	menu._join_button.pressed.emit()
	check(picked == [[Network.Role.CLIENT, "192.168.0.10", CODE]],
		"entra com o IP e o código como o jogo usa (%s)" % [picked])
	var again := add_to_tree(MatchMenu.new()) as MatchMenu
	check(again._address.text == "192.168.0.10", "lembra o IP na próxima vez")
	check(again._code.text.is_empty(), "o código não é guardado")


func test_playing_solo_hides_the_screen_when_the_player_arrives() -> void:
	var start := _start_screen("Solo")
	(start._menu as MatchMenu).chosen.emit(Network.Role.OFFLINE, "", "")
	check(await wait_until(func() -> bool: return start._menu == null), "a tela some com o jogador no mundo")
	check(start._game != null and _joined(start._game), "jogo sozinho aberto")


func test_wrong_code_returns_to_the_screen_with_the_reason() -> void:
	start_network_game("Host", Network.Role.HOST, PORT, "", false, CODE)
	var start := _start_screen("Client")
	(start._menu as MatchMenu).chosen.emit(Network.Role.CLIENT, Network.LOOPBACK, "AAAAAAAA")
	var reason := Texts.get_text(&"NET_REFUSED_CODE")
	check(await wait_until(func() -> bool: return _message(start) == reason),
		"de volta à tela com o motivo (\"%s\")" % _message(start))
	await physics_frames(2)
	check(start._game == null and start.get_parent().get_child_count() == 1,
		"o jogo recusado foi fechado")
	var first_choice := start._menu._choices.get_child(0) as Button
	check(start._menu._choices.visible and not first_choice.disabled, "a tela volta a responder")
	(start._menu as MatchMenu).chosen.emit(Network.Role.CLIENT, Network.LOOPBACK, CODE)
	check(await wait_until(func() -> bool: return start._menu == null), "com o código certo, entra")
	check(_joined(start._game), "e recebe o próprio personagem")


func test_losing_the_host_returns_to_the_screen() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT, "", false, CODE)
	var start := _start_screen("Client")
	(start._menu as MatchMenu).chosen.emit(Network.Role.CLIENT, Network.LOOPBACK, CODE)
	check(await wait_until(func() -> bool: return start._menu == null), "entrou")
	host.get_parent().free()  # host fecha o jogo
	var reason := Texts.get_text(&"NET_HOST_LOST")
	check(await wait_until(func() -> bool: return _message(start) == reason),
		"de volta à tela: perdeu o host (\"%s\")" % _message(start))


# --- Auxiliares ------------------------------------------------------------------------------

func _start_screen(instance_name: String) -> GameStart:
	var viewport := SubViewport.new()
	viewport.name = instance_name
	add_to_tree(viewport)
	tree.set_multiplayer(SceneMultiplayer.new(), viewport.get_path())
	_multiplayer_roots.append(viewport.get_path())
	var start: GameStart = START_SCENE.instantiate()
	viewport.add_child(start)
	return start


## Digitar no campo (a Godot só avisa text_changed quando é o jogador que digita).
static func _type(field: LineEdit, text: String) -> void:
	field.text = text
	field.text_changed.emit(text)


static func _message(start: GameStart) -> String:
	return start._menu._message.text if start._menu != null else ""


static func _joined(game: Node) -> bool:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) != null
