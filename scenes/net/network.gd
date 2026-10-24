class_name Network
extends Node
## Liga a sessão à rede (ADR-012). Sem argumentos, o jogo roda OFFLINE: host com 1
## jogador e nenhuma porta aberta.
##
## Argumentos de linha de comando (depois de `--`):
##   --host            hospeda só para este computador (127.0.0.1): testes locais.
##   --host-lan        hospeda para a rede local (abre a porta UDP para a LAN) e mostra o
##                     código da partida (MatchCode), sorteado a cada vez.
##   --join=<ip>       entra na partida de um host (só endereço IP).
##   --code=<código>   código da partida do host (cliente); no host, fixa o código.
##   --port=<n>        porta UDP (padrão NetRules.DEFAULT_PORT).
##
## Segurança (ADR-013): aperto de mão com identificação e versão do protocolo (quem não
## responde certo é desconectado), sem repasse direto entre clientes (tudo passa pelo host,
## que valida), sem decodificação de objetos, limite de jogadores e de tamanho de pacote.
## Aperto de mão: o host manda identificação + desafio; o cliente responde identificação +
## segredo do perfil (PlayerProfile; o resumo é a chave do personagem no save do host,
## ADR-019) + prova do código da partida. Código errado, mesma chave duas vezes ou endereço
## bloqueado por erros seguidos: recusado. O host diz o motivo antes de desconectar (o
## cliente só compara com as recusas conhecidas, byte a byte, para mostrar o aviso).

signal player_joined(player_id: int)
signal player_left(player_id: int)

enum Role { OFFLINE, HOST, HOST_LAN, CLIENT }

const LOOPBACK := "127.0.0.1"
## Chave do personagem de quem hospeda (ou joga sozinho) no save do próprio mundo.
const HOST_KEY := "host"
## Motivos de recusa que o host avisa ao cliente -> texto mostrado ao jogador.
const REFUSALS: Dictionary[String, StringName] = {
	"refused:version": &"NET_REFUSED_VERSION",
	"refused:code": &"NET_REFUSED_CODE",
	"refused:locked": &"NET_REFUSED_LOCKED",
	"refused:same-player": &"NET_REFUSED_SAME_PLAYER",
}
## Host aceitou: só então o cliente conclui (antes disso ele não manda nada do jogo).
const ACCEPTED := "accepted"
## Tempo entre avisar a recusa e desconectar, para o aviso chegar antes da queda (s).
const REFUSAL_GRACE := 0.25

var role := Role.OFFLINE
var address := LOOPBACK
var port := NetRules.DEFAULT_PORT
## Código da partida (MatchCode). Host na rede local sem código fixado: sorteado no start().
var match_code := ""

var _status := ""
var _refused := false  # cliente: o host disse por que recusou; mantém esse aviso
var _local_id := 1
var _hello := ("%s:%d" % [NetRules.PROTOCOL_ID, NetRules.PROTOCOL_VERSION]).to_utf8_buffer()
var _keys: Dictionary[int, String] = {}  # host: peer -> chave do personagem
var _challenges: Dictionary[int, PackedByteArray] = {}  # host: peer -> desafio enviado
var _refusing: Dictionary[int, bool] = {}  # host: avisados, à espera da desconexão
var _failures: Dictionary[String, int] = {}  # host: endereço -> códigos errados seguidos
var _locked_until: Dictionary[String, float] = {}  # host: endereço -> fim do bloqueio


func configure_from_command_line(args: PackedStringArray) -> void:
	for arg in args:
		if arg == "--host":
			role = Role.HOST
		elif arg == "--host-lan":
			role = Role.HOST_LAN
		elif arg.begins_with("--join="):
			role = Role.CLIENT
			address = arg.trim_prefix("--join=")
		elif arg.begins_with("--code="):
			match_code = MatchCode.normalize(arg.trim_prefix("--code="))
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
	elif role == Role.HOST:
		peer.set_bind_ip(LOOPBACK)
		error = peer.create_server(port, NetRules.MAX_CLIENTS)
		_status = Texts.format(&"NET_HOSTING_LOCAL", [port])
	else:
		peer.set_bind_ip("*")
		error = peer.create_server(port, NetRules.MAX_CLIENTS)
		if match_code.is_empty():
			match_code = MatchCode.generate()
		var addresses := ", ".join(lan_addresses())
		_status = Texts.format(&"NET_HOSTING_LAN", [addresses, port, match_code])
		print("[net] rede local: %s, porta %d, código %s" % [addresses, port, match_code])
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


## Endereços IPv4 de rede local deste computador, para quem vai entrar digitar.
static func lan_addresses() -> PackedStringArray:
	var found := PackedStringArray()
	for ip in IP.get_local_addresses():
		var parts := ip.split(".")
		if parts.size() != 4 or not ip.is_valid_ip_address():
			continue
		var second := parts[1].to_int()
		if parts[0] == "10" or (parts[0] == "192" and parts[1] == "168") \
				or (parts[0] == "172" and second >= 16 and second <= 31):
			found.append(ip)
	return found


func is_online() -> bool:
	return NetRules.is_online(multiplayer)


## ID deste computador na partida (= ID do jogador local). Offline e no host: 1.
func local_player_id() -> int:
	return _local_id


## Host: chave do personagem do jogador no save do mundo ("" se desconhecido).
func player_key(player_id: int) -> String:
	if player_id == _local_id:
		return HOST_KEY
	return _keys.get(player_id, "")


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


## Só o host começa: o cliente espera o desafio para responder.
func _on_peer_authenticating(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _locked_until.get(_address_of(peer_id), 0.0) > NetRules.now():
		_refuse(peer_id, "refused:locked")
		return
	_challenges[peer_id] = MatchCode.new_challenge()
	(multiplayer as SceneMultiplayer).send_auth(peer_id, _hello + _challenges[peer_id])


## Os dois lados conferem a identificação do outro byte a byte (nada é interpretado) e o
## tamanho exato de cada parte.
func _on_auth_data(peer_id: int, data: PackedByteArray) -> void:
	if multiplayer.is_server():
		if not _refusing.has(peer_id):
			_check_client_answer(peer_id, data)
	else:
		_answer_host(peer_id, data)


func _answer_host(peer_id: int, data: PackedByteArray) -> void:
	var api := multiplayer as SceneMultiplayer
	if data == ACCEPTED.to_utf8_buffer():
		api.complete_auth(peer_id)
		return
	for refusal in REFUSALS:
		if data == refusal.to_utf8_buffer():
			_refused = true
			_status = Texts.get_text(REFUSALS[refusal])
			return
	if data.size() != _hello.size() + MatchCode.CHALLENGE_SIZE \
			or data.slice(0, _hello.size()) != _hello:
		_refused = true
		_status = Texts.get_text(&"NET_REFUSED_VERSION")
		api.disconnect_peer(peer_id)
		return
	var challenge := data.slice(_hello.size())
	api.send_auth(peer_id, _hello + PlayerProfile.token() + MatchCode.proof(match_code, challenge))


## Host: identificação, segredo do perfil e prova do código; guarda só o resumo do segredo.
func _check_client_answer(peer_id: int, data: PackedByteArray) -> void:
	var token_end := _hello.size() + PlayerProfile.TOKEN_SIZE
	if not _challenges.has(peer_id) or data.size() != token_end + MatchCode.PROOF_SIZE \
			or data.slice(0, _hello.size()) != _hello:
		_refuse(peer_id, "refused:version")
		return
	var address_key := _address_of(peer_id)
	if not MatchCode.is_valid_proof(match_code, _challenges[peer_id], data.slice(token_end)):
		_failures[address_key] = _failures.get(address_key, 0) + 1
		if _failures[address_key] >= MatchCode.MAX_FAILURES:
			_failures.erase(address_key)
			_locked_until[address_key] = NetRules.now() + MatchCode.LOCKOUT_SECONDS
		_refuse(peer_id, "refused:code")
		return
	_failures.erase(address_key)
	var key := PlayerProfile.key_of(data.slice(_hello.size(), token_end))
	if _keys.values().has(key):
		_refuse(peer_id, "refused:same-player")
		return
	_challenges.erase(peer_id)
	_keys[peer_id] = key
	var api := multiplayer as SceneMultiplayer
	api.send_auth(peer_id, ACCEPTED.to_utf8_buffer())
	api.complete_auth(peer_id)


## Host: avisa o motivo (um dos REFUSALS) e desconecta logo depois; o que o recusado mandar
## nesse meio-tempo é ignorado.
func _refuse(peer_id: int, refusal: String) -> void:
	print("[net] peer %d recusado: %s" % [peer_id, refusal])
	(multiplayer as SceneMultiplayer).send_auth(peer_id, refusal.to_utf8_buffer())
	_challenges.erase(peer_id)
	_refusing[peer_id] = true
	get_tree().create_timer(REFUSAL_GRACE).timeout.connect(_drop_refused.bind(peer_id))


func _drop_refused(peer_id: int) -> void:
	if _refusing.has(peer_id):  # pode já ter caído sozinho
		_refusing.erase(peer_id)
		(multiplayer as SceneMultiplayer).disconnect_peer(peer_id)


func _address_of(peer_id: int) -> String:
	var packet_peer := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer_id)
	return packet_peer.get_remote_address() if packet_peer != null else ""


func _on_peer_authentication_failed(peer_id: int) -> void:
	_keys.erase(peer_id)
	_challenges.erase(peer_id)
	_refusing.erase(peer_id)
	print("[net] peer %d não concluiu o aperto de mão" % peer_id)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		print("[net] jogador %d entrou" % peer_id)
		player_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		print("[net] jogador %d saiu" % peer_id)
		player_left.emit(peer_id)  # antes de esquecer a chave: o save guarda o personagem
		_keys.erase(peer_id)


func _set_status(key: StringName) -> void:
	if not _refused:  # a queda que segue uma recusa não apaga o motivo
		_status = Texts.get_text(key)


func _fail(error: Error, message: String) -> Error:
	_status = message
	push_warning("[net] %s" % message)
	return error


func _exit_tree() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
