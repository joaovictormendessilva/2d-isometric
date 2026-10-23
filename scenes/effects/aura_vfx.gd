class_name AuraVfx
extends Node2D
## Auras do ator (só apresentação, ADR-029): para cada `AuraData` em `body.auras`, a metade de
## trás do anel fica neste nó (logo depois da sombra, antes do sprite) e a metade da frente com as
## faíscas fica num nó irmão criado por último (por cima do sprite). Fica dentro do Visual, então
## pisca e some junto com o ator. Sem aura, não roda nada por quadro.

## Fração do anel ocupada pela nuvem de onde as faíscas sobem.
const SPARKLE_AREA := 0.8
## Lado das faíscas em pixels (1 px some na grama).
const SPARKLE_SIZE := 2.0
## Fração da vida em que a faísca termina de acender (pisca ao surgir e some devagar).
const SPARKLE_FADE_IN := 0.2

@export var body: Character

var _front: Node2D


func _ready() -> void:
	_front = Node2D.new()
	_front.name = "AuraFront"
	# Por cima do sprite (o Body é irmão criado depois, nas cenas que herdam o ator): entra quando
	# o pai termina de montar os filhos. Não com call_deferred: se o ator fosse liberado antes,
	# o nó ficaria solto na memória ("leaked at exit").
	get_parent().ready.connect(get_parent().add_child.bind(_front), CONNECT_ONE_SHOT)
	body.auras_changed.connect(_rebuild)
	VfxQuality.shared().changed.connect(_rebuild)
	_rebuild()


## Quantas auras aparecem agora (testes).
func aura_count() -> int:
	return get_child_count()


## Refaz tudo: auras trocam raramente (vestir ou tirar) e o nível de qualidade, quase nunca.
func _rebuild() -> void:
	for layer in get_children() + _front.get_children():
		layer.queue_free()
		layer.get_parent().remove_child(layer)
	for aura in body.auras:
		add_child(_ring(aura, AuraRing.Half.BACK))
		_front.add_child(_ring(aura, AuraRing.Half.FRONT))
		var sparkles := _sparkles(aura)
		if sparkles:
			_front.add_child(sparkles)


func _ring(aura: AuraData, half: AuraRing.Half) -> AuraRing:
	var ring := AuraRing.new()
	ring.setup(aura, half)
	return ring


## Nulo se a aura não tem faíscas ou o teto de partículas do computador já foi alcançado.
func _sparkles(aura: AuraData) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	if not VfxQuality.shared().claim(particles, aura.sparkle_amount):
		particles.free()
		return null
	particles.lifetime = aura.sparkle_lifetime
	particles.randomness = 0.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Iso.ground_to_screen(Vector2.ONE * aura.radius * SPARKLE_AREA)
	particles.direction = Vector2.UP
	particles.spread = 10.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = aura.sparkle_rise_speed * 0.5
	particles.initial_velocity_max = aura.sparkle_rise_speed
	particles.scale_amount_min = SPARKLE_SIZE
	particles.scale_amount_max = SPARKLE_SIZE
	var twinkle := SparkBurst.fade(aura.sparkle_color)
	twinkle.set_color(0, Color(aura.sparkle_color, 0.0))
	twinkle.add_point(SPARKLE_FADE_IN, aura.sparkle_color)
	particles.color_ramp = twinkle
	return particles
