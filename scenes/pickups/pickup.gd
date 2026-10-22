class_name Pickup
extends Node2D
## Item no chão que pertence a UM jogador (drop pessoal, `docs/04-multiplayer.md`).
## Nasce onde a criatura morreu e salta num arco até o ponto onde cai (escolhido pelo host,
## sempre em chão andável: `GroundQuery`). Depois de pousar, o dono o pega ao passar por
## cima; dentro do "ímã" do dono, o item escorrega até ele. Só o dono o vê; a coleta é decidida pelo host.

signal collected(pickup: Pickup)

## Duração do salto até o chão; antes de pousar o item não pode ser pego.
const POP_TIME := 0.35
const POP_HEIGHT := 10.0
## Distância (chão, entre centros) em que o dono pega o item. Até `Character.pickup_radius()`
## do dono, o item escorrega até ele (o "ímã", que equipamentos poderão aumentar).
const COLLECT_RADIUS := 8.0
const MAGNET_SPEED := 120.0
## Quanto além do ímã o dono precisa ir para o item que ele jogou fora voltar a ser pegável.
const LEAVE_MARGIN := 8.0
const SPRITE_HEIGHT := 4.0
const BOB_HZ := 1.5
const BOB_HEIGHT := 1.5

var item: ItemData
var amount := 1
var owner_player_id := 0
var session: GameSession
## Onde o item nasce (posição da criatura); `position` é onde ele pousa. Definir os dois
## antes de adicionar à árvore (iguais = sem salto).
var origin := Vector2.ZERO
## Item que o próprio dono jogou fora: não volta sozinho para ele; só depois que o dono se
## afastar além do ímã o item passa a poder ser pego.
var waits_for_owner_to_leave := false

var _time := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _shadow: Sprite2D = $Shadow


func _ready() -> void:
	_sprite.texture = item.icon
	_update_visual()


func has_landed() -> bool:
	return _time >= POP_TIME


func _physics_process(delta: float) -> void:
	_time += delta
	_update_visual()
	if not has_landed():
		return
	var owner_body := session.get_player_entity(owner_player_id) as Character
	if owner_body == null or not owner_body.is_alive() or owner_body.get_parent() != get_parent():
		return
	var inventory := session.get_inventory(owner_player_id)
	if inventory == null or not inventory.can_add(item.id, amount):
		return  # inventário cheio: o item espera no chão
	var distance := Iso.ground_distance(position, owner_body.position)
	if waits_for_owner_to_leave:
		waits_for_owner_to_leave = distance <= owner_body.pickup_radius() + LEAVE_MARGIN
		return
	if distance <= COLLECT_RADIUS:
		_collect()
	elif distance <= owner_body.pickup_radius():
		position = position.move_toward(owner_body.position, MAGNET_SPEED * delta)


func _collect() -> void:
	if not multiplayer.is_server():
		return  # o cliente espera o host remover o item
	session.get_inventory(owner_player_id).add(item.id, amount)
	collected.emit(self)
	queue_free()


## Durante o salto, sprite e sombra vão da origem até o ponto de pouso (o sprite em arco);
## depois, o item balança no lugar.
func _update_visual() -> void:
	var t := minf(_time / POP_TIME, 1.0)
	var ground_offset := (origin - position) * (1.0 - t)
	_shadow.position = ground_offset
	var height := sin(t * PI) * POP_HEIGHT if t < 1.0 \
		else absf(sin((_time - POP_TIME) * TAU * BOB_HZ * 0.5)) * BOB_HEIGHT
	_sprite.position = ground_offset + Vector2(0.0, -SPRITE_HEIGHT - height)
