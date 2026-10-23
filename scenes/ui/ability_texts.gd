class_name AbilityTexts
extends RefCounted
## Texto de uma habilidade para a dica: nome, dano, recarga e os efeitos que aplica.


static func describe(ability: AbilityData) -> String:
	if ability == null:
		return ""
	var lines: Array[String] = [ability.get_display_name(),
		Texts.format(&"STAT_DAMAGE", [ability.damage]),
		Texts.format(&"STAT_ABILITY_COOLDOWN", [String.num(ability.cooldown, 1)])]
	for effect in ability.hit_effects:
		lines.append(Texts.format(&"STAT_EFFECT", [effect.get_display_name(),
			roundi(effect.duration)]))
	return "\n".join(lines)
