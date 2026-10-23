class_name StatBonuses
extends Resource
## Bônus de atributos de um equipamento, somados aos de `ActorStats` por jogador (o recurso de
## atributos é compartilhado e nunca é alterado). Valores em `data/items/`.

@export var max_health: int = 0
@export var defense: int = 0
## Porcentagem somada à velocidade de andar (10 = +10%).
@export var move_speed_percent: float = 0.0
## Pixels (chão) somados ao raio do ímã de itens.
@export var pickup_radius: float = 0.0
## Espaços somados ao inventário (mochilas).
@export var inventory_slots: int = 0


## Soma dos bônus de todos estes itens.
static func total(items: Array[EquipmentData]) -> StatBonuses:
	var sum := StatBonuses.new()
	for item in items:
		sum.add(item.bonuses)
	return sum


## Soma `other` a estes bônus (null = nada).
func add(other: StatBonuses) -> void:
	if other == null:
		return
	max_health += other.max_health
	defense += other.defense
	move_speed_percent += other.move_speed_percent
	pickup_radius += other.pickup_radius
	inventory_slots += other.inventory_slots
