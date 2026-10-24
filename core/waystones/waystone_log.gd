class_name WaystoneLog
extends RefCounted
## Pedras de portal que UM jogador ativou (ADR-037). Ativada, fica para sempre com o personagem
## (vai no save). Só o host ativa; na rede, o dono recebe a lista inteira (`replicate`), conferida
## contra as pedras que existem. Mesmo padrão do RecipeBook.

## Uma pedra entrou na lista. `is_new`: ativada agora (aviso), e não vinda do save ou do host.
signal activated(waystone_id: StringName, is_new: bool)

## Lido do save ou da rede: bem acima de qualquer mundo legítimo; só barra lixo.
const MAX_WAYSTONES := 256

var _known: Dictionary[StringName, bool] = {}


func knows(waystone_id: StringName) -> bool:
	return _known.has(waystone_id)


## Ids ativados, em ordem estável (save e rede).
func snapshot() -> PackedStringArray:
	var ids := PackedStringArray()
	for waystone_id in _known:
		ids.append(String(waystone_id))
	ids.sort()
	return ids


## Host: ativa a pedra. Falso se já estava ativada (nada muda).
func activate(waystone_id: StringName) -> bool:
	if knows(waystone_id):
		return false
	_known[waystone_id] = true
	activated.emit(waystone_id, true)
	return true


## Lista vinda do save ou do host (dado não confiável): só entram pedras que `exists` aceita.
## Junta com o que já estava (nada é esquecido). `is_new`: o host avisou uma ativação agora.
func replicate(state: Variant, exists: Callable, is_new: bool = false) -> void:
	if not (state is PackedStringArray or state is Array):
		return
	for index in mini(state.size(), MAX_WAYSTONES):
		var entry: Variant = state[index]
		if entry is String and exists.call(StringName(entry)) and not knows(StringName(entry)):
			_known[StringName(entry)] = true
			activated.emit(StringName(entry), is_new)
