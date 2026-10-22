class_name Character
extends CharacterBody2D
## Corpo simulado de QUALQUER ator — jogador ou criatura. A origem fica nos PÉS (Y-sort).
## Recebe apenas INTENÇÕES (mover, atacar) de um controlador: LocalPlayerInput para o
## jogador, MonsterBrain para criaturas. Quem aplica a física e o dano é a autoridade.
## Componentes opcionais (filhos): Footprint, Health, MeleeAttacker, NetSync ("Net").
## Na rede, só quem SIMULA o corpo roda a física; nos outros computadores o NetSync move
## o corpo pelos estados recebidos.

signal died(character: Character)
signal revived(character: Character)

@export var stats: ActorStats
## Atores da mesma facção não se ferem.
@export var faction: StringName = &"players"

var entity_id := 0
var player_id := 0
## Multiplica `stats.max_health` (ex.: escala por número de jogadores). Definir antes de
## adicionar à árvore.
var max_health_multiplier := 1.0
## Velocidade atual no plano do chão (ver `Iso`).
var ground_velocity := Vector2.ZERO
## Direção em que o ator olha, no plano do chão. Usada pela apresentação e pelo ataque.
var facing := Vector2.DOWN

## Componentes. Resolvidos em `_enter_tree` (antes do `_ready` dos filhos), para que
## componentes visuais filhos já os encontrem no próprio `_ready`.
var health: Health
var attacker: MeleeAttacker
var net: NetSync

var _footprint: Footprint
var _move_intent := Vector2.ZERO
var _stun_left := 0.0

@onready var _collision_layer := collision_layer


func _enter_tree() -> void:
	health = get_node_or_null("Health")
	attacker = get_node_or_null("MeleeAttacker")
	net = get_node_or_null("Net")
	_footprint = get_node_or_null("Footprint")


func _ready() -> void:
	reset_physics_interpolation()  # nasce na posição dada, sem deslizar da origem
	if health:
		health.setup(roundi(stats.max_health * max_health_multiplier), stats.defense,
			stats.invulnerability_time)
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died.unbind(1))


func is_alive() -> bool:
	return health == null or not health.is_dead()


func footprint_radius() -> float:
	return _footprint.radius if _footprint else 0.0


## `direction` no plano do chão; comprimento até 1 (controle analógico pode ser menor).
func set_move_intent(direction: Vector2) -> void:
	_move_intent = direction.limit_length(1.0)


## Pede um ataque na direção dada (plano do chão). Retorna se o ataque começou.
func request_attack(direction: Vector2) -> bool:
	if attacker == null or not is_alive() or _stun_left > 0.0:
		return false
	if not attacker.try_attack(direction):
		return false
	facing = direction.normalized()
	return true


## Ataque decidido em outro computador (ver NetSync): ignora atordoamento, que pode diferir
## por alguns milissegundos entre computadores.
func play_remote_attack(direction: Vector2, tolerance: float) -> void:
	if attacker and is_alive() and attacker.try_attack(direction, tolerance):
		facing = direction.normalized()


func add_ground_impulse(impulse: Vector2) -> void:
	ground_velocity += impulse


## Volta à vida com vida cheia, no ponto dado (renascimento do jogador, reaproveitamento).
func revive(at: Vector2) -> void:
	position = at
	reset_physics_interpolation()
	ground_velocity = Vector2.ZERO
	_stun_left = 0.0
	collision_layer = _collision_layer
	health.restore_full()
	revived.emit(self)


func _physics_process(delta: float) -> void:
	if net and not net.is_simulating():
		return
	_stun_left = maxf(_stun_left - delta, 0.0)
	var intent := _move_intent if is_alive() and _stun_left == 0.0 else Vector2.ZERO
	var speed := stats.move_speed * Iso.move_speed_factor(intent, stats.horizontal_speed_factor)
	if attacker:
		speed *= attacker.move_multiplier()
	var rate := stats.acceleration if intent != Vector2.ZERO else stats.friction
	ground_velocity = ground_velocity.move_toward(intent * speed, rate * delta)
	velocity = Iso.ground_to_screen(ground_velocity)
	move_and_slide()
	# Depois de deslizar numa colisão, a velocidade real pode ter mudado.
	ground_velocity = Iso.screen_to_ground(velocity)
	if intent != Vector2.ZERO and not (attacker and attacker.is_attacking()):
		facing = intent.normalized()


func _on_damaged(info: DamageInfo) -> void:
	_stun_left = stats.hit_stun
	ground_velocity = info.direction * info.knockback * (1.0 - stats.knockback_resistance)
	if attacker:
		attacker.interrupt()


func _on_died() -> void:
	# Corpo deixa de ser alvo e de bloquear; quem o criou decide remover ou reviver.
	collision_layer = 0
	if attacker:
		attacker.stop()  # sem bote "fantasma" depois da morte
	died.emit(self)
