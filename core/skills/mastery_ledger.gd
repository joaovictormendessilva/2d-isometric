class_name MasteryLedger
extends RefCounted
## Dano que cada jogador causou numa criatura, por maestria (ADR-038). A experiência só é paga
## quando ela morre (`pay_out`): ferir e deixar a criatura voltar para casa curada não rende
## nada. Só no host (o dano só é aplicado lá).

var _entries: Array[Dictionary] = []


func record(skills: SkillProgress, mastery: MasteryData, damage: int) -> void:
	if damage <= 0:
		return
	for entry in _entries:
		if entry.skills == skills and entry.mastery == mastery:
			entry.damage += damage
			return
	_entries.append({"skills": skills, "mastery": mastery, "damage": damage})


func total_damage() -> int:
	var total := 0
	for entry in _entries:
		total += entry.damage
	return total


func clear() -> void:
	_entries.clear()


## Paga cada um pelo dano dele. O total nunca passa de `max_damage` (a vida máxima): se a criatura
## se curou no meio da luta, as partes encolhem na mesma proporção, para curar não virar fonte
## de experiência.
func pay_out(max_damage: int) -> void:
	var scale := minf(1.0, float(max_damage) / maxi(total_damage(), 1))
	for entry in _entries:
		var mastery := entry.mastery as MasteryData
		(entry.skills as SkillProgress).add_xp(mastery.id,
			mastery.xp_for_damage(roundi(entry.damage * scale)))
	clear()
