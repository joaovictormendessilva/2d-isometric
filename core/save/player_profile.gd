class_name PlayerProfile
extends RefCounted
## Identidade deste computador nos mundos dos outros (ADR-019): um segredo aleatório criado na
## primeira vez e guardado em `user://`. O cliente o envia no aperto de mão; o host guarda só o
## resumo (SHA-256) como chave do personagem. Quem não conhece o segredo não entra como outro
## jogador. (Na LAN ele trafega sem criptografia: risco registrado na ADR-013.)

const TOKEN_SIZE := 32

## Os testes trocam o arquivo, para não mexer na identidade de quem joga.
static var path := "user://profile.cfg"


static func token() -> PackedByteArray:
	var config := ConfigFile.new()
	config.load(path)  # sem arquivo ainda: começa vazio
	var saved: Variant = config.get_value("identity", "token", "")
	if saved is String and saved.length() == TOKEN_SIZE * 2 \
			and saved.hex_decode().hex_encode() == saved:
		return saved.hex_decode()
	var created := Crypto.new().generate_random_bytes(TOKEN_SIZE)
	config.set_value("identity", "token", created.hex_encode())
	config.save(path)
	return created


## Chave do personagem no save do host a partir do segredo recebido.
static func key_of(secret: PackedByteArray) -> String:
	return secret.hex_encode().sha256_text()
