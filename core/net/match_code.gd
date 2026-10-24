class_name MatchCode
extends RefCounted
## Código da partida (Etapa I, ADR-013): quem hospeda na rede local mostra um código curto, e
## só entra quem o digitar. O código NUNCA trafega. Ele serve duas vezes:
## - o host sela o próprio certificado com ele (DoorProtocol): o cliente só confia no host
##   que conhece o código;
## - já na conexão criptografada, o host manda um desafio e o cliente responde com o resumo
##   (HMAC-SHA256) do desafio usando o código como chave: o host só aceita quem o conhece.
## O selo da porta da frente é público (qualquer um pode pedir); quem o tiver pode testar
## códigos no próprio computador. Por isso 8 letras (31^8 ≈ 850 bilhões) e uma chave lenta
## (DOOR_KEY_ROUNDS resumos por tentativa): adivinhar levaria meses numa placa de vídeo, e o
## código muda a cada vez que se hospeda.

## Sem letras que se confundem ao ditar ou digitar (0/O, 1/I/L).
const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const LENGTH := 8
const CHALLENGE_SIZE := 16
const PROOF_SIZE := 32
## ~70 ms neste PC; o host calcula uma vez ao abrir, o cliente uma vez por tentativa.
const DOOR_KEY_ROUNDS := 65536
## Erros seguidos de um mesmo endereço antes do bloqueio, e quanto dura o bloqueio (s).
const MAX_FAILURES := 5
const LOCKOUT_SECONDS := 60.0
## Separam o uso de cada chave de qualquer outro resumo do jogo.
const KEY_CONTEXT := "2d-isometric/match-code:"
const DOOR_KEY_CONTEXT := "2d-isometric/door-key:"


static func generate() -> String:
	var crypto := Crypto.new()
	var code := ""
	while code.length() < LENGTH:
		# Rejeita os bytes da "sobra" para cada letra sair com a mesma chance.
		for byte in crypto.generate_random_bytes(LENGTH):
			if byte < 256 - 256 % ALPHABET.length() and code.length() < LENGTH:
				code += ALPHABET[byte % ALPHABET.length()]
	return code


## O que a pessoa digitou, sem espaços nem hífens e em maiúsculas. Vazio = sem código
## (host só deste computador).
static func normalize(typed: String) -> String:
	return typed.strip_edges().replace(" ", "").replace("-", "").to_upper()


## Como mostrar na tela: em dois blocos, fácil de ditar ("K7MQ-4PXA").
static func display(code: String) -> String:
	var half := code.length() / 2
	return code if code.length() < 2 else "%s-%s" % [code.left(half), code.substr(half)]


## Chave do selo da porta da frente: resumo repetido do código, "salgado" com o certificado do
## host (que é novo a cada vez), para nenhuma tabela pronta servir.
static func door_key(code: String, salt: PackedByteArray) -> PackedByteArray:
	var key := (DOOR_KEY_CONTEXT + normalize(code)).to_utf8_buffer() + salt
	var hashing := HashingContext.new()
	for i in DOOR_KEY_ROUNDS:
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(key)
		key = hashing.finish()
	return key


static func new_challenge() -> PackedByteArray:
	return Crypto.new().generate_random_bytes(CHALLENGE_SIZE)


static func proof(code: String, challenge: PackedByteArray) -> PackedByteArray:
	var key := (KEY_CONTEXT + normalize(code)).sha256_buffer()
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, key, challenge)


static func is_valid_proof(code: String, challenge: PackedByteArray,
		received: PackedByteArray) -> bool:
	return received.size() == PROOF_SIZE \
		and Crypto.new().constant_time_compare(proof(code, challenge), received)
