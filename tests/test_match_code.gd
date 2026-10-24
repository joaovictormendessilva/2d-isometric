extends TestCase
## Código da partida e criptografia (Etapa I1/I2, ADR-013): o host se prova pela porta da
## frente (certificado selado com o código), tudo trafega criptografado, só entra quem sabe o
## código, ele nunca trafega, e quem erra demais espera. Na rede, o host só deste computador
## (127.0.0.1) com código fixado faz o papel do host da rede local (mesmo caminho, sem abrir
## porta para a LAN).

const PORT := 24720
const CODE := "K7MQ4PXA"


func test_generated_codes_use_the_alphabet() -> void:
	var seen := {}
	for i in 50:
		var code := MatchCode.generate()
		seen[code] = true
		check(code.length() == MatchCode.LENGTH, "código com %d letras (%s)" % [MatchCode.LENGTH, code])
		for letter in code:
			check(MatchCode.ALPHABET.contains(letter), "letra %s do alfabeto sem confusões" % letter)
	check(seen.size() == 50, "códigos sorteados não se repetem")


func test_typing_is_forgiving() -> void:
	check(MatchCode.normalize(" k7mq-4pxa ") == CODE, "minúsculas, espaços e hífen aceitos")


func test_proof_depends_on_code_and_challenge() -> void:
	var challenge := MatchCode.new_challenge()
	var proof := MatchCode.proof(CODE, challenge)
	check(proof.size() == MatchCode.PROOF_SIZE, "prova com tamanho fixo")
	check(MatchCode.is_valid_proof("k7mq 4pxa", challenge, proof), "mesmo código digitado diferente vale")
	check(not MatchCode.is_valid_proof("K7MQ4PXB", challenge, proof), "outro código não vale")
	check(not MatchCode.is_valid_proof(CODE, MatchCode.new_challenge(), proof),
		"prova copiada não vale para outro desafio")


func test_door_request_is_strict_and_larger_than_the_answer() -> void:
	var challenge := MatchCode.new_challenge()
	var request := DoorProtocol.request(challenge)
	check(DoorProtocol.challenge_of(request) == challenge, "pedido válido devolve o desafio")
	check(DoorProtocol.challenge_of(request.slice(0, 100)).is_empty(), "pedido curto ignorado")
	var other := request.duplicate()
	other[0] = 0
	check(DoorProtocol.challenge_of(other).is_empty(), "pedido de outro jogo ignorado")
	var identity := HostIdentity.shared()
	var answer := DoorProtocol.response(MatchCode.door_key(CODE, identity.certificate_pem),
		challenge, identity.certificate_pem)
	check(answer.size() < request.size(),
		"resposta (%d B) menor que o pedido (%d B): a porta não multiplica tráfego"
		% [answer.size(), request.size()])


func test_door_answer_opens_only_with_the_right_code() -> void:
	var identity := HostIdentity.shared()
	var challenge := MatchCode.new_challenge()
	var answer := DoorProtocol.response(MatchCode.door_key(CODE, identity.certificate_pem),
		challenge, identity.certificate_pem)
	var opened := DoorProtocol.open_response("k7mq-4pxa", challenge, answer)
	check(opened != null and opened.save_to_string() == identity.certificate.save_to_string(),
		"código certo: o certificado do host")
	check(DoorProtocol.open_response("K7MQ4PXB", challenge, answer) == null, "código errado: nada")
	check(DoorProtocol.open_response(CODE, MatchCode.new_challenge(), answer) == null,
		"resposta de outro pedido (repetida): nada")
	var tampered := answer.duplicate()
	tampered[tampered.size() - 40] ^= 1
	check(DoorProtocol.open_response(CODE, challenge, tampered) == null, "certificado trocado: nada")


func test_right_code_joins_encrypted() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT, "", false, CODE)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT, "", false, "k7mq-4pxa")
	check(await wait_until(func() -> bool: return _joined(client)), "com o código certo, entra")
	check((host.session as GameSession).get_player_count() == 2, "host tem 2 jogadores")


func test_wrong_or_missing_code_stops_at_the_door() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT, "", false, CODE)
	for typed in ["", "K7MQ4PXB"]:
		var client := start_network_game("Client", Network.Role.CLIENT, PORT, "", false, typed)
		check(await wait_until(func() -> bool: return _status(client) == Texts.get_text(&"NET_REFUSED_CODE")),
			"código \"%s\": vê o motivo (\"%s\")" % [typed, _status(client)])
		check(not NetRules.is_online(client.multiplayer), "e nem chega a conectar")
		client.get_parent().free()
	check((host.session as GameSession).get_player_count() == 1, "host não aceitou ninguém")


## Quem pula a conferência da porta (outro programa) ainda precisa provar o código ao host.
func test_too_many_wrong_proofs_lock_the_address() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT, "", false, CODE)
	for i in MatchCode.MAX_FAILURES:
		var guesser := await _past_the_door("Guess%d" % i)
		guesser.network.match_code = "AAAAAAAA"  # prova errada dentro da conexão
		check(await wait_until(func() -> bool: return _status(guesser) == Texts.get_text(&"NET_REFUSED_CODE")),
			"prova errada recusada (\"%s\")" % _status(guesser))
		guesser.get_parent().free()
	var client := start_network_game("Client", Network.Role.CLIENT, PORT, "", false, CODE)
	check(await wait_until(func() -> bool: return _status(client) == Texts.get_text(&"NET_REFUSED_LOCKED")),
		"bloqueado: nem o código certo entra (\"%s\")" % _status(client))
	check(not _joined(client), "e não recebe o mundo")
	client.get_parent().free()
	var network := host.network as Network
	for address in network._locked_until:
		network._locked_until[address] = NetRules.now()  # o minuto passou
	client = start_network_game("Client2", Network.Role.CLIENT, PORT, "", false, CODE)
	check(await wait_until(func() -> bool: return _joined(client)), "depois do bloqueio, entra")


func test_unencrypted_client_never_connects() -> void:
	expect_errors("TLS handshake error")  # o host reclama do lixo e descarta
	var host := start_network_game("Host", Network.Role.HOST, PORT, "", false, CODE)
	var plain := ENetMultiplayerPeer.new()
	plain.create_client(Network.LOOPBACK, PORT)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1500:
		plain.poll()
		await tree.physics_frame
	check(plain.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED,
		"conexão sem criptografia não é aceita")
	plain.close()
	check((host.session as GameSession).get_player_count() == 1, "host segue sozinho")


func test_missing_host_is_reported() -> void:
	var client := start_network_game("Client", Network.Role.CLIENT, PORT, "", false, CODE)
	check(await wait_until(func() -> bool: return _status(client) == Texts.get_text(&"NET_HOST_NOT_FOUND"),
			60 * int(NetRules.DOOR_TIMEOUT + 1)),
		"sem host: avisa (\"%s\")" % _status(client))
	check(not _joined(client), "e não cria mundo próprio")


## Cliente com o código certo, já com a conexão criptografada aberta (porta da frente vencida),
## antes de o host mandar o desafio.
func _past_the_door(instance_name: String) -> Node:
	var game := start_network_game(instance_name, Network.Role.CLIENT, PORT, "", false, CODE)
	await wait_until(func() -> bool: return NetRules.is_online(game.multiplayer))
	return game


func _status(game: Node) -> String:
	return (game.network as Network).status_text()


func _joined(game: Node) -> bool:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) != null
