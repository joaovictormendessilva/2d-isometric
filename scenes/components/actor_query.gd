class_name ActorQuery
extends RefCounted
## Quem um ataque atinge: personagens vivos de outra facção perto de um ponto, medindo no plano
## do chão. Usado pelo golpe (Attacker) e pelos golpes em área (AreaStrike: salto e habilidades).

## Maior raio de pegada esperado num alvo; amplia a busca física inicial.
const MAX_TARGET_RADIUS := 16.0
const MAX_TARGETS := 32

## Uma consulta só, reaproveitada: criar a forma a cada busca registrava uma forma nova no
## servidor de física (cada projétil busca a cada quadro; Etapa H). Seguro porque as buscas
## rodam uma de cada vez, na linha principal.
static var _shared_query: PhysicsShapeQueryParameters2D


## Inimigos vivos de `attacker` cuja pegada chega a `reach` (chão) da borda de um círculo de
## raio `inner_radius` em `center` (tela). Golpe: o círculo é a pegada do atacante.
static func hostiles_near(attacker: Character, center: Vector2, inner_radius: float,
		reach: float) -> Array[Character]:
	# Busca física larga (círculo de tela cobre a elipse do chão), depois filtro exato no chão.
	var query := _query()
	(query.shape as CircleShape2D).radius = inner_radius + reach + MAX_TARGET_RADIUS
	query.transform = Transform2D(0.0, center)
	var targets: Array[Character] = []
	for hit in attacker.get_world_2d().direct_space_state.intersect_shape(query, MAX_TARGETS):
		var target := hit.collider as Character
		if target != null and is_hit(attacker, target, center, inner_radius, reach):
			targets.append(target)
	return targets


static func _query() -> PhysicsShapeQueryParameters2D:
	if _shared_query == null:
		_shared_query = PhysicsShapeQueryParameters2D.new()
		_shared_query.shape = CircleShape2D.new()
		_shared_query.collision_mask = PhysicsLayers.ACTORS
	return _shared_query


## O mesmo filtro sem física, para quem já tem os candidatos (investida: ver Attacker).
static func is_hit(attacker: Character, target: Character, center: Vector2, inner_radius: float,
		reach: float) -> bool:
	if not is_instance_valid(target) or target == attacker or target.faction == attacker.faction \
			or not target.is_alive():
		return false
	return Iso.ground_distance(target.global_position, center) - target.footprint_radius() \
		- inner_radius <= reach
