extends TestCase
## Ferramentas de teste do João: mercador de testes (todos os itens e receitas por 0, só em
## desenvolvimento) e a linha de velocidade e efeitos do painel F3.


## Ao lado do mercador da campina; vende tudo e ensina toda receita que se aprende, por 0.
func test_dev_merchant_sells_everything_for_free() -> void:
	var game := start_game()
	calm_monsters(game)
	var region: Region = game.region
	DevMerchant.add_to(region, game.items, game.recipes)
	var dev := region.entities.get_node("DevMerchant") as Npc
	check(dev != null, "mercador de testes na campina")
	for item in (game.items as ItemDatabase).entries():
		check(dev.data.sells(item.id) and dev.data.price_of(item.id) == 0,
			"vende %s por 0" % item.id)
	check(dev.data.teaches(&"health_potion") and dev.data.recipe_price(&"health_potion") == 0,
		"ensina a receita da poção por 0")
	var merchant := load("res://data/npcs/merchant.tres") as NpcData
	check(merchant.price_of(&"health_potion") > 0, "o mercador de verdade continua cobrando")

	# Compra de verdade, decidida pelo host: o jogador ao lado dele, sem moedas.
	var session := game.session as GameSession
	var player := session.get_player_entity(1) as Character
	player.position = dev.position + Iso.ground_to_screen(Vector2(-16, 0))
	player.reset_physics_interpolation()
	await physics_frames(2)
	var state: PlayerStateSync = game.player_state
	check(state.npc_near(1) == dev, "o mais perto é o mercador de testes")
	state.request_buy(&"king_slime_crown")
	check(session.get_inventory(1).count(&"king_slime_crown") == 1, "comprou a coroa de graça")


func test_dev_merchant_needs_the_setting() -> void:
	check(DevMerchant.is_enabled() == (OS.is_debug_build()
		and ProjectSettings.get_setting("game/debug/dev_merchant", false)),
		"liga só em desenvolvimento e com a chave do project.godot")


## Painel F3: velocidade base e atual e os efeitos ativos com os segundos.
func test_debug_overlay_shows_speed_and_effects() -> void:
	var game := start_game()
	calm_monsters(game)
	var player := (game.session as GameSession).get_player_entity(1) as Character
	var overlay: DebugOverlay = game.find_children("*", "DebugOverlay", true, false)[0]
	check(overlay._stats_line(player).contains("nenhum"), "sem efeitos")
	player.status_effects.apply(EffectDatabase.shared().get_effect(&"swiftness"))
	var line := overlay._stats_line(player)
	check(line.contains("swiftness") and line.contains("-> %d" % int(player.move_speed())),
		"mostra a rapidez e a velocidade nova (%s)" % line)
