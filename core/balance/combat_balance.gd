class_name CombatBalance
extends Resource
## Números das fórmulas de combate (ver `CombatRules`). Valores em `data/balance/combat.tres`.

const DEFAULT_PATH := "res://data/balance/combat.tres"

## Defesa que corta METADE do dano (retorno decrescente: o dobro dela corta 2/3, nunca tudo).
## Pequeno o bastante para itens com poucos pontos de defesa fazerem diferença visível.
@export var defense_for_half_damage: float = 20.0

static var _default: CombatBalance


static func get_default() -> CombatBalance:
	if _default == null:
		_default = load(DEFAULT_PATH)
	return _default
