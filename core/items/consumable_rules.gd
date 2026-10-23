class_name ConsumableRules
extends RefCounted
## Regras de usar um item consumível (sem nós): se dá e o uso em si, tudo ou nada. Usadas pelo
## host para decidir e pelo dono para explicar a recusa antes de pedir.
## A vida entra como números (atual e máxima): quem aplica a cura e os efeitos do item usado é quem
## chama (Health.heal, StatusEffects.apply).

enum Check { OK, NOT_USABLE, NO_POTION, DEAD, FULL_HEALTH, COOLING_DOWN, ALREADY_KNOWN }


## Usar o item do espaço `index` com a vida `current`/`maximum`. `abilities`: livro de quem usa
## (tomos; sem ele, tomo nenhum se usa).
static func check_use(inventory: Inventory, index: int, items: ItemDatabase, current: int,
		maximum: int, cooldowns: Cooldowns, now: float, abilities: AbilityBook = null) -> Check:
	var item := _consumable_at(inventory, index, items)
	if item == null or (item.teaches_ability and abilities == null):
		return Check.NOT_USABLE
	if current <= 0:
		return Check.DEAD
	if item.teaches_ability and abilities.knows(item.teaches_ability.id):
		return Check.ALREADY_KNOWN  # não gasta o tomo
	if item.heal > 0 and item.effects.is_empty() and current >= maximum:
		return Check.FULL_HEALTH  # não desperdiça a poção (com efeitos, ainda serve)
	if not cooldowns.is_ready(item.cooldown_group, now):
		return Check.COOLING_DOWN
	return Check.OK


## Gasta uma unidade do espaço e começa a espera. Retorna o item usado (null = recusado): a cura,
## os efeitos e a habilidade que ele ensina.
static func use(inventory: Inventory, index: int, items: ItemDatabase, current: int,
		maximum: int, cooldowns: Cooldowns, now: float, abilities: AbilityBook = null) -> ConsumableData:
	if check_use(inventory, index, items, current, maximum, cooldowns, now, abilities) != Check.OK:
		return null
	var item := _consumable_at(inventory, index, items)
	inventory.set_slot(index, item.id, inventory.slot_amount(index) - 1)
	cooldowns.start(item.cooldown_group, item.cooldown, now)
	return item


## Espaço que a tecla de poção usa: o primeiro com um item que cura (-1 = nenhum).
static func healing_slot(inventory: Inventory, items: ItemDatabase) -> int:
	for index in inventory.capacity():
		var item := _consumable_at(inventory, index, items)
		if item and item.heal > 0:
			return index
	return -1


## Tecla de poção: como `check_use`, mas sem poção nenhuma a recusa é NO_POTION.
static func check_quick_heal(inventory: Inventory, items: ItemDatabase, current: int,
		maximum: int, cooldowns: Cooldowns, now: float) -> Check:
	var index := healing_slot(inventory, items)
	if index < 0:
		return Check.NO_POTION
	return check_use(inventory, index, items, current, maximum, cooldowns, now)


static func is_usable(item: ItemData) -> bool:
	return item is ConsumableData


static func _consumable_at(inventory: Inventory, index: int, items: ItemDatabase) -> ConsumableData:
	if not inventory.is_valid_slot(index) or inventory.slot_amount(index) < 1:
		return null
	return items.get_item(inventory.slot_item(index)) as ConsumableData
