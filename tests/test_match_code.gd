extends TestCase
## Código da partida (Etapa I1, ADR-013): só entra quem sabe o código, ele nunca trafega, e
## quem erra demais espera. Na rede, o host só deste computador (127.0.0.1) com código fixado
## faz o papel do host da rede local (mesmo aperto de mão, sem abrir porta para a LAN).

const PORT := 24720
const CODE := "K7MQ4P"


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
	check(MatchCode.normalize(" k7m-q4p ") == CODE, "minúsculas, espaços e hífen aceitos")


func test_proof_depends_on_code_and_challenge() -> void:
	var challenge := MatchCode.new_challenge()
	var proof := MatchCode.proof(CODE, challenge)
	check(proof.size() == MatchCode.PROOF_SIZE, "prova com tamanho fixo")
	check(MatchCode.is_valid_proof("k7m q4p", challenge, proof), "mesmo código digitado diferente vale")
	check(not MatchCode.is_valid_proof("K7MQ4R", challenge, proof), "outro código não vale")
	check(not MatchCode.is_valid_proof(CODE, MatchCode.new_challenge(), proof),
		"prova copiada não vale para outro desafio")


func test_right_code_joins() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT, "", false, CODE)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT, "", false, "k7m-q4p")
	check(await wait_until(func() -> bool: return _joined(client)), "com o código certo, entra")
	check((host.session as GameSession).get_player_count() == 2, "host tem 2 jogadores")


func test_wrong_or_missing_code_is_refused() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT, "", false, CODE)
	for typed in ["", "K7MQ4R"]:
		var client := start_network_game("Client", Network.Role.CLIENT, PORT, "", false, typed)
		await physics_frames(120)
		check(not _joined(client), "código \"%s\": não recebe o mundo" % typed)
		check((client.network as Network).status_text() == Texts.get_text(&"NET_REFUSED_CODE"),
			"e vê o motivo (\"%s\")" % (client.network as Network).status_text())
		client.get_parent().free()
	check((host.session as GameSession).get_player_count() == 1, "host não aceitou ninguém")


func test_too_many_wrong_codes_lock_the_address() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT, "", false, CODE)
	for i in MatchCode.MAX_FAILURES:
		var guesser := start_network_game("Guess%d" % i, Network.Role.CLIENT, PORT, "", false, "AAAAAA")
		await physics_frames(60)
		guesser.get_parent().free()
	var client := start_network_game("Client", Network.Role.CLIENT, PORT, "", false, CODE)
	await physics_frames(120)
	check(not _joined(client), "bloqueado: nem o código certo entra")
	check((client.network as Network).status_text() == Texts.get_text(&"NET_REFUSED_LOCKED"),
		"e vê o motivo (\"%s\")" % (client.network as Network).status_text())
	client.get_parent().free()
	var network := host.network as Network
	for address in network._locked_until:
		network._locked_until[address] = NetRules.now()  # o minuto passou
	client = start_network_game("Client2", Network.Role.CLIENT, PORT, "", false, CODE)
	check(await wait_until(func() -> bool: return _joined(client)), "depois do bloqueio, entra")


func _joined(game: Node) -> bool:
	return (game.session as GameSession).get_player_entity(game.local_player_id()) != null
