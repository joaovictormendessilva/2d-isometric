class_name HostIdentity
extends RefCounted
## Chave e certificado da conexão criptografada do host (DTLS, Etapa I2, ADR-013). Novos a
## cada execução do jogo (nada de chave privada guardada em disco); criar custa ~250 ms, uma
## vez só: hospedar de novo na mesma execução reaproveita.

## Nome no certificado; o cliente confere que é este.
const COMMON_NAME := "2d-isometric"
const KEY_BITS := 2048
## Validade: começa um dia antes (relógios desacertados) e dura bem mais que uma partida.
const VALID_DAYS := 30

static var _shared: HostIdentity

var key: CryptoKey
var certificate: X509Certificate
## Certificado em texto (PEM), como vai pela porta da frente.
var certificate_pem: PackedByteArray


static func shared() -> HostIdentity:
	if _shared == null:
		_shared = HostIdentity.new()
	return _shared


func _init() -> void:
	var crypto := Crypto.new()
	key = crypto.generate_rsa(KEY_BITS)
	var now := int(Time.get_unix_time_from_system())
	certificate = crypto.generate_self_signed_certificate(key,
		"CN=%s,O=%s,C=BR" % [COMMON_NAME, COMMON_NAME],
		_certificate_time(now - 86400), _certificate_time(now + VALID_DAYS * 86400))
	# O texto vem com o "\0" final da biblioteca de criptografia (já trocado por U+FFFD).
	certificate_pem = certificate.save_to_string().replace(String.chr(0xFFFD), "") \
		.strip_edges().to_ascii_buffer()


func server_options() -> TLSOptions:
	return TLSOptions.server(key, certificate)


## Formato das datas do certificado: AAAAMMDDhhmmss (UTC).
static func _certificate_time(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d%02d%02d%02d%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]
