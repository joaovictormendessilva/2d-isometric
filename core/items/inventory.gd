class_name Inventory
extends RefCounted
## Inventário de UM jogador: uma fila de espaços; cada espaço guarda um tipo de item até o
## limite de pilha dele (`ItemData.max_stack`). Mais a "mão": a pilha que o jogador pegou
## com um clique e ainda não pôs em lugar nenhum (faz parte do inventário: não some nem se
## duplica). Só o host altera; na rede, o dono recebe cada espaço (`replicate_slot`), a mão
## (`replicate_held`) e os ganhos (`notify_added`), ver PlayerStateSync.

signal slot_changed(index: int)
signal held_changed
## Ganho de itens (apresentação: "+1 Madeira"). Mexer em itens que já eram seus não conta.
signal added(item_id: StringName, amount: int)

## Limite de pilha sem catálogo de itens (testes) ou para item desconhecido.
const DEFAULT_STACK := 99
## Espaços de quem ainda não tem mochila (mochilas somam espaços, Etapa E4).
const DEFAULT_SLOTS := 12
const EMPTY := &""

var _ids: Array[StringName] = []
var _amounts := PackedInt32Array()
var _held_id := EMPTY
var _held_amount := 0
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


func held_item() -> StringName:
	return _held_id


func held_amount() -> int:
	return _held_amount


func is_holding() -> bool:
	return _held_amount > 0


func stack_limit(item_id: StringName) -> int:
	var item := _items.get_item(item_id) if _items else null
	return item.max_stack if item else DEFAULT_STACK


## Quantidade nos espaços (a mão não conta: o que está nela está "em trânsito").
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


## Guarda itens NOVOS (coleta, drops): o que couber, primeiro completando pilhas. Retorna o
## que sobrou (0 = tudo guardado).
func add(item_id: StringName, amount: int) -> int:
	var left := _store(item_id, amount)
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


## Tudo isto cabe junto? (Simula numa cópia: itens diferentes podem disputar o mesmo espaço.)
func can_add_all(amounts: Dictionary[StringName, int]) -> bool:
	return can_exchange({}, amounts)


## Dá para tirar `removed` e depois guardar `added`? (Fabricação: os ingredientes liberam
## espaço para o resultado.) Simula numa cópia.
func can_exchange(removed: Dictionary[StringName, int],
		added: Dictionary[StringName, int]) -> bool:
	var copy := Inventory.new(capacity(), _items)
	copy._ids = _ids.duplicate()
	copy._amounts = _amounts.duplicate()
	for item_id in removed:
		if not copy.remove(item_id, removed[item_id]):
			return false
	for item_id in added:
		if copy._store(item_id, added[item_id]) > 0:
			return false
	return true


## Clique num espaço. Mão vazia: pega a pilha. Mão cheia: espaço vazio recebe tudo; mesmo item
## junta até o limite (o resto fica na mão); item diferente troca (o do espaço vem para a mão).
func click_slot(index: int) -> void:
	if not is_valid_slot(index):
		return
	var slot_id := _ids[index]
	var slot_amount_ := _amounts[index]
	if not is_holding():
		_set_held(slot_id, slot_amount_)
		_set_slot(index, EMPTY, 0)
	elif slot_id == _held_id:
		var put := mini(stack_limit(slot_id) - slot_amount_, _held_amount)
		_set_slot(index, slot_id, slot_amount_ + put)
		_set_held(_held_id, _held_amount - put)
	else:
		_set_slot(index, _held_id, _held_amount)
		_set_held(slot_id, slot_amount_)


## Pega `amount` da pilha de `index` (dividir). Só com a mão vazia, e deixando ao menos 1.
func split_to_hand(index: int, amount: int) -> bool:
	if is_holding() or not is_valid_slot(index) or amount < 1 or amount >= _amounts[index]:
		return false
	_set_held(_ids[index], amount)
	_set_slot(index, _ids[index], _amounts[index] - amount)
	return true


## Gasta `amount` do que está na mão (ex.: colocou uma bancada). Tudo ou nada.
func use_held(amount: int) -> bool:
	if amount < 1 or amount > _held_amount:
		return false
	_set_held(_held_id, _held_amount - amount)
	return true


## Esvazia a mão e devolve o que havia nela: [id, quantidade] (ex.: jogar no chão).
func take_held() -> Array:
	var content := [_held_id, _held_amount]
	_set_held(EMPTY, 0)
	return content


## Devolve o que está na mão para os espaços (ex.: fechou o inventário). Retorna o que não
## coube (fica na mão).
func return_held() -> int:
	if not is_holding():
		return 0
	var left := _store(_held_id, _held_amount)
	_set_held(_held_id, left)
	return left


func is_valid_slot(index: int) -> bool:
	return index >= 0 and index < capacity()


## Quantidade total por item nos espaços (para quem não se importa com espaços).
func get_counts() -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for i in capacity():
		if _ids[i] != EMPTY:
			counts[_ids[i]] = counts.get(_ids[i], 0) + _amounts[i]
	return counts


## Cliente: conteúdo oficial de um espaço, vindo do host.
func replicate_slot(index: int, item_id: StringName, amount: int) -> void:
	_set_slot(index, item_id, amount)


## Cliente: conteúdo oficial da mão, vindo do host.
func replicate_held(item_id: StringName, amount: int) -> void:
	_set_held(item_id, amount)


## Cliente: o host avisou um ganho (só apresentação).
func notify_added(item_id: StringName, amount: int) -> void:
	added.emit(item_id, amount)


## Guarda sem avisar ganho: completa pilhas, depois ocupa espaços vazios. Retorna a sobra.
func _store(item_id: StringName, amount: int) -> int:
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
	return left


func _set_slot(index: int, item_id: StringName, amount: int) -> void:
	if amount <= 0:
		item_id = EMPTY
		amount = 0
	if _ids[index] == item_id and _amounts[index] == amount:
		return
	_ids[index] = item_id
	_amounts[index] = amount
	slot_changed.emit(index)


func _set_held(item_id: StringName, amount: int) -> void:
	if amount <= 0:
		item_id = EMPTY
		amount = 0
	if _held_id == item_id and _held_amount == amount:
		return
	_held_id = item_id
	_held_amount = amount
	held_changed.emit()
