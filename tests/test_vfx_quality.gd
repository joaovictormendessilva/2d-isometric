extends TestCase
## Qualidade dos efeitos (G3a, ADR-028): cada nível corta as partículas pedidas, um teto soma as de
## todos os efeitos do computador, a escolha fica nas preferências e trocar refaz as partículas.


func test_levels_are_consistent() -> void:
	var levels: VfxQualityLevels = load(VfxQuality.DATA_PATH)
	check(levels.levels.size() == 3, "baixo, médio e alto")
	for index in range(1, levels.levels.size()):
		var lighter := levels.levels[index - 1]
		var richer := levels.levels[index]
		check(lighter.particle_scale <= richer.particle_scale
			and lighter.particle_budget <= richer.particle_budget,
			"%s não gasta mais que %s" % [lighter.id, richer.id])
	check(levels.levels[-1].particle_scale == 1.0, "o mais alto mostra tudo o que o dado pede")


func test_scaling_budget_and_preference() -> void:
	var quality := VfxQuality.shared()
	var original := quality.level_index()
	quality.set_level(0)
	check(quality.scaled(10) == roundi(10 * quality.level().particle_scale), "o baixo corta")
	check(quality.scaled(1) == 1 and quality.scaled(0) == 0, "pediu alguma: ganha pelo menos 1")
	check(UserSettings.get_value(VfxQuality.SETTINGS_SECTION, VfxQuality.SETTINGS_KEY, -1) == 0,
		"a escolha fica nas preferências")

	# Teto: enche o orçamento e o próximo emissor fica sem nada; ao sair da árvore, devolve.
	var before := quality.in_use()
	var budget := quality.level().particle_budget - before
	var holder := add_to_tree(Node2D.new())
	var big := CPUParticles2D.new()
	check(quality.claim(big, ceili(budget / quality.level().particle_scale) + 10), "o primeiro ganha")
	holder.add_child(big)
	check(big.amount == budget and quality.in_use() == before + budget, "cortado no teto (%d)" % big.amount)
	var late := CPUParticles2D.new()
	check(not quality.claim(late, 4), "teto cheio: o próximo fica sem partículas")
	late.free()
	holder.remove_child(big)
	check(quality.in_use() == before, "sair da árvore devolve")
	holder.add_child(big)
	check(quality.in_use() == before + budget, "voltar conta de novo")
	holder.queue_free()
	await physics_frames(1)
	check(quality.in_use() == before, "liberado")

	quality.apply_command_line(PackedStringArray(["--quality=medium"]))
	check(quality.level().id == &"medium", "--quality= escolhe o nível")
	check(UserSettings.get_value(VfxQuality.SETTINGS_SECTION, VfxQuality.SETTINGS_KEY, -1) == 0,
		"sem mexer na preferência gravada")
	quality.set_level(original)


## Trocar de nível com o efeito ativo refaz as partículas do ator com a nova quantidade, e a
## tecla do painel de debug só troca com ele aberto.
func test_changing_level_rebuilds_actor_particles() -> void:
	var quality := VfxQuality.shared()
	var original := quality.level_index()
	quality.set_level(2)
	var game := start_game()
	calm_monsters(game)
	var player := (game.session as GameSession).get_player_entity(1) as Character
	var vfx := player.get_node("Visual/EffectVfx") as StatusEffectVfx
	var poison := EffectDatabase.shared().get_effect(&"poison")
	player.status_effects.apply(poison)
	var emitter := vfx.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D)
	check(emitter.size() == 1 and emitter[0].amount == mini(poison.vfx_amount,
		StatusEffectVfx.MAX_PARTICLES), "alto: a quantidade do dado")

	var overlay: DebugOverlay = game.find_children("*", "DebugOverlay", true, false)[0]
	overlay.visible = false
	var press := InputEventAction.new()
	press.action = &"cycle_effects_quality"
	press.pressed = true
	overlay._unhandled_input(press)
	check(quality.level_index() == 2, "painel fechado: F4 não troca")
	overlay.visible = true
	overlay._unhandled_input(press)
	check(quality.level_index() == 0, "painel aberto: do alto volta ao baixo")
	await physics_frames(1)
	var rebuilt := vfx.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D)
	check(vfx.emitter_count() == 1 and rebuilt.size() == 1
		and rebuilt[0].amount == quality.scaled(poison.vfx_amount), "refeito com menos partículas")
	quality.set_level(original)
