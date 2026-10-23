class_name CharacterRecord
extends RefCounted
## Progresso de UM personagem no save do mundo (ADR-019): inventário (com a mão), equipamento,
## experiência de coleta, moedas, receitas aprendidas e vida atual. `capture` monta o registro;
## `restore` aplica um registro lido do arquivo, que é dado NÃO confiável: o que não for válido é
## ignorado. Nunca cria item que não existe, pilha acima do limite nem equipamento fora do lugar.

## Limites de leitura: bem acima de qualquer personagem legítimo; só barram lixo.
const MAX_SLOTS := 256
const MAX_XP := 1_000_000_000
const MAX_HEALTH := 1_000_000
const MAX_RECIPES := 1024


static func capture(inventory: Inventory, equipment: Equipment, skills: SkillProgress,
		wallet: Wallet, book: RecipeBook, health: int) -> Dictionary:
	var slots := []
	for index in inventory.capacity():
		slots.append([String(inventory.slot_item(index)), inventory.slot_amount(index)])
	var worn := []
	for index in equipment.size():
		worn.append(String(equipment.item_id(index)))
	var xp := {}
	for skill_id in skills.all_xp():
		xp[String(skill_id)] = skills.xp(skill_id)
	var learned := []
	for recipe_id in book.all_learned():
		learned.append(String(recipe_id))
	return {"inventory": slots, "held": [String(inventory.held_item()), inventory.held_amount()],
		"equipment": worn, "skills": xp, "coins": wallet.coins(), "recipes": learned,
		"health": health}


## Aplica `record` num personagem recém-criado (inventário vazio, nada vestido). Retorna a vida
## salva, ou 0 se não houver uma válida (o personagem fica com a vida cheia).
static func restore(record: Variant, inventory: Inventory, equipment: Equipment,
		skills: SkillProgress, wallet: Wallet, book: RecipeBook, skill_catalog: DataCatalog,
		items: ItemDatabase, recipes: RecipeDatabase) -> int:
	if not record is Dictionary:
		return 0
	var data: Dictionary = record
	# Equipamento primeiro: mochilas aumentam o inventário (o spawner reage a cada espaço).
	_restore_equipment(data.get("equipment"), equipment)
	_restore_inventory(data, inventory, items)
	var xp: Variant = data.get("skills")
	if xp is Dictionary:
		for skill_id: Variant in xp:
			if skill_id is String and skill_catalog.has(StringName(skill_id)):
				var value := SaveValues.to_int(xp[skill_id], 0, MAX_XP, -1)
				if value > 0:
					skills.replicate_xp(StringName(skill_id), value)
	wallet.replicate(SaveValues.to_int(data.get("coins"), 0, Wallet.MAX_COINS, 0))
	_restore_recipes(data.get("recipes"), book, recipes)
	return SaveValues.to_int(data.get("health"), 1, MAX_HEALTH, 0)


## Na ordem dos espaços (mão principal antes da secundária): `fits` confere tipo do espaço,
## acessório repetido e se a arma aceita o item secundário.
static func _restore_equipment(worn: Variant, equipment: Equipment) -> void:
	if not worn is Array:
		return
	var ids: Array = worn
	for index in mini(ids.size(), equipment.size()):
		var item := equipment.data_of(StringName(ids[index])) if ids[index] is String else null
		if item and EquipmentRules.fits(equipment, index, item):
			equipment.replicate_slot(index, item.id)


## Cada pilha volta ao seu espaço; a que não tiver mais espaço (mochila perdida) é guardada onde
## couber. O que não couber em lugar nenhum se perde.
static func _restore_inventory(data: Dictionary, inventory: Inventory, items: ItemDatabase) -> void:
	var leftovers: Array[Array] = []
	var slots: Variant = data.get("inventory")
	if slots is Array:
		var entries: Array = slots
		for index in mini(entries.size(), MAX_SLOTS):
			var stack := _stack(entries[index], inventory, items)
			if stack.is_empty():
				continue
			if inventory.is_valid_slot(index):
				inventory.set_slot(index, stack[0], stack[1])
			else:
				leftovers.append(stack)
	var held := _stack(data.get("held"), inventory, items)
	if not held.is_empty():
		inventory.set_held(held[0], held[1])
	for stack in leftovers:
		inventory.store(stack[0], stack[1])


## [id, quantidade] de uma pilha válida (item existe; 1 até o limite de pilha), ou [].
static func _stack(value: Variant, inventory: Inventory, items: ItemDatabase) -> Array:
	if not (value is Array and value.size() == 2 and value[0] is String):
		return []
	var item_id := StringName(value[0])
	if items.get_item(item_id) == null:
		return []
	var amount := SaveValues.to_int(value[1], 1, inventory.stack_limit(item_id), 0)
	return [item_id, amount] if amount > 0 else []


## Só receitas que existem e precisam ser aprendidas (o resto já se sabe ou é lixo).
static func _restore_recipes(learned: Variant, book: RecipeBook, recipes: RecipeDatabase) -> void:
	if not learned is Array:
		return
	var ids: Array = learned
	for index in mini(ids.size(), MAX_RECIPES):
		var recipe := recipes.get_recipe(StringName(ids[index])) if ids[index] is String else null
		if recipe:
			book.replicate(recipe)
