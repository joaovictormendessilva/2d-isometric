class_name AbilityRules
extends RefCounted
## Regras de lançar uma habilidade (sem nós): se dá e o lançamento em si (começa a recarga). O host
## decide; o dono confere antes de pedir, para responder na hora e explicar a recusa.

enum Check { OK, EMPTY_SLOT, COOLING_DOWN, CANNOT_ACT }


## Lançar a habilidade do espaço `index`. `can_act`: vivo, sem atordoamento nem outro ataque.
static func check_cast(book: AbilityBook, index: int, can_act: bool, now: float) -> Check:
	var ability := book.in_slot(index)
	if ability == null:
		return Check.EMPTY_SLOT
	if not book.cooldowns.is_ready(ability.id, now):
		return Check.COOLING_DOWN
	if not can_act:
		return Check.CANNOT_ACT
	return Check.OK


## Começa a recarga e retorna a habilidade a lançar (null = recusado).
static func cast(book: AbilityBook, index: int, can_act: bool, now: float) -> AbilityData:
	if check_cast(book, index, can_act, now) != Check.OK:
		return null
	var ability := book.in_slot(index)
	book.cooldowns.start(ability.id, ability.cooldown, now)
	return ability
