class_name CombatRules
## Fórmulas de combate num lugar só. Números de balanceamento ficam em `data/`.


## Dano depois da defesa, com retorno decrescente: cada ponto de defesa vale menos que o
## anterior (100 de defesa = metade do dano; nunca chega a zero). Mínimo 1.
static func mitigate(amount: int, defense: int) -> int:
	return maxi(1, roundi(amount * 100.0 / (100.0 + maxf(defense, 0))))


## Multiplicador da vida das criaturas pelo número de jogadores na sessão.
static func monster_health_multiplier(player_count: int, scaling: PlayerScaling) -> float:
	return 1.0 + scaling.monster_health_per_extra_player * maxi(player_count - 1, 0)
