class_name MountData
extends EquipmentData
## Montaria (ADR-035): vai no espaço de montaria; com ela vestida, a tecla de montar a chama.
## Estilo Albion (escolha do João): montar leva `mount_time` parado; montado, anda mais rápido,
## mas não ataca, não coleta nem lança habilidades, e levar dano derruba.

## Porcentagem somada à velocidade de andar enquanto montado (80 = +80%).
@export var speed_percent: float = 80.0
## Segundos parado até subir (antecipação; apanhar interrompe).
@export var mount_time: float = 1.0

@export_group("Apresentação")
## Desenho da montaria, com a origem nos pés dela (como o personagem).
@export var texture: Texture2D
## Canto de cima à esquerda do desenho, relativo aos pés.
@export var texture_offset := Vector2.ZERO
## Quanto o cavaleiro sobe (px de tela) para sentar nas costas da montaria.
@export var rider_height: float = 6.0


func get_slot() -> EquipmentData.Slot:
	return Slot.MOUNT
