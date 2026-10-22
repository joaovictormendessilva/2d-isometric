class_name PlacementRules
extends RefCounted
## Onde uma estrutura pode ser colocada (sem estado): perto do jogador, em chão livre de
## água, objetos e personagens, e sem nada no caminho. O host decide com esta regra; a prévia
## usa a mesma para mostrar verde ou vermelho.

## Distância máxima (no chão) dos pés do jogador até o ponto.
const MAX_DISTANCE := 48.0


static func can_place(space: PhysicsDirectSpaceState2D, structure: StructureData,
		player_position: Vector2, at: Vector2) -> bool:
	return Iso.ground_distance(player_position, at) <= MAX_DISTANCE \
		and GroundQuery.is_walkable(space, at, structure.footprint_radius,
			PhysicsLayers.WORLD | PhysicsLayers.ACTORS) \
		and GroundQuery.is_reachable(space, player_position, at)
