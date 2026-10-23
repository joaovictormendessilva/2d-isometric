class_name Equipment
extends RefCounted
## Equipamento de UM jogador: um item (ou nada) por espaço, nos espaços de `EquipmentLayout`.
## Só o host altera (via EquipmentRules); na rede, todos recebem cada espaço (`replicate_slot`).
## Cada espaço também tem uma APARÊNCIA (G3c, ADR-030): a do próprio item, a de outro equipamento
## colecionado do mesmo tipo (transmog, vale mesmo com o espaço vazio) ou nenhuma (escondido).
## Atributos e golpe vêm do que está vestido; o que se vê (auras e, um dia, sprites), de `shown`.

signal slot_changed(index: int)
signal look_changed(index: int)

const EMPTY := &""
## Aparências especiais de um espaço (ids que nenhum item usa).
const OWN_LOOK := &""  ## mostra o item vestido
const HIDDEN_LOOK := &"-"  ## não mostra nada

var _types: Array[EquipmentData.Slot] = []
var _ids: Array[StringName] = []
var _looks: Array[StringName] = []
var _items: ItemDatabase


func _init(layout: EquipmentLayout, items: ItemDatabase) -> void:
	_items = items
	_types.assign(layout.slots)
	_ids.resize(_types.size())
	_ids.fill(EMPTY)
	_looks.resize(_types.size())
	_looks.fill(OWN_LOOK)


func size() -> int:
	return _ids.size()


func is_valid_index(index: int) -> bool:
	return index >= 0 and index < size()


func slot_type(index: int) -> EquipmentData.Slot:
	return _types[index]


func item_id(index: int) -> StringName:
	return _ids[index]


func item(index: int) -> EquipmentData:
	return data_of(_ids[index])


## Primeiro espaço deste tipo (-1 se o personagem não tem nenhum).
func index_of_type(type: EquipmentData.Slot) -> int:
	return _types.find(type)


## Item no primeiro espaço do tipo (ex.: a arma da mão principal), ou null.
func item_of_type(type: EquipmentData.Slot) -> EquipmentData:
	var index := index_of_type(type)
	return item(index) if index >= 0 else null


func weapon() -> WeaponData:
	return item_of_type(EquipmentData.Slot.MAIN_HAND) as WeaponData


func off_hand() -> OffHandData:
	return item_of_type(EquipmentData.Slot.OFF_HAND) as OffHandData


## Tudo o que está vestido (para somar atributos).
func equipped() -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for index in size():
		var equipped_item := item(index)
		if equipped_item:
			result.append(equipped_item)
	return result


func look(index: int) -> StringName:
	return _looks[index]


## Aparências de todos os espaços, na ordem (rede e save).
func looks() -> PackedStringArray:
	return PackedStringArray(_looks)


## O que aparece no espaço: o item vestido, o da aparência escolhida, ou null (vazio/escondido).
func shown(index: int) -> EquipmentData:
	match _looks[index]:
		OWN_LOOK:
			return item(index)
		HIDDEN_LOOK:
			return null
	return data_of(_looks[index])


## Tudo o que aparece no personagem.
func shown_items() -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for index in size():
		var shown_item := shown(index)
		if shown_item:
			result.append(shown_item)
	return result


## Host (EquipmentRules) e cliente (dado oficial vindo do host).
func replicate_look(index: int, look_id: StringName) -> void:
	if _looks[index] == look_id:
		return
	_looks[index] = look_id
	look_changed.emit(index)


## Host (EquipmentRules) e cliente (dado oficial vindo do host).
func replicate_slot(index: int, id: StringName) -> void:
	if _ids[index] == id:
		return
	_ids[index] = id
	slot_changed.emit(index)


## Dados de um item de equipamento pelo id (null se não for equipamento).
func data_of(id: StringName) -> EquipmentData:
	return _items.get_item(id) as EquipmentData if _items else null
