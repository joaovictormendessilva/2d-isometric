class_name DoorKnock
extends RefCounted
## Cliente: bate na porta da frente do host (DoorProtocol) e espera o certificado selado,
## repetindo o pedido de tempos em tempos (UDP pode perder pacotes). Só aceita resposta do
## endereço e porta pedidos.

enum Result { WAITING, OPENED, WRONG_CODE }

const RESEND_INTERVAL := 0.25

## Certificado do host, quando o resultado é OPENED.
var certificate: X509Certificate

var _socket := PacketPeerUDP.new()
var _code := ""
var _challenge := MatchCode.new_challenge()
var _resend_at := 0.0


func start(address: String, port: int, code: String) -> Error:
	_code = code
	return _socket.connect_to_host(address, port)


## `now`: relógio deste computador (NetRules.now()).
func poll(now: float) -> Result:
	if _socket.get_available_packet_count() > 0:
		certificate = DoorProtocol.open_response(_code, _challenge, _socket.get_packet())
		return Result.OPENED if certificate != null else Result.WRONG_CODE
	if now >= _resend_at:
		_resend_at = now + RESEND_INTERVAL
		_socket.put_packet(DoorProtocol.request(_challenge))
	return Result.WAITING


func close() -> void:
	_socket.close()
