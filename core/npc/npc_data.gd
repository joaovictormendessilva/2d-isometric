class_name NpcData
extends Resource
## Um NPC fixo do mundo (um arquivo por NPC em `data/npcs/`). Hoje: o mercador, que vende os
## itens de `offers`, ensina as receitas de `recipe_offers` e compra qualquer item com
## `ItemData.sell_price` (F3).

@export var id: StringName
## Id do item → preço em moedas de UMA unidade. Vazio = não vende nada.
@export var offers: Dictionary[StringName, int] = {}
## Id da receita (`must_learn`) → preço em moedas para aprendê-la (F3c). Vazio = não ensina.
@export var recipe_offers: Dictionary[StringName, int] = {}
## Compra itens do jogador (pelo `ItemData.sell_price` de cada um)?
@export var buys_items := true
## Distância (no chão) dos pés do jogador até o NPC para negociar.
@export var interact_range: float = 40.0
## Raio (no chão) da pegada: o NPC bloqueia a passagem como uma pedra.
@export var footprint_radius: float = 6.0
@export_group("Aparência")
@export var texture: Texture2D
## Desenho em relação aos pés (posição do NPC no chão).
@export var sprite_offset: Vector2


## Nome no idioma atual (chave `NPC_<ID>` em `data/i18n/texts.csv`).
func get_display_name() -> String:
	return Texts.name_of("NPC", id)


func sells(item_id: StringName) -> bool:
	return offers.has(item_id)


## Preço de uma unidade de `item_id`, ou 0 se não vende.
func price_of(item_id: StringName) -> int:
	return offers.get(item_id, 0)


func teaches(recipe_id: StringName) -> bool:
	return recipe_offers.has(recipe_id)


## Preço para aprender `recipe_id`, ou 0 se não ensina.
func recipe_price(recipe_id: StringName) -> int:
	return recipe_offers.get(recipe_id, 0)
