class_name HostDoor
extends RefCounted
## Host: atende a porta da frente (DoorProtocol) por UDP: a cada pedido válido, responde com o
## certificado selado. Não guarda estado de ninguém além do horário da última resposta por
## endereço (no máximo uma a cada MIN_INTERVAL), e lê um número limitado de pedidos por quadro.

const MIN_INTERVAL := 0.1
const MAX_PER_POLL := 32
const MAX_TRACKED := 64

var _socket := PacketPeerUDP.new()
var _door_key: PackedByteArray
var _certificate_pem: PackedByteArray
var _last_answer: Dictionary[String, float] = {}


func open(bind_ip: String, port: int, door_key: PackedByteArray,
		certificate_pem: PackedByteArray) -> Error:
	_door_key = door_key
	_certificate_pem = certificate_pem
	return _socket.bind(port, bind_ip)


## `now`: relógio do host (NetRules.now()).
func poll(now: float) -> void:
	for i in MAX_PER_POLL:
		if _socket.get_available_packet_count() == 0:
			return
		var challenge := DoorProtocol.challenge_of(_socket.get_packet())
		var address := _socket.get_packet_ip()
		if challenge.is_empty() or now - _last_answer.get(address, -INF) < MIN_INTERVAL:
			continue
		if _last_answer.size() >= MAX_TRACKED:
			_last_answer.clear()  # só limita a frequência; esquecer não abre nada
		_last_answer[address] = now
		_socket.set_dest_address(address, _socket.get_packet_port())
		_socket.put_packet(DoorProtocol.response(_door_key, challenge, _certificate_pem))


func close() -> void:
	_socket.close()
