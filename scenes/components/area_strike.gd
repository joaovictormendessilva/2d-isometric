class_name AreaStrike
extends RefCounted
## Golpe em área (host): fere os inimigos de `attacker` em volta de um ponto, empurrando cada um
## para fora do centro. Usado pelo salto dos chefes (SlamAttacker) e pelas habilidades em área
## (AreaBlast). Retorna quem levou dano de fato, para quem chamou aplicar os efeitos do golpe.


## `center` na tela; `radius` no plano do chão (a pegada do alvo conta).
static func hit(attacker: Character, center: Vector2, radius: float, damage: int,
		knockback: float) -> Array[Character]:
	var hurt: Array[Character] = []
	for target in ActorQuery.hostiles_near(attacker, center, 0.0, radius):
		var away := Iso.screen_to_ground(target.global_position - center)
		var direction := away.normalized() if not away.is_zero_approx() else attacker.facing
		if target.health.apply_damage(DamageInfo.create(damage, direction, knockback,
				attacker.entity_id, attacker.player_id)):
			hurt.append(target)
	return hurt
