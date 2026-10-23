class_name SlamFeedback
extends Node
## Apresentação do salto (SlamAttacker) do Character pai, em todos os computadores: aviso no
## chão onde ele vai cair, que enche até o impacto; na queda, onda no chão e tremor de câmera
## para quem estiver perto. A pose do corpo (altura do pulo, achatar) fica com o visual dele.

var _telegraph: GroundTelegraph

@onready var _body: Character = get_parent()


func _ready() -> void:
	_body.slammer.slam_started.connect(_on_slam_started)
	_body.slammer.slam_landed.connect(_on_slam_landed)
	_body.slammer.slam_finished.connect(_clear)


func _process(_delta: float) -> void:
	if is_instance_valid(_telegraph) and _body.slammer.is_slamming():
		_telegraph.set_progress(_progress())


func _on_slam_started(landing: Vector2, attack: SlamAttackData) -> void:
	_clear()
	var region := Region.of(_body)
	if region == null:
		return
	_telegraph = GroundTelegraph.new()
	_telegraph.setup(landing, attack.radius)
	region.ground_effects.add_child(_telegraph)


func _on_slam_landed(landing: Vector2, attack: SlamAttackData) -> void:
	if is_instance_valid(_telegraph):
		_telegraph.burst()
		_telegraph = null
	get_tree().call_group(GameCamera.GROUP, &"shake_near", landing, _body.get_world_2d(),
		attack.shake_reach, attack.shake_strength, attack.shake_time)


## O aviso enche durante a espera e o voo: o miolo cheio = a queda.
func _progress() -> float:
	var attack := _body.slammer.attack
	return _body.slammer.elapsed_until_landing() / (attack.windup + attack.air_time)


## Salto interrompido (morte) ou terminado: o aviso que sobrou some.
func _clear() -> void:
	if is_instance_valid(_telegraph) and not _telegraph.is_queued_for_deletion():
		_telegraph.queue_free()
	_telegraph = null
