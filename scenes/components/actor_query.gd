class_name ActorQuery
extends RefCounted
## Quem um ataque atinge: personagens vivos de outra facção perto de um ponto, medindo no plano
## do chão. Usado pelo golpe (MeleeAttacker) e pelo impacto do salto (SlamAttacker).

## Maior raio de pegada esperado num alvo; amplia a busca física inicial.
const MAX_TARGET_RADIUS := 16.0
const MAX_TARGETS := 32


## Inimigos vivos de `attacker` cuja pegada chega a `reach` (chão) da borda de um círculo de
## raio `inner_radius` em `center` (tela). Golpe: o círculo é a pegada do atacante.
static func hostiles_near(attacker: Character, center: Vector2, inner_radius: float,
		reach: float) -> Array[Character]:
	# Busca física larga (círculo de tela cobre a elipse do chão), depois filtro exato no chão.
	var shape := CircleShape2D.new()
	shape.radius = inner_radius + reach + MAX_TARGET_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = PhysicsLayers.ACTORS
	var targets: Array[Character] = []
	for hit in attacker.get_world_2d().direct_space_state.intersect_shape(query, MAX_TARGETS):
		var target := hit.collider as Character
		if target == null or target == attacker or target.faction == attacker.faction \
				or not target.is_alive():
			continue
		var gap := Iso.ground_distance(target.global_position, center) \
			- target.footprint_radius() - inner_radius
		if gap <= reach:
			targets.append(target)
	return targets
