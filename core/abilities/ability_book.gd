class_name AbilityBook
extends RefCounted
## Habilidades de UM jogador (ADR-026): as que aprendeu e as que estão nos espaços das teclas
## 1–4, mais as recargas. O host decide (aprender, trocar de espaço, lançar); o dono recebe o
## livro inteiro a cada mudança e as recargas começadas. Sem nós.

signal changed  ## Aprendeu uma habilidade ou mudou um espaço (a barra se refaz).

const SLOTS := 4
## Limite do que vem de fora (rede, save): bem acima de qualquer jogador legítimo.
const MAX_LEARNED := 256

var cooldowns := Cooldowns.new()

var _learned: Dictionary[StringName, AbilityData] = {}
var _slots: Array[AbilityData] = []


func _init() -> void:
	_slots.resize(SLOTS)


func knows(ability_id: StringName) -> bool:
	return _learned.has(ability_id)


## Aprende e, se houver espaço vazio, já põe no primeiro (aprendeu, já pode usar). Retorna se era
## nova.
func learn(ability: AbilityData) -> bool:
	if ability == null or knows(ability.id) or _learned.size() >= MAX_LEARNED:
		return false
	_learned[ability.id] = ability
	var free := _slots.find(null)
	if free >= 0:
		_slots[free] = ability
	changed.emit()
	return true


func learned() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	result.assign(_learned.values())
	result.sort_custom(func(a: AbilityData, b: AbilityData) -> bool: return a.id < b.id)
	return result


func in_slot(index: int) -> AbilityData:
	return _slots[index] if index >= 0 and index < SLOTS else null


## Põe uma habilidade aprendida no espaço (null = esvazia). Se ela já estava em outro espaço, os
## dois trocam. Retorna se mudou algo.
func set_slot(index: int, ability: AbilityData) -> bool:
	if index < 0 or index >= SLOTS or (ability and not knows(ability.id)):
		return false
	var previous := _slots.find(ability) if ability else -1
	if previous == index:
		return false
	if previous >= 0:
		_slots[previous] = _slots[index]
	_slots[index] = ability
	changed.emit()
	return true


## {"learned": [ids], "slots": [id ou ""]}: para a rede e o save.
func snapshot() -> Dictionary:
	var learned_ids := []
	for ability in learned():
		learned_ids.append(String(ability.id))
	var slot_ids := []
	for ability in _slots:
		slot_ids.append(String(ability.id) if ability else "")
	return {"learned": learned_ids, "slots": slot_ids}


## Troca tudo pelo recebido (host pela rede, ou save). Dado NÃO confiável: só habilidades que
## existem; espaço só com habilidade aprendida e sem repetir.
func replicate(state: Variant, abilities: AbilityDatabase) -> void:
	_learned.clear()
	_slots.fill(null)
	if state is Dictionary:
		var learned_ids: Variant = (state as Dictionary).get("learned")
		if learned_ids is Array:
			for value: Variant in (learned_ids as Array).slice(0, MAX_LEARNED):
				var ability := abilities.get_ability(StringName(value)) if value is String else null
				if ability:
					_learned[ability.id] = ability
		var slot_ids: Variant = (state as Dictionary).get("slots")
		if slot_ids is Array:
			for index in mini((slot_ids as Array).size(), SLOTS):
				var value: Variant = slot_ids[index]
				var ability: AbilityData = _learned.get(StringName(value)) if value is String else null
				if ability and not _slots.has(ability):
					_slots[index] = ability
	changed.emit()
