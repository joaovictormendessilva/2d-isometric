class_name EquipmentRules
extends RefCounted
## Regras do equipamento (sem nós): o que vai em cada espaço e as trocas com o inventário, tudo
## ou nada (nada se cria nem se perde). Só o host aplica; a tela usa `fits` para mostrar.
##
## Mãos (ADR-018): a arma diz quais itens secundários aceita; vestir uma arma que não aceita o
## secundário atual o devolve ao inventário (precisa caber). De mãos vazias, qualquer
## secundário serve. Acessórios: nunca dois iguais.


## `item` pode ir no espaço `index`, com o resto do equipamento como está? (O que já está em
## `index` não conta: ele sairia.)
static func fits(equipment: Equipment, index: int, item: EquipmentData) -> bool:
	if item == null or not equipment.is_valid_index(index) \
			or item.get_slot() != equipment.slot_type(index):
		return false
	if item.get_slot() == EquipmentData.Slot.ACCESSORY:
		for other in equipment.size():
			if other != index and equipment.item_id(other) == item.id:
				return false
	var off_hand := item as OffHandData
	if off_hand:
		var weapon := equipment.weapon()
		return weapon == null or weapon.accepts(off_hand)
	return true


## Menu "Equipar" num espaço do inventário: vai para o primeiro espaço livre do tipo, senão
## troca com o primeiro do tipo (o item que sai ocupa o lugar no inventário).
static func equip_from_inventory(inventory: Inventory, equipment: Equipment,
		inventory_index: int) -> bool:
	if inventory.is_holding() or not inventory.is_valid_slot(inventory_index):
		return false
	var item := equipment.data_of(inventory.slot_item(inventory_index))
	var target := _target_index(equipment, item)
	# Trocar por um igual não muda nada (ex.: 2º anel igual com o 1º vestido).
	if target < 0 or equipment.item_id(target) == item.id or not _has_room_for_displaced(inventory, equipment, item,
			equipment.item_id(target) == Equipment.EMPTY):
		return false
	var old := equipment.item_id(target)
	equipment.replicate_slot(target, item.id)
	inventory.set_slot(inventory_index, old, 1)
	_return_displaced(inventory, equipment, item)
	return true


## Clique num espaço de equipamento. Com um item na mão: veste (trocando com o que estava, que
## vem para a mão). Mão vazia: tira o item para a mão.
static func click_slot(inventory: Inventory, equipment: Equipment, index: int) -> bool:
	if not equipment.is_valid_index(index):
		return false
	var old := equipment.item_id(index)
	if not inventory.is_holding():
		if old == Equipment.EMPTY:
			return false
		equipment.replicate_slot(index, Equipment.EMPTY)
		inventory.set_held(old, 1)
		return true
	var item := equipment.data_of(inventory.held_item())
	if inventory.held_amount() != 1 or not fits(equipment, index, item) \
			or not _has_room_for_displaced(inventory, equipment, item, false):
		return false
	equipment.replicate_slot(index, item.id)
	inventory.set_held(old, 1)
	_return_displaced(inventory, equipment, item)
	return true


## Espaço de destino: primeiro livre onde cabe; senão, o primeiro onde cabe (troca).
static func _target_index(equipment: Equipment, item: EquipmentData) -> int:
	var occupied := -1
	for index in equipment.size():
		if fits(equipment, index, item):
			if equipment.item_id(index) == Equipment.EMPTY:
				return index
			if occupied < 0:
				occupied = index
	return occupied


## Secundário que sai se esta arma for vestida (não o aceita), ou null.
static func _displaced(equipment: Equipment, item: EquipmentData) -> OffHandData:
	var weapon := item as WeaponData
	var off_hand := equipment.off_hand()
	return off_hand if weapon and off_hand and not weapon.accepts(off_hand) else null


## O secundário que sai tem onde ficar? `source_frees_slot`: o espaço de onde a arma saiu fica
## vazio (não havia arma vestida), então ele cabe ali.
static func _has_room_for_displaced(inventory: Inventory, equipment: Equipment,
		item: EquipmentData, source_frees_slot: bool) -> bool:
	var displaced := _displaced(equipment, item)
	return displaced == null or source_frees_slot or inventory.can_add(displaced.id, 1)


static func _return_displaced(inventory: Inventory, equipment: Equipment,
		item: EquipmentData) -> void:
	var displaced := _displaced(equipment, item)
	if displaced:
		equipment.replicate_slot(equipment.index_of_type(EquipmentData.Slot.OFF_HAND),
			Equipment.EMPTY)
		inventory.store(displaced.id, 1)
