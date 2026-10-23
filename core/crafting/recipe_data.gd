class_name RecipeData
extends Resource
## Uma receita de fabricação (um arquivo por receita em `data/recipes/`): ingredientes que
## saem do inventário, o item que entra e onde ela pode ser feita (ADR-017).

## Onde a receita é feita. Na mão: em qualquer lugar. Bancada: perto de uma.
enum Station { HAND, WORKBENCH }

@export var id: StringName
@export var station: Station = Station.HAND
## Precisa ser aprendida antes (comprada de um NPC, ver `NpcData.recipe_offers` e RecipeBook)?
@export var must_learn := false
## Id do item → quantidade consumida.
@export var ingredients: Dictionary[StringName, int] = {}
@export var result: ItemData
@export var result_amount: int = 1


## O que a receita produz, no formato de `Inventory.can_exchange`.
func get_output() -> Dictionary[StringName, int]:
	return {result.id: result_amount}
