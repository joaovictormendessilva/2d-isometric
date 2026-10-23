class_name StatusEffectVfx
extends Node2D
## Partículas dos efeitos ativos no ator (só apresentação, ADR-025): um emissor pequeno por efeito
## com `vfx_amount` > 0, nas cores e velocidades dos dados. Fica dentro do Visual do ator, então
## pisca, avermelha e some junto com ele. O tamanho do corpo vem do sprite "Body" irmão.
## Bolhas no corpo acompanham o ator; faíscas nos pés ficam para trás (rastro de rapidez).

## Teto por efeito, qualquer que seja o dado (níveis de qualidade: Etapa G3).
const MAX_PARTICLES := 8
const LIFETIME := 1.0
## Lado das partículas em pixels (quadradinhos sem textura; 2 px lê na escala do jogo).
const PARTICLE_SIZE := 2.0
## Fração da vida em que a partícula começa a sumir (antes disso, cor cheia).
const FADE_START := 0.6
## Área dos pés: meia largura e meia altura em pixels.
const FEET_EXTENTS := Vector2(5.0, 1.0)
## Margem tirada da caixa do sprite (contorno e espaço vazio do quadro).
const BODY_INSET := 3.0

@export var body: Character

var _emitters: Dictionary[StringName, CPUParticles2D] = {}
var _body_rect := Rect2(-6, -16, 12, 14)


func _ready() -> void:
	var sprite := get_parent().get_node_or_null("Body") as Sprite2D
	if sprite:
		_body_rect = sprite.get_rect().grow(-BODY_INSET)
	# Desenhar por cima do corpo (o Body é irmão criado depois, nas cenas que herdam o ator).
	get_parent().move_child.call_deferred(self, -1)
	if body.status_effects:
		body.status_effects.effects.changed.connect(_sync)
		_sync()


## Quantos emissores há agora (testes).
func emitter_count() -> int:
	return _emitters.size()


func _sync() -> void:
	var active: Dictionary[StringName, StatusEffectData] = {}
	for entry in body.status_effects.effects.entries():
		if entry.data.vfx_amount > 0:
			active[entry.data.id] = entry.data
	for id: StringName in _emitters.keys():
		if not active.has(id):
			_emitters[id].queue_free()
			_emitters.erase(id)
	for id in active:
		if not _emitters.has(id):
			_emitters[id] = _create(active[id])


func _create(effect: StatusEffectData) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = clampi(effect.vfx_amount, 1, MAX_PARTICLES)
	particles.lifetime = LIFETIME
	particles.randomness = 0.5
	particles.local_coords = not effect.vfx_at_feet
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	if effect.vfx_at_feet:
		particles.emission_rect_extents = FEET_EXTENTS
	else:
		particles.position = _body_rect.get_center()
		particles.emission_rect_extents = _body_rect.size / 2.0
	particles.direction = Vector2.UP
	particles.spread = 15.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = effect.vfx_rise_speed * 0.6
	particles.initial_velocity_max = effect.vfx_rise_speed
	particles.scale_amount_min = PARTICLE_SIZE
	particles.scale_amount_max = PARTICLE_SIZE
	var fade := Gradient.new()
	fade.set_color(0, effect.vfx_color)
	fade.set_color(1, Color(effect.vfx_color, 0.0))
	fade.add_point(FADE_START, effect.vfx_color)
	particles.color_ramp = fade
	add_child(particles)
	return particles
