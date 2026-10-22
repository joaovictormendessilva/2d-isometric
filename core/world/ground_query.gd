class_name GroundQuery
extends RefCounted
## Perguntas sobre o chão andável (ADR-009). Um ponto é andável se uma pegada redonda ali não
## encosta em nada da camada "world" (água, árvores, pedras). Usado para decidir onde itens
## caem; servirá também para recursos que renascem e criaturas que surgem.

## Tentativas de achar um ponto antes de desistir e usar a origem.
const SPOT_ATTEMPTS := 16


## A pegada (círculo no chão = elipse 2:1 na tela) em `at` está livre? `mask` inclui
## `ACTORS` quando também não pode haver personagens ali (ex.: colocar uma estrutura).
static func is_walkable(space: PhysicsDirectSpaceState2D, at: Vector2, radius: float,
		mask: int = PhysicsLayers.WORLD) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, Vector2(1.0, 1.0 / Iso.Y_SCALE), 0.0, at)
	query.collision_mask = mask
	return space.intersect_shape(query, 1).is_empty()


## Dá para ir em linha reta de `from` até `to` sem atravessar água ou objetos?
static func is_reachable(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD)
	return space.intersect_ray(query).is_empty()


## Ponto andável e alcançável a partir de `origin`, a uma distância (no chão) entre
## `min_distance` e `max_distance`. Sem nenhum, devolve `origin` (quem estava lá andava ali).
static func find_drop_spot(space: PhysicsDirectSpaceState2D, origin: Vector2,
		rng: RandomNumberGenerator, min_distance: float, max_distance: float,
		radius: float) -> Vector2:
	for attempt in SPOT_ATTEMPTS:
		var offset := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(min_distance, max_distance)
		var spot := origin + Iso.ground_to_screen(offset)
		if is_walkable(space, spot, radius) and is_reachable(space, origin, spot):
			return spot
	return origin
