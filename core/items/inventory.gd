class_name Inventory
extends RefCounted
## Inventário de UM jogador: uma fila de espaços; cada espaço guarda um tipo de item até o
## limite de pilha dele (`ItemData.max_stack`). Só o host altera (`add`, `remove`, `move`,
## `take_slot`); na rede, o dono recebe cada espaço (`replicate_slot`) e os ganhos
## (`notify_added`), ver PlayerStateSync.

signal slot_changed(index: int)
## Ganho de itens (apresentação: "+1 Madeira"). Mover itens entre espaços não conta.
signal added(item_id: StringName, amount: int)

## Limite de pilha sem catálogo de itens (testes) ou para item desconhecido.
const DEFAULT_STACK := 99
## Tamanho padrão do inventário de um jogador.
const DEFAULT_SLOTS := 30
const EMPTY := &""

var _ids: Array[StringName] = []
var _amounts := PackedInt32Array()
var _items: ItemDatabase


func _init(capacity: int, items: ItemDatabase = null) -> void:
	_items = items
	_ids.resize(capacity)
	_ids.fill(EMPTY)
	_amounts.resize(capacity)


func capacity() -> int:
	return _ids.size()


func slot_item(index: int) -> StringName:
	return _ids[index]


func slot_amount(index: int) -> int:
	return _amounts[index]


func stack_limit(item_id: StringName) -> int:
	var item := _items.get_item(item_id) if _items else null
	return item.max_stack if item else DEFAULT_STACK


func count(item_id: StringName) -> int:
	var total := 0
	for i in capacity():
		if _ids[i] == item_id:
			total += _amounts[i]
	return total


## Quanto deste item ainda cabe (pilhas incompletas + espaços vazios).
func space_for(item_id: StringName) -> int:
	var limit := stack_limit(item_id)
	var space := 0
	for i in capacity():
		if _ids[i] == item_id:
			space += limit - _amounts[i]
		elif _ids[i] == EMPTY:
			space += limit
	return space


func can_add(item_id: StringName, amount: int) -> bool:
	return space_for(item_id) >= amount


## Guarda o que couber (primeiro completa pilhas, depois ocupa espaços vazios). Retorna o que
## sobrou (0 = tudo guardado).
func add(item_id: StringName, amount: int) -> int:
	var left := amount
	var limit := stack_limit(item_id)
	for pass_empty in [false, true]:
		for i in capacity():
			if left == 0:
				break
			var matches: bool = _ids[i] == EMPTY if pass_empty else _ids[i] == item_id
			if matches and _amounts[i] < limit:
				var put := mini(limit - _amounts[i], left)
				_set_slot(i, item_id, _amounts[i] + put)
				left -= put
	if left < amount:
		added.emit(item_id, amount - left)
	return left


## Tira `amount` deste item (das últimas pilhas para as primeiras). Tudo ou nada.
func remove(item_id: StringName, amount: int) -> bool:
	if count(item_id) < amount:
		return false
	var left := amount
	for i in range(capacity() - 1, -1, -1):
		if left > 0 and _ids[i] == item_id:
			var take := mini(_amounts[i], left)
			_set_slot(i, item_id, _amounts[i] - take)
			left -= take
	return true


## Move o conteúdo de um espaço para outro: junta se for o mesmo item (até o limite), senão
## troca os dois de lugar.
func move(from: int, to: int) -> void:
	if from == to or _ids[from] == EMPTY:
		return
	if _ids[from] == _ids[to]:
		var put := mini(stack_limit(_ids[to]) - _amounts[to], _amounts[from])
		_set_slot(to, _ids[to], _amounts[to] + put)
		_set_slot(from, _ids[from], _amounts[from] - put)
	else:
		var moving_id := _ids[from]
		var moving_amount := _amounts[from]
		_set_slot(from, _ids[to], _amounts[to])
		_set_slot(to, moving_id, moving_amount)


## Tudo isto cabe junto? (Simula numa cópia: itens diferentes podem disputar o mesmo espaço.)
func can_add_all(amounts: Dictionary[StringName, int]) -> bool:
	var copy := Inventory.new(capacity(), _items)
	copy._ids = _ids.duplicate()
	copy._amounts = _amounts.duplicate()
	for item_id in amounts:
		if copy.add(item_id, amounts[item_id]) > 0:
			return false
	return true


## Esvazia um espaço e devolve o que havia nele: [id, quantidade].
func take_slot(index: int) -> Array:
	var content := [_ids[index], _amounts[index]]
	_set_slot(index, EMPTY, 0)
	return content


func is_valid_slot(index: int) -> bool:
	return index >= 0 and index < capacity()


## Quantidade total por item (para quem não se importa com espaços).
func get_counts() -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for i in capacity():
		if _ids[i] != EMPTY:
			counts[_ids[i]] = counts.get(_ids[i], 0) + _amounts[i]
	return counts


## Cliente: conteúdo oficial de um espaço, vindo do host.
func replicate_slot(index: int, item_id: StringName, amount: int) -> void:
	_set_slot(index, item_id, amount)


## Cliente: o host avisou um ganho (só apresentação).
func notify_added(item_id: StringName, amount: int) -> void:
	added.emit(item_id, amount)


func _set_slot(index: int, item_id: StringName, amount: int) -> void:
	if amount <= 0:
		item_id = EMPTY
		amount = 0
	if _ids[index] == item_id and _amounts[index] == amount:
		return
	_ids[index] = item_id
	_amounts[index] = amount
	slot_changed.emit(index)
