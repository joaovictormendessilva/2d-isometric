class_name Network
extends Node
## Liga a sessão à rede (ADR-012). Sem argumentos, o jogo roda OFFLINE: host com 1
## jogador e nenhuma porta aberta.
##
## Argumentos de linha de comando (depois de `--`):
##   --host            hospeda só para este computador (127.0.0.1): testes locais.
##   --host-lan        hospeda para a rede local (abre a porta UDP para a LAN).
##   --join=<ip>       entra na partida de um host (só endereço IP).
##   --port=<n>        porta UDP (padrão NetRules.DEFAULT_PORT).
##
## Segurança (ADR-013): aperto de mão com identificação e versão do protocolo (quem não
## responde certo é desconectado), sem repasse direto entre clientes (tudo passa pelo host,
## que valida), sem decodificação de objetos, limite de jogadores e de tamanho de pacote.

signal player_joined(player_id: int)
signal player_left(player_id: int)

enum Role { OFFLINE, HOST, HOST_LAN, CLIENT }

const LOOPBACK := "127.0.0.1"

var role := Role.OFFLINE
var address := LOOPBACK
var port := NetRules.DEFAULT_PORT

var _status := ""
var _local_id := 1
var _hello := ("%s:%d" % [NetRules.PROTOCOL_ID, NetRules.PROTOCOL_VERSION]).to_utf8_buffer()


func configure_from_command_line(args: PackedStringArray) -> void:
	for arg in args:
		if arg == "--host":
			role = Role.HOST
		elif arg == "--host-lan":
			role = Role.HOST_LAN
		elif arg.begins_with("--join="):
			role = Role.CLIENT
			address = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()


## Abre a conexão conforme `role`. Retorna OK ou o erro (porta em uso, IP inválido...).
func start() -> Error:
	if role == Role.OFFLINE:
		return OK
	if port < 1024 or port > 65535:
		return _fail(ERR_INVALID_PARAMETER, Texts.format(&"NET_BAD_PORT", [port]))
	var api := multiplayer as SceneMultiplayer
	api.server_relay = false  # clientes não falam entre si: o host valida e repassa
	api.allow_object_decoding = false
	api.max_sync_packet_size = NetRules.MAX_PACKET_SIZE
	api.max_delta_packet_size = NetRules.MAX_PACKET_SIZE
	api.auth_timeout = NetRules.AUTH_TIMEOUT
	api.auth_callback = _on_auth_data
	api.peer_authenticating.connect(_on_peer_authenticating)
	api.peer_authentication_failed.connect(_on_peer_authentication_failed)

	var peer := ENetMultiplayerPeer.new()
	var error: Error
	if role == Role.CLIENT:
		if not address.is_valid_ip_address():
			return _fail(ERR_INVALID_PARAMETER, Texts.format(&"NET_BAD_ADDRESS", [address]))
		error = peer.create_client(address, port)
		_status = Texts.format(&"NET_CONNECTING", [address, port])
	else:
		peer.set_bind_ip(LOOPBACK if role == Role.HOST else "*")
		error = peer.create_server(port, NetRules.MAX_CLIENTS)
		var hosting := &"NET_HOSTING_LOCAL" if role == Role.HOST else &"NET_HOSTING_LAN"
		_status = Texts.format(hosting, [port])
	if error != OK:
		return _fail(error, Texts.format(&"NET_OPEN_FAILED", [port]))
	multiplayer.multiplayer_peer = peer
	_local_id = multiplayer.get_unique_id()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_set_status.bind(&"NET_CONNECTED"))
	multiplayer.connection_failed.connect(_set_status.bind(&"NET_CONNECT_FAILED"))
	multiplayer.server_disconnected.connect(_set_status.bind(&"NET_HOST_LOST"))
	return OK


func is_online() -> bool:
	return NetRules.is_online(multiplayer)


## ID deste computador na partida (= ID do jogador local). Offline e no host: 1.
func local_player_id() -> int:
	return _local_id


## Texto curto para a interface; vazio offline.
func status_text() -> String:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not is_online() or enet.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return _status
	if multiplayer.is_server():
		return Texts.format(&"NET_PLAYERS", [_status, multiplayer.get_peers().size() + 1])
	var host := enet.get_peer(1)
	if host == null:
		return _status
	var ping := host.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	return Texts.format(&"NET_PING", [_status, ping])


func _on_peer_authenticating(peer_id: int) -> void:
	(multiplayer as SceneMultiplayer).send_auth(peer_id, _hello)


## Os dois lados conferem a identificação do outro byte a byte (nada é interpretado).
func _on_auth_data(peer_id: int, data: PackedByteArray) -> void:
	var api := multiplayer as SceneMultiplayer
	if data == _hello:
		api.complete_auth(peer_id)
	else:
		print("[net] peer %d recusado: versão ou jogo diferente" % peer_id)
		api.disconnect_peer(peer_id)


func _on_peer_authentication_failed(peer_id: int) -> void:
	print("[net] peer %d não concluiu o aperto de mão" % peer_id)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		print("[net] jogador %d entrou" % peer_id)
		player_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		print("[net] jogador %d saiu" % peer_id)
		player_left.emit(peer_id)


func _set_status(key: StringName) -> void:
	_status = Texts.get_text(key)


func _fail(error: Error, message: String) -> Error:
	_status = message
	push_warning("[net] %s" % message)
	return error


func _exit_tree() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
