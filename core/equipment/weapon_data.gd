class_name WeaponData
extends EquipmentData
## Arma, na mão principal. De 1 mão ou de 2 mãos; `off_hand_kinds` diz o que pode ir na mão
## secundária junto com ela (espada: escudo; cajado de 1 mão: tomo; arco de 2 mãos: aljava;
## espadão: nada) — estilo Path of Exile, pedido do João.

enum Grip { ONE_HAND, TWO_HAND }

@export var grip: Grip = Grip.ONE_HAND
@export var off_hand_kinds: Array[OffHandData.Kind] = []
## Golpe desta arma (a arma define o ataque; sem arma: `fists` dos dados do jogador).
@export var attack: AttackData


func get_slot() -> EquipmentData.Slot:
	return Slot.MAIN_HAND


func accepts(off_hand: OffHandData) -> bool:
	return off_hand.kind in off_hand_kinds
