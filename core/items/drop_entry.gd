class_name DropEntry
extends Resource
## Uma linha da tabela de drops de uma criatura. Sorteada por jogador (drop pessoal).

@export var item: ItemData
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_amount: int = 1
@export var max_amount: int = 1


## Quantidade sorteada (0 = não caiu).
func roll(rng: RandomNumberGenerator) -> int:
	if rng.randf() >= chance:
		return 0
	return rng.randi_range(min_amount, max_amount)
