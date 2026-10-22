class_name PlaceableData
extends ItemData
## Item que vira uma estrutura no mundo ao ser colocado (ex.: bancada). Na mão, mostra a
## prévia no chão; um clique coloca (o host confere, ver PlacementRules).

@export var structure: StructureData
