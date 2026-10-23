class_name AreaBlast
extends Node2D
## Habilidade em área (ADR-026, G2d): aviso no chão no ponto mirado, na cor da habilidade, que
## enche até o impacto; no impacto, onda e faíscas. Em todo computador o aviso e o impacto
## aparecem (apresentação); só no host o impacto fere e aplica os efeitos. Mora na camada de
## efeitos do chão da região, mas não é entidade: nada dele passa pela rede. Se quem lançou sai
## antes do impacto (viagem, desconexão), some sem ferir, como o projétil.

## Miolo do aviso: a cor clara da habilidade, translúcida (o contorno, na cor do brilho, vai cheio).
## A cor do brilho translúcida some no chão (violeta sobre a grama vira cinza).
const FILL_ALPHA := 0.55
const BURST_PARTICLES := 16
const BURST_SPEED := 90.0
const BURST_LIFETIME := 0.35
## Faíscas um pouco acima do chão, para não sumirem sob os pés de quem está no meio.
const BURST_HEIGHT := 4.0

var _ability: AbilityData
var _caster: WeakRef
var _elapsed := 0.0
var _telegraph: GroundTelegraph


## `at`: ponto de impacto (tela).
func setup(ability: AbilityData, caster: Character, at: Vector2) -> void:
	_ability = ability
	_caster = weakref(caster)
	position = at.round()


func _ready() -> void:
	_telegraph = GroundTelegraph.new()
	_telegraph.setup(Vector2.ZERO, _ability.area_radius, _ability.vfx_glow_color,
		Color(_ability.vfx_color, FILL_ALPHA))
	add_child(_telegraph)


func _physics_process(delta: float) -> void:
	var caster := _caster.get_ref() as Character
	if caster == null:
		queue_free()
		return
	_elapsed += delta
	_telegraph.set_progress(_elapsed / _ability.area_delay)
	if _elapsed >= _ability.area_delay:
		_detonate(caster)


func _detonate(caster: Character) -> void:
	set_physics_process(false)
	if multiplayer.is_server():
		for target in AreaStrike.hit(caster, position, _ability.area_radius, _ability.damage,
				_ability.knockback):
			caster.apply_effects(target, _ability.hit_effects)
	# Faíscas na camada das entidades (o aviso fica embaixo de todos; elas, não).
	var region := Region.of(self)
	if region:
		SparkBurst.spawn(region.entities, position + Vector2(0, -BURST_HEIGHT),
			_ability.vfx_glow_color,
			BURST_PARTICLES, BURST_SPEED, BURST_LIFETIME)
	# A onda é do aviso; quando ela some, o aviso e este nó saem juntos.
	_telegraph.burst()
	_telegraph.tree_exited.connect(queue_free)
