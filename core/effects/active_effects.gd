class_name ActiveEffects
extends RefCounted
## Efeitos ativos num ator, sem nós (ADR-025). O host aplica, avança o tempo e cobra os ticks;
## os clientes recebem a lista oficial (`replicate`) e só contam o tempo para mostrar.
## Jogadores: um por jogador na sessão (sobrevive à viagem entre regiões). Criaturas: um por
## criatura (StatusEffects).

signal changed  ## Um efeito começou, foi renovado ou acabou (bônus e ícones mudam).

## Limites do que vem de fora (rede, save): barram lixo, bem acima de qualquer efeito legítimo.
const MAX_SECONDS := 3600.0
const MAX_EFFECTS := 32
## Folga de arredondamento: o último tick de um efeito cai no mesmo quadro em que ele acaba.
const EPSILON := 0.0001


class Entry:
	var data: StatusEffectData
	var remaining: float
	var tick_left: float
	## Jogador que aplicou (0 = criatura/ambiente): crédito de quem mata com veneno (drops).
	var source_player_id: int


var _entries: Dictionary[StringName, Entry] = {}


## Começa o efeito, ou renova o tempo cheio se já estiver ativo (o ritmo dos ticks continua: renovar
## não adia o próximo).
func apply(data: StatusEffectData, source_player_id: int = 0) -> void:
	var entry: Entry = _entries.get(data.id)
	if entry == null:
		if _entries.size() >= MAX_EFFECTS:
			return
		entry = Entry.new()
		entry.data = data
		entry.tick_left = data.tick_interval
		_entries[data.id] = entry
	entry.remaining = data.duration
	entry.source_player_id = source_player_id
	changed.emit()


func remove(id: StringName) -> void:
	if _entries.erase(id):
		changed.emit()


func clear() -> void:
	if not _entries.is_empty():
		_entries.clear()
		changed.emit()


## Passa o tempo. Retorna os efeitos que deram tick agora (um item por tick), antes de tirar os
## que acabaram.
func advance(delta: float) -> Array[Entry]:
	var ticked: Array[Entry] = []
	var expired := false
	for id: StringName in _entries.keys():
		var entry := _entries[id]
		if entry.data.has_ticks():
			entry.tick_left -= delta
			while entry.tick_left <= EPSILON:
				ticked.append(entry)
				entry.tick_left += entry.data.tick_interval
		entry.remaining -= delta
		if entry.remaining <= EPSILON:
			_entries.erase(id)
			expired = true
	if expired:
		changed.emit()
	return ticked


func is_empty() -> bool:
	return _entries.is_empty()


func has(id: StringName) -> bool:
	return _entries.has(id)


func remaining(id: StringName) -> float:
	var entry: Entry = _entries.get(id)
	return entry.remaining if entry else 0.0


## Efeitos ativos, em ordem de id (lista estável para a tela).
func entries() -> Array[Entry]:
	var result: Array[Entry] = []
	result.assign(_entries.values())
	result.sort_custom(func(a: Entry, b: Entry) -> bool: return a.data.id < b.data.id)
	return result


func bonuses() -> StatBonuses:
	var sum := StatBonuses.new()
	for entry: Entry in _entries.values():
		sum.add(entry.data.bonuses)
	return sum


## {id: segundos restantes}, para a rede e o save.
func snapshot() -> Dictionary:
	var result := {}
	for id: StringName in _entries:
		result[String(id)] = _entries[id].remaining
	return result


## Troca tudo pela lista recebida (host pela rede, ou save). Dado NÃO confiável: só efeitos que
## existem, tempo entre 0 e a duração do efeito; o resto é ignorado.
func replicate(state: Variant, effects: EffectDatabase) -> void:
	var valid: Dictionary[StringName, Entry] = {}
	if state is Dictionary and (state as Dictionary).size() <= MAX_EFFECTS:
		for key: Variant in state:
			var data := effects.get_effect(StringName(key)) if key is String else null
			var seconds: Variant = state[key]
			if data == null or not (seconds is float or seconds is int) or not is_finite(seconds):
				continue
			var left := minf(float(seconds), minf(data.duration, MAX_SECONDS))
			if left <= 0.0:
				continue
			var entry: Entry = _entries.get(data.id, Entry.new())
			entry.data = data
			entry.remaining = left
			if entry.tick_left <= 0.0:
				entry.tick_left = data.tick_interval
			valid[data.id] = entry
	_entries = valid
	changed.emit()
