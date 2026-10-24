class_name Character
extends CharacterBody2D
## Corpo simulado de QUALQUER ator — jogador ou criatura. A origem fica nos PÉS (Y-sort).
## Recebe apenas INTENÇÕES (mover, atacar) de um controlador: LocalPlayerInput para o
## jogador, MonsterBrain para criaturas. Quem aplica a física e o dano é a autoridade.
## Componentes opcionais (filhos): Footprint, Health, Attacker, SlamAttacker, Gatherer,
## StatusEffects, AbilityCaster, NetSync ("Net").
## Na rede, só quem SIMULA o corpo roda a física; nos outros computadores o NetSync move
## o corpo pelos estados recebidos.

signal died(character: Character)
signal revived(character: Character)
## As auras mudaram (equipamento vestido; ver `auras`).
signal auras_changed

## Lentidão nunca para o ator de vez: no mínimo esta fração da velocidade.
const MIN_SPEED_FACTOR := 0.2
## Facção dos jogadores (o padrão; criaturas definem a delas).
const PLAYER_FACTION := &"players"

@export var stats: ActorStats
## Atores da mesma facção não se ferem.
@export var faction: StringName = PLAYER_FACTION

var entity_id := 0
var player_id := 0
## Multiplica `stats.max_health` (ex.: escala por número de jogadores). Definir antes de
## adicionar à árvore.
var max_health_multiplier := 1.0
## Velocidade atual no plano do chão (ver `Iso`).
var ground_velocity := Vector2.ZERO
## Direção em que o ator olha, no plano do chão. Usada pela apresentação e pelo ataque.
var facing := Vector2.DOWN
## Bônus do equipamento vestido (jogadores; ver `apply_equipment`) mais os dos efeitos ativos
## (StatusEffects). Somam a `stats`, que é compartilhado e nunca muda.
var bonuses := StatBonuses.new()
## Efeitos aplicados em quem os ataques deste ator acertam (criaturas: `MonsterData`).
var on_hit_effects: Array[StatusEffectData] = []
## Auras em volta do ator (só aparência, ADR-029): as do equipamento vestido.
var auras: Array[AuraData] = []

## Componentes. Resolvidos em `_enter_tree` (antes do `_ready` dos filhos), para que
## componentes visuais filhos já os encontrem no próprio `_ready`.
var health: Health
var attacker: Attacker
var slammer: SlamAttacker
var gatherer: Gatherer
var status_effects: StatusEffects
var caster: AbilityCaster
var net: NetSync

var _footprint: Footprint
var _move_intent := Vector2.ZERO
var _stun_left := 0.0
var _weapon_attack: AttackData
var _equipment_bonuses := StatBonuses.new()

@onready var _collision_layer := collision_layer


func _enter_tree() -> void:
	health = get_node_or_null("Health")
	attacker = get_node_or_null("Attacker")
	slammer = get_node_or_null("SlamAttacker")
	gatherer = get_node_or_null("Gatherer")
	status_effects = get_node_or_null("StatusEffects")
	caster = get_node_or_null("AbilityCaster")
	net = get_node_or_null("Net")
	_footprint = get_node_or_null("Footprint")


func _ready() -> void:
	reset_physics_interpolation()  # nasce na posição dada, sem deslizar da origem
	bonuses = _total_bonuses()
	if status_effects:
		status_effects.effects.changed.connect(_update_bonuses)
	if health:
		health.setup(_max_health(), _defense(), stats.invulnerability_time)
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died.unbind(1))
	if attacker and attacker.attack == null:
		attacker.attack = _weapon_attack if _weapon_attack else stats.unarmed_attack
	if attacker and gatherer:
		attacker.attack_started.connect(gatherer.stop.unbind(2))  # atacar larga a coleta
	if caster and gatherer:
		caster.cast_started.connect(gatherer.stop.unbind(2))  # lançar também


func is_alive() -> bool:
	return health == null or not health.is_dead()


## Equipamento vestido ou aparência mudou: soma os bônus e troca o golpe pelo da arma (sem arma:
## o golpe desarmado de `stats`); as auras vêm do que APARECE (transmog, ADR-030), sem repetir
## a mesma aura. Vale antes de entrar na árvore (aplicado no `_ready`).
func apply_equipment(equipment: Equipment) -> void:
	_equipment_bonuses = StatBonuses.total(equipment.equipped())
	var weapon := equipment.weapon()
	_weapon_attack = weapon.attack if weapon else null
	_update_bonuses()
	if is_node_ready() and attacker:
		attacker.set_attack(_weapon_attack if _weapon_attack else stats.unarmed_attack)
	var shown: Array[AuraData] = []
	for item in equipment.shown_items():
		if item.aura and item.aura not in shown:
			shown.append(item.aura)
	if shown != auras:
		auras = shown
		auras_changed.emit()


## Equipamento ou efeitos mudaram: recalcula os bônus (vida máxima e defesa, já na árvore).
func _update_bonuses() -> void:
	bonuses = _total_bonuses()
	if is_node_ready() and health:
		health.set_limits(_max_health(), _defense())


func _total_bonuses() -> StatBonuses:
	var total := StatBonuses.new()
	total.add(_equipment_bonuses)
	if status_effects:
		total.add(status_effects.effects.bonuses())
	return total


func move_speed() -> float:
	return stats.move_speed * maxf(1.0 + bonuses.move_speed_percent / 100.0, MIN_SPEED_FACTOR)


## Raio do ímã de itens no chão (ver `Pickup`).
func pickup_radius() -> float:
	return stats.pickup_radius + bonuses.pickup_radius


func _max_health() -> int:
	return maxi(roundi((stats.max_health + bonuses.max_health) * max_health_multiplier), 1)


## Bônus negativos (debuffs) nunca deixam a defesa abaixo de zero.
func _defense() -> int:
	return maxi(stats.defense + bonuses.defense, 0)


func footprint_radius() -> float:
	return _footprint.radius if _footprint else 0.0


## `direction` no plano do chão; comprimento até 1 (controle analógico pode ser menor).
func set_move_intent(direction: Vector2) -> void:
	_move_intent = direction.limit_length(1.0)


## Livre para agir: vivo, sem atordoamento e sem outro ataque, salto ou lançamento em andamento.
func can_act() -> bool:
	return is_alive() and _stun_left == 0.0 and not (attacker and attacker.is_attacking()) \
		and not (slammer and slammer.is_slamming()) and not (caster and caster.is_casting())


## Pede um ataque na direção dada (plano do chão). Retorna se o ataque começou.
func request_attack(direction: Vector2) -> bool:
	if attacker == null or not is_alive() or _stun_left > 0.0 \
			or (slammer and slammer.is_slamming()) or (caster and caster.is_casting()):
		return false
	if not attacker.try_attack(direction):
		return false
	facing = direction.normalized()
	return true


## Lança a habilidade mirando em `aim` (até o ponto mirado, no plano do chão; ver
## AbilityCaster). Quem confere livro e recarga é o AbilitySync; aqui, só se o ator está livre.
## Retorna se começou.
func request_cast(ability: AbilityData, aim: Vector2) -> bool:
	if caster == null or not can_act() or not caster.try_cast(ability, aim):
		return false
	facing = aim.normalized()
	return true


## Lançamento decidido em outro computador (host ou dono que previu): como `play_remote_attack`,
## ignora o atordoamento, que pode diferir por milissegundos entre computadores.
func play_remote_cast(ability: AbilityData, aim: Vector2) -> void:
	if caster and is_alive() and caster.try_cast(ability, aim):
		facing = aim.normalized()


## Pede um salto com queda em `landing` (tela; ver SlamAttacker). Retorna se começou.
func request_slam(landing: Vector2) -> bool:
	if slammer == null or not is_alive() or _stun_left > 0.0 \
			or (attacker and attacker.is_attacking()):
		return false
	return slammer.try_slam(landing)


## Pede para coletar o ponto de coleta mais próximo ao alcance. Retorna se começou.
func request_gather() -> bool:
	if gatherer == null or not is_alive() or _stun_left > 0.0 \
			or (attacker and attacker.is_attacking()):
		return false
	if not gatherer.try_gather(gatherer.find_node()):
		return false
	face_towards(gatherer.current_node().position)
	return true


## Vira para um ponto da tela (ex.: o que está coletando).
func face_towards(screen_point: Vector2) -> void:
	var direction := Iso.screen_to_ground(screen_point - position)
	if not direction.is_zero_approx():
		facing = direction.normalized()


## Ataque decidido em outro computador (ver NetSync): ignora atordoamento, que pode diferir
## por alguns milissegundos entre computadores.
func play_remote_attack(direction: Vector2, tolerance: float) -> void:
	if attacker and is_alive() and attacker.try_attack(direction, tolerance):
		facing = direction.normalized()


## Host: um ataque deste ator acertou `target` (dano já aplicado): aplica os efeitos do golpe.
func apply_hit_effects(target: Character) -> void:
	apply_effects(target, on_hit_effects)


## Host: um golpe deste ator (golpe, salto ou habilidade) acertou `target`: aplica `effects`.
func apply_effects(target: Character, effects: Array[StatusEffectData]) -> void:
	if target.status_effects:
		for effect in effects:
			target.status_effects.apply(effect, player_id)


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


## Host: o personagem foi recriado em outra região (viagem). Este fica parado, invisível e
## sem colisão até ser liberado, ignorando mensagens atrasadas do dono.
func retire() -> void:
	if gatherer:
		gatherer.stop()
	process_mode = PROCESS_MODE_DISABLED
	visible = false
	collision_layer = 0
	collision_mask = 0
	remove_from_group(OccluderFade.VIEWER_GROUP)
	if net:
		net.retire()


func _physics_process(delta: float) -> void:
	if net and not net.is_simulating():
		return
	_stun_left = maxf(_stun_left - delta, 0.0)
	var intent := _move_intent if is_alive() and _stun_left == 0.0 else Vector2.ZERO
	var speed := move_speed() * Iso.move_speed_factor(intent, stats.horizontal_speed_factor)
	if attacker:
		speed *= attacker.move_multiplier()
	if slammer:
		speed *= slammer.move_multiplier()
	if caster:
		speed *= caster.move_multiplier()
	var rate := stats.acceleration if intent != Vector2.ZERO else stats.friction
	ground_velocity = ground_velocity.move_toward(intent * speed, rate * delta)
	velocity = Iso.ground_to_screen(ground_velocity)
	move_and_slide()
	# Depois de deslizar numa colisão, a velocidade real pode ter mudado.
	ground_velocity = Iso.screen_to_ground(velocity)
	if intent != Vector2.ZERO and not (attacker and attacker.is_attacking()) \
			and not (caster and caster.is_casting()):
		facing = intent.normalized()


func _on_damaged(info: DamageInfo) -> void:
	if info.periodic:
		return  # veneno e afins não atordoam, não empurram nem interrompem
	if gatherer:
		gatherer.stop()  # apanhar interrompe a coleta
	_stun_left = stats.hit_stun
	ground_velocity = info.direction * info.knockback * (1.0 - stats.knockback_resistance)
	if attacker:
		attacker.interrupt()


func _on_died() -> void:
	# Corpo deixa de ser alvo e de bloquear; quem o criou decide remover ou reviver.
	collision_layer = 0
	if attacker:
		attacker.stop()  # sem bote "fantasma" depois da morte
	if slammer:
		slammer.stop()
	if gatherer:
		gatherer.stop()
	if caster:
		caster.stop()
	died.emit(self)
