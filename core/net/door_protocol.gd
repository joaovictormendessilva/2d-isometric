class_name DoorProtocol
extends RefCounted
## "Porta da frente" do host (Etapa I2, ADR-013). A conexão do jogo é criptografada (DTLS) e,
## na Godot, o cliente só conecta se já tiver o certificado do host. Então, antes, ele pede o
## certificado por UDP na porta seguinte à do jogo; o host responde com o certificado e um
## selo (HMAC) feito com a chave do código da partida. Sem o código, ninguém no meio da rede
## consegue trocar o certificado por outro: o cliente confere o selo antes de confiar nele.
##
## Pedido:   PREFIXO + desafio do cliente (16 bytes) + zeros até REQUEST_SIZE.
## Resposta: PREFIXO + selo (32 bytes) + certificado (PEM).
## O pedido é maior que a resposta: ninguém usa a porta para multiplicar tráfego contra outro
## computador (pedido com remetente falso).

const REQUEST_SIZE := 1400
const MAX_CERTIFICATE_SIZE := 1300
const PREFIX := "%s:door:%d" % [NetRules.PROTOCOL_ID, NetRules.PROTOCOL_VERSION]


static func request(challenge: PackedByteArray) -> PackedByteArray:
	var bytes := PREFIX.to_utf8_buffer() + challenge
	bytes.resize(REQUEST_SIZE)  # completa com zeros
	return bytes


## Desafio contido num pedido; vazio se o pedido não é exatamente um pedido nosso.
static func challenge_of(bytes: PackedByteArray) -> PackedByteArray:
	var prefix := PREFIX.to_utf8_buffer()
	if bytes.size() != REQUEST_SIZE or bytes.slice(0, prefix.size()) != prefix:
		return PackedByteArray()
	return bytes.slice(prefix.size(), prefix.size() + MatchCode.CHALLENGE_SIZE)


static func response(door_key: PackedByteArray, challenge: PackedByteArray,
		certificate_pem: PackedByteArray) -> PackedByteArray:
	return PREFIX.to_utf8_buffer() + _seal(door_key, challenge, certificate_pem) + certificate_pem


## Certificado da resposta, se o selo confere com o código digitado; senão null (código
## errado, resposta adulterada ou de outro host).
static func open_response(code: String, challenge: PackedByteArray,
		bytes: PackedByteArray) -> X509Certificate:
	var prefix := PREFIX.to_utf8_buffer()
	var pem_start := prefix.size() + MatchCode.PROOF_SIZE
	if bytes.size() <= pem_start or bytes.size() > pem_start + MAX_CERTIFICATE_SIZE \
			or bytes.slice(0, prefix.size()) != prefix:
		return null
	var pem := bytes.slice(pem_start)
	var expected := _seal(MatchCode.door_key(code, pem), challenge, pem)
	if not Crypto.new().constant_time_compare(expected, bytes.slice(prefix.size(), pem_start)):
		return null
	var certificate := X509Certificate.new()
	return certificate if certificate.load_from_string(pem.get_string_from_ascii()) == OK else null


static func _seal(door_key: PackedByteArray, challenge: PackedByteArray,
		certificate_pem: PackedByteArray) -> PackedByteArray:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, door_key, challenge + certificate_pem)
