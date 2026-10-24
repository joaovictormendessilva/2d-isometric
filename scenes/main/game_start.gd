class_name GameStart
extends Node
## Ponto de partida da janela (cena principal do projeto): a tela de partida (MatchMenu) e,
## escolhida a partida, o jogo (main.tscn). A tela fica por cima enquanto o jogo abre
## ("Conectando...") e some quando o jogador local chega ao mundo; se a partida não abrir ou o
## host cair, o jogo é fechado e a tela volta com o motivo.
## Com argumentos de rede ou de captura na linha de comando (testes, tools/coop-local.bat,
## capturas), vai direto ao jogo, configurado por eles.
##   --match-screen[=join]   mostra a tela mesmo assim (com o formulário de entrar), para
##                           capturas: `-- --match-screen=join --screenshot=<arquivo.png>`.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
## Argumentos que pulam a tela de partida.
const DIRECT_ARGS: Array[String] = ["--host", "--host-lan", "--join=", "--screenshot="]
const MENU_ARG := "--match-screen"
## Quadros até a tela estar desenhada (foco e layout se acertam no quadro seguinte).
const CAPTURE_FRAMES := 5
## Acima de toda a interface do jogo.
const MENU_LAYER := 100

var _game: Node
var _menu: MatchMenu
var _menu_layer := CanvasLayer.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Texts.apply_command_line(args)
	_menu_layer.layer = MENU_LAYER
	add_child(_menu_layer)
	if args.has(MENU_ARG) or args.has(MENU_ARG + "=join"):
		_show_menu("")
		if args.has(MENU_ARG + "=join"):
			_menu._show_join_form()
		if not Screenshot.path().is_empty():
			for i in CAPTURE_FRAMES:
				await get_tree().process_frame
			Screenshot.capture_and_quit(self, Screenshot.path())
	elif _starts_directly(args):
		_start_game(null)
	else:
		_show_menu("")


static func _starts_directly(args: PackedStringArray) -> bool:
	for arg in args:
		for direct in DIRECT_ARGS:
			if arg == direct or (direct.ends_with("=") and arg.begins_with(direct)):
				return true
	return false


func _show_menu(message: String) -> void:
	if _menu == null:
		_menu = MatchMenu.new()
		_menu.chosen.connect(_on_chosen)
		_menu_layer.add_child(_menu)
	if not message.is_empty():
		_menu.show_message(message)


func _on_chosen(role: Network.Role, address: String, code: String) -> void:
	var network: Network = MAIN_SCENE.instantiate().get_node("Network")
	var game := network.get_parent()
	game.configure_network_from_command_line = false
	network.role = role
	network.address = address
	network.match_code = code
	_menu.show_busy(Texts.format(&"NET_CONNECTING", [address, network.port])
		if role == Network.Role.CLIENT else Texts.get_text(&"MENU_STARTING"))
	_start_game(game)


## Põe o jogo na árvore (sem `game`: configurado pela linha de comando). Ao lado desta cena,
## não dentro: as mensagens de rede apontam nós pelo caminho ("Main/PlayerState"), que
## precisa ser o mesmo no host e nos clientes, venham da tela ou da linha de comando.
func _start_game(game: Node) -> void:
	_game = game if game else MAIN_SCENE.instantiate()
	_game.match_started.connect(_on_match_started)
	_game.match_ended.connect(_on_match_ended)
	get_parent().add_child.call_deferred(_game)  # no _ready a raiz ainda monta os filhos


func _on_match_started() -> void:
	if _menu:
		_menu.queue_free()
		_menu = null


## O jogo sai da árvore depois do quadro (o aviso veio de dentro dele) e a tela volta.
func _on_match_ended(reason: String) -> void:
	if _game == null:
		return
	_game.name = "Closed"  # libera o nome "Main" já para a próxima partida
	_game.queue_free()
	_game = null
	_show_menu(reason)
