class_name ResourceNode
extends StaticBody2D
## Ponto de coleta no mundo (árvore de lenha, veio de cobre...), definido por um
## `ResourceNodeData`. Cada coleta gasta uma carga; sem cargas, o ponto fica esgotado (toco,
## cascalho) e volta depois de `respawn_time`. Quem coleta é o `Gatherer` do jogador.
## Cargas e renascimento são decididos SÓ pelo host e replicados (ADR-012); o ponto faz parte
## da cena da região, então tem o mesmo caminho em todos os computadores.

## Uma coleta terminou neste ponto (apresentação: tremer).
signal gathered
signal depletion_changed(depleted: bool)

## Tremida ao ser coletado (px, s).
const SHAKE_DISTANCE := 1.5
const SHAKE_TIME := 0.15

@export var data: ResourceNodeData

var charges_left := 0

var _respawn_left := 0.0
var _broadcast: HostBroadcast
var _shake_tween: Tween

@onready var _sprite: Sprite2D = $Sprite


func _enter_tree() -> void:
	# Antes do `_ready` dos filhos: o OccluderFade mede o sprite no próprio `_ready`.
	($Sprite as Sprite2D).texture = data.texture


func _ready() -> void:
	charges_left = data.charges
	_broadcast = HostBroadcast.new(self)
	HostBroadcast.request_from_host(self, &"_request_state")
	set_physics_process(false)


func is_depleted() -> bool:
	return charges_left <= 0


## Onde fica, encostado à esquerda deste ponto (no plano do chão), quem tem pegada de raio
## `radius` (testes e capturas de animação posicionam o personagem aqui).
func approach_point(radius: float) -> Vector2:
	var footprint: Footprint = $Footprint
	return position - Iso.ground_to_screen(Vector2(footprint.radius + radius + 2.0, 0))


## Save do mundo (ADR-019): cargas e tempo que falta para renascer.
func save_state() -> Array:
	return [charges_left, _respawn_left]


## Host, ao carregar o mundo. Dado do arquivo (não confiável): limitado ao que o tipo permite.
func load_state(state: Variant) -> void:
	if not (state is Array and state.size() == 2):
		return
	var was_depleted := is_depleted()
	charges_left = SaveValues.to_int(state[0], 0, data.charges, data.charges)
	_respawn_left = SaveValues.to_float(state[1], 0.0, data.respawn_time, data.respawn_time) \
		if is_depleted() else 0.0
	set_physics_process(is_depleted())
	if was_depleted != is_depleted():
		_sprite.texture = data.depleted_texture if is_depleted() else data.texture
		depletion_changed.emit(is_depleted())


## Host: gasta uma carga (uma coleta concluída). Ao esgotar, agenda o renascimento.
func take_charge() -> void:
	if is_depleted():
		return
	_set_charges(charges_left - 1)
	if is_depleted():
		_respawn_left = data.respawn_time
		set_physics_process(true)


func _physics_process(delta: float) -> void:
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		set_physics_process(false)
		_set_charges(data.charges)


func _set_charges(value: int) -> void:
	var was_depleted := is_depleted()
	var spent := value < charges_left
	charges_left = value
	_broadcast.send(&"_charges", [value])
	if spent:
		_shake()
		gathered.emit()
	if was_depleted != is_depleted():
		_sprite.texture = data.depleted_texture if is_depleted() else data.texture
		depletion_changed.emit(is_depleted())


func _shake() -> void:
	if _shake_tween:
		_shake_tween.kill()
	_sprite.position = Vector2(SHAKE_DISTANCE, 0)
	_shake_tween = create_tween()
	_shake_tween.tween_property(_sprite, "position", Vector2.ZERO, SHAKE_TIME) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


@rpc("authority", "call_remote", "reliable")
func _charges(value: int) -> void:
	_set_charges(clampi(value, 0, data.charges))


## Cliente com a região carregada pede o estado atual (ex.: entrou com pontos esgotados).
@rpc("any_peer", "call_remote", "reliable")
func _request_state() -> void:
	var peer := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and _broadcast.add_peer(peer):
		_charges.rpc_id(peer, charges_left)
