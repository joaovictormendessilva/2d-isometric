class_name MatchCode
extends RefCounted
## Código da partida (Etapa I, ADR-013): quem hospeda na rede local mostra um código curto, e
## só entra quem o digitar. O código NUNCA trafega: o host manda um desafio aleatório e o
## cliente responde com o resumo (HMAC-SHA256) do desafio usando o código como chave. Quem
## escuta a rede não aprende o código, e uma resposta copiada não serve para outro desafio.

## Sem letras que se confundem ao ditar ou digitar (0/O, 1/I/L).
const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const LENGTH := 6
const CHALLENGE_SIZE := 16
const PROOF_SIZE := 32
## Erros seguidos de um mesmo endereço antes do bloqueio, e quanto dura o bloqueio (s):
## 5 tentativas por minuto tornam inviável adivinhar entre ~900 milhões de códigos.
const MAX_FAILURES := 5
const LOCKOUT_SECONDS := 60.0
## Separa o uso desta chave de qualquer outro resumo do jogo.
const KEY_CONTEXT := "2d-isometric/match-code:"


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


static func new_challenge() -> PackedByteArray:
	return Crypto.new().generate_random_bytes(CHALLENGE_SIZE)


static func proof(code: String, challenge: PackedByteArray) -> PackedByteArray:
	var key := (KEY_CONTEXT + normalize(code)).sha256_buffer()
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, key, challenge)


static func is_valid_proof(code: String, challenge: PackedByteArray,
		received: PackedByteArray) -> bool:
	return received.size() == PROOF_SIZE \
		and Crypto.new().constant_time_compare(proof(code, challenge), received)
