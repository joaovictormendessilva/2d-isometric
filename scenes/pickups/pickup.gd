class_name Pickup
extends Area2D
## Item no chão que pertence a UM jogador (drop pessoal, `docs/04-multiplayer.md`).
## Só o dono o vê e coleta; perto dele, o item é atraído. A coleta é feita pela autoridade.

signal collected(pickup: Pickup)

## Distância (chão) em que o item começa a ser atraído pelo dono, e a velocidade.
const MAGNET_RADIUS := 36.0
const MAGNET_SPEED := 170.0
const BOB_HZ := 1.5
const BOB_HEIGHT := 1.5

var item: ItemData
var amount := 1
var owner_player_id := 0
var session: GameSession

var _time := 0.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_sprite.texture = item.icon
	collision_layer = 0
	collision_mask = PhysicsLayers.ACTORS
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_time += delta
	_sprite.position.y = -4.0 - absf(sin(_time * TAU * BOB_HZ * 0.5)) * BOB_HEIGHT
	var owner_body := session.get_player_entity(owner_player_id) as Character
	if owner_body and owner_body.is_alive() \
			and Iso.ground_distance(position, owner_body.position) < MAGNET_RADIUS:
		position = position.move_toward(owner_body.position, MAGNET_SPEED * delta)


func _on_body_entered(body: Node2D) -> void:
	var character := body as Character
	if character == null or character.player_id != owner_player_id or not character.is_alive():
		return
	if not is_multiplayer_authority():
		return
	session.get_inventory(owner_player_id).add(item.id, amount)
	collected.emit(self)
	queue_free()
