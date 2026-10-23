class_name ItemTexts
extends RefCounted
## Texto de um item para a dica ao passar o mouse: nome e, em equipamentos, o que ele faz
## (dano da arma, duas mãos, bônus) e, em consumíveis, a cura, os efeitos e a espera. Mesmo texto no
## inventário, no equipamento, nas receitas e na loja.

## Bônus de `StatBonuses` → chave de texto (só os diferentes de zero aparecem).
const BONUS_TEXTS := {
	&"max_health": &"STAT_MAX_HEALTH",
	&"defense": &"STAT_DEFENSE",
	&"move_speed_percent": &"STAT_MOVE_SPEED",
	&"pickup_radius": &"STAT_PICKUP_RADIUS",
	&"inventory_slots": &"STAT_INVENTORY_SLOTS",
}


static func describe(item: ItemData) -> String:
	if item == null:
		return ""
	var lines: Array[String] = [item.get_display_name()]
	var weapon := item as WeaponData
	if weapon:
		if weapon.attack:
			lines.append(Texts.format(&"STAT_DAMAGE", [weapon.attack.damage]))
		if weapon.grip == WeaponData.Grip.TWO_HAND:
			lines.append(Texts.get_text(&"STAT_TWO_HANDED"))
	var consumable := item as ConsumableData
	if consumable:
		if consumable.heal > 0:
			lines.append(Texts.format(&"STAT_HEAL", [consumable.heal]))
		for effect in consumable.effects:
			lines.append(Texts.format(&"STAT_EFFECT", [effect.get_display_name(),
				roundi(effect.duration)]))
			lines.append_array(_bonus_lines(effect.bonuses))
		if consumable.cooldown > 0.0:
			lines.append(Texts.format(&"STAT_COOLDOWN", [roundi(consumable.cooldown)]))
	var equipment := item as EquipmentData
	if equipment:
		lines.append_array(_bonus_lines(equipment.bonuses))
	return "\n".join(lines)


static func _bonus_lines(bonuses: StatBonuses) -> Array[String]:
	var lines: Array[String] = []
	if bonuses:
		for property: StringName in BONUS_TEXTS:
			var value: float = bonuses.get(property)
			if value != 0.0:
				lines.append(Texts.format(BONUS_TEXTS[property], [roundi(value)]))
	return lines
