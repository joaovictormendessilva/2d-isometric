class_name AppearanceCollection
extends RefCounted
## Aparências que UM jogador colecionou (G3c, ADR-030): todo equipamento que já passou pelas mãos
## dele (inventário, mão ou vestido) fica liberado para sempre, mesmo vendido ou destruído. As
## aparências escolhidas em cada espaço ficam no `Equipment` (todos as veem); a coleção, só o
## dono. O host decide (ver `watch`); o dono recebe a coleção inteira a cada mudança. Sem nós.

signal changed  ## Coleção trocada inteira (rede, save).
signal collected(item_id: StringName)  ## Aparência nova (aviso ao jogador).

## Limite do que vem de fora (rede, save): bem acima de qualquer jogador legítimo.
const MAX_ITEMS := 1024

var _ids: Dictionary[StringName, bool] = {}


func has(item_id: StringName) -> bool:
	return _ids.has(item_id)


## Retorna se era nova.
func collect(item_id: StringName) -> bool:
	if item_id == Equipment.EMPTY or has(item_id) or _ids.size() >= MAX_ITEMS:
		return false
	_ids[item_id] = true
	collected.emit(item_id)
	return true


## Ids em ordem (estável para a tela, a rede e o save).
func all() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_ids.keys())
	# Pelo texto: `sort` em StringName não segue a ordem alfabética.
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


## Coleciona todo equipamento que entrar no inventário, na mão ou no corpo do jogador. Ligado em
## todos os computadores com a mesma regra; no cliente a coleção oficial chega do host
## (`replicate`), então o que ele junta sozinho só antecipa o mesmo resultado.
## As ligações guardam o inventário e o equipamento por referência fraca: guardar o próprio
## emissor no sinal dele é um ciclo que nunca seria liberado.
func watch(inventory: Inventory, equipment: Equipment) -> void:
	var inventory_ref: WeakRef = weakref(inventory)
	var equipment_ref: WeakRef = weakref(equipment)
	inventory.slot_changed.connect(func(index: int) -> void:
		_collect_if_equipment(equipment_ref, inventory_ref.get_ref().slot_item(index)))
	inventory.held_changed.connect(func() -> void:
		_collect_if_equipment(equipment_ref, inventory_ref.get_ref().held_item()))
	equipment.slot_changed.connect(func(index: int) -> void:
		_collect_if_equipment(equipment_ref, equipment_ref.get_ref().item_id(index)))


func _collect_if_equipment(equipment_ref: WeakRef, item_id: StringName) -> void:
	var equipment: Equipment = equipment_ref.get_ref()
	if equipment and equipment.data_of(item_id):
		collect(item_id)


## Lista de ids: para a rede e o save.
func snapshot() -> PackedStringArray:
	return PackedStringArray(all())


## Troca tudo pelo recebido (host pela rede, ou save). Dado NÃO confiável: só equipamentos que
## existem, até o limite.
func replicate(state: Variant, items: ItemDatabase) -> void:
	_ids.clear()
	if state is Array or state is PackedStringArray:
		for value: Variant in Array(state).slice(0, MAX_ITEMS):
			if (value is String or value is StringName) \
					and items.get_item(StringName(value)) is EquipmentData:
				_ids[StringName(value)] = true
	changed.emit()
