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
		if item.bonuses:
			sum.max_health += item.bonuses.max_health
			sum.defense += item.bonuses.defense
			sum.move_speed_percent += item.bonuses.move_speed_percent
			sum.pickup_radius += item.bonuses.pickup_radius
			sum.inventory_slots += item.bonuses.inventory_slots
	return sum
