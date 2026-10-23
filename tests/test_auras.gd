extends TestCase
## Auras (G3b, ADR-029): só aparência, ligadas ao equipamento vestido. A Coroa do Rei Slime acende a
## primeira; vestir mostra, tirar apaga (e devolve as partículas); no coop todos veem a aura de
## todos, pelo equipamento que o host já envia.

const PORT := 24790


func test_crown_has_an_aura() -> void:
	var crown := ItemDatabase.load_all().get_item(&"king_slime_crown") as EquipmentData
	check(crown != null and crown.aura != null, "a coroa tem aura")
	var aura := crown.aura
	check(aura.radius >= 8.0 and aura.rune_count > 0 and aura.sparkle_amount > 0,
		"anel, runas e faíscas")
	check(aura.sparkle_amount <= VfxQuality.shared().level().particle_budget, "cabe no teto")


## Desempenho (G3d): o anel é pintado uma vez por passo e dividido por todos com a mesma aura.
func test_actors_with_the_same_aura_share_one_image() -> void:
	var aura := (ItemDatabase.load_all().get_item(&"king_slime_crown") as EquipmentData).aura
	var back := AuraRingImage.shared(aura, AuraRing.Half.BACK)
	check(back == AuraRingImage.shared(aura, AuraRing.Half.BACK), "mesma aura, mesma imagem")
	check(back != AuraRingImage.shared(aura, AuraRing.Half.FRONT), "cada metade tem a sua")
	back.show_step(0)
	var image := back.image
	check(image.get_pixelv(back.offset + Vector2i(0, -1)).a > 0.0, "a luz do chão aparece atrás")
	check(image.get_used_rect().size.x > aura.radius, "o anel foi pintado")


func test_wearing_shows_and_removing_hides() -> void:
	var game := start_game()
	calm_monsters(game)
	var session := game.session as GameSession
	var player := session.get_player_entity(1) as Character
	var vfx := player.get_node("Visual/AuraVfx") as AuraVfx
	await physics_frames(1)  # a metade da frente entra depois do sprite
	var front := player.get_node("Visual/AuraFront")
	check(vfx.aura_count() == 0 and front.get_child_count() == 0, "sem coroa, sem aura")
	var visual := player.get_node("Visual")
	check(vfx.get_index() < visual.get_node("Body").get_index()
		and front.get_index() > visual.get_node("Body").get_index(),
		"metade de trás antes do corpo, metade da frente depois")

	var particles_before := VfxQuality.shared().in_use()
	var equipment := session.get_equipment(1)
	var crown := equipment.data_of(&"king_slime_crown")
	check(EquipmentRules.give_equipped(equipment, crown), "vestiu a coroa")
	check(player.auras == [crown.aura], "o personagem sabe da aura")
	check(vfx.aura_count() == 1 and front.get_child_count() == 2, "anel atrás; anel e faíscas na frente")
	check(VfxQuality.shared().in_use() > particles_before, "as faíscas contam no teto")
	await physics_frames(2)

	equipment.replicate_slot(equipment.index_of_type(EquipmentData.Slot.HEAD), Equipment.EMPTY)
	check(player.auras.is_empty() and vfx.aura_count() == 0 and front.get_child_count() == 0,
		"tirou: a aura apaga")
	check(VfxQuality.shared().in_use() == particles_before, "e devolve as partículas")


## Coop: o host veste a coroa no personagem do cliente; a aura aparece no cliente e no host.
func test_aura_is_seen_in_coop() -> void:
	var host := start_network_game("Host", Network.Role.HOST, PORT)
	var client := start_network_game("Client", Network.Role.CLIENT, PORT)
	var connected := await wait_until(func() -> bool:
		return (client.session as GameSession).get_player_entity(client.local_player_id()) != null)
	check(connected, "cliente conectou")
	calm_monsters(host)
	await physics_frames(10)
	var client_id: int = client.local_player_id()
	var equipment := (host.session as GameSession).get_equipment(client_id)
	EquipmentRules.give_equipped(equipment, equipment.data_of(&"king_slime_crown"))
	var on_host := (host.session as GameSession).get_player_entity(client_id) as Character
	var on_client := (client.session as GameSession).get_player_entity(client_id) as Character
	check((on_host.get_node("Visual/AuraVfx") as AuraVfx).aura_count() == 1, "o host vê")
	check(await wait_until(func() -> bool:
		return (on_client.get_node("Visual/AuraVfx") as AuraVfx).aura_count() == 1, 30),
		"o cliente vê a própria aura")
