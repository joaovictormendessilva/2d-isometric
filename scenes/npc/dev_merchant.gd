class_name DevMerchant
extends RefCounted
## Mercador de testes (pedido do João, 2026-10-23): vende TODOS os itens e ensina todas as receitas
## por 0 moedas, para testar sem farmar. Só em compilações de desenvolvimento e com
## `game/debug/dev_merchant` ligado no project.godot: um jogo exportado nunca o tem. Fica ao lado
## do primeiro NPC da região (hoje, o mercador da campina), dourado para não ser confundido.
## Provisório: decidir depois se sai do código ou fica só em desenvolvimento.

const DATA := "res://data/debug/dev_merchant.tres"
const SCENE := preload("res://scenes/npc/npc.tscn")
## Ao lado do NPC da região (chão, px).
const OFFSET := Vector2(0, 28)
const TINT := Color(1.0, 0.85, 0.35)


static func is_enabled() -> bool:
	return OS.is_debug_build() and ProjectSettings.get_setting("game/debug/dev_merchant", false)


## Põe o mercador de testes na região, se ela tiver um NPC. Mesmo lugar em todos os computadores;
## quem decide as compras continua sendo o host (preço 0 vem dos dados dele).
static func add_to(region: Region, items: ItemDatabase, recipes: RecipeDatabase) -> void:
	var anchor: Npc
	for node in region.entities.get_children():
		if node is Npc:
			anchor = node
			break
	if anchor == null:
		return
	var offers: Dictionary[StringName, int] = {}
	for item in items.entries():
		offers[item.id] = 0
	var recipe_offers: Dictionary[StringName, int] = {}
	for recipe: RecipeData in recipes.entries():
		if recipe.must_learn:
			recipe_offers[recipe.id] = 0
	var data := (load(DATA) as NpcData).duplicate() as NpcData
	data.offers = offers
	data.recipe_offers = recipe_offers
	var npc: Npc = SCENE.instantiate()
	npc.name = "DevMerchant"
	npc.data = data
	npc.position = anchor.position + Iso.ground_to_screen(OFFSET)
	npc.modulate = TINT
	region.entities.add_child(npc)
