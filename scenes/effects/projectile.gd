class_name Projectile
extends Node2D
## Projétil de uma habilidade (ADR-026): voa em linha reta no plano do chão até acertar o primeiro
## inimigo de quem lançou ou chegar ao alcance. Em todo computador ele voa e some ao tocar alguém
## (apresentação); só no host o toque causa dano e aplica os efeitos. Mora na camada de entidades
## da região (ordem de desenho pelos pés), mas não é entidade: nada dele passa pela rede.
## Ainda atravessa árvores e pedras (pendência registrada na ADR-026).

## Altura do voo acima do chão, em pixels de tela (meio do corpo).
const HEIGHT := 9.0
const CORE_RADIUS := 2.0
const GLOW_RADIUS := 4.0
const SHADOW_SIZE := Vector2(4.0, 1.5)
const SHADOW_COLOR := Color(0.05, 0.04, 0.1, 0.35)
## Canto de cima à esquerda da imagem do projétil, relativo aos pés.
const IMAGE_ORIGIN := Vector2(-GLOW_RADIUS, -HEIGHT - GLOW_RADIUS)
const TRAIL_PARTICLES := 6
const TRAIL_LIFETIME := 0.25
const IMPACT_PARTICLES := 8
const IMPACT_SPEED := 40.0
const IMPACT_LIFETIME := 0.3

## Imagem do projétil (sombra, brilho e núcleo), uma por habilidade, pintada na primeira vez.
## Três círculos desenhados por projétil viravam 3 chamadas de desenho cada (polígonos não se
## agrupam no renderizador Compatibility): 1000 projéteis custavam ~7 ms só de desenho (Etapa H).
## Uma textura por projétil se agrupa com as outras iguais.
static var _images := {}

var _ability: AbilityData
var _caster: WeakRef
var _direction := Vector2.RIGHT
var _traveled := 0.0


func setup(ability: AbilityData, caster: Character, direction: Vector2) -> void:
	_ability = ability
	_caster = weakref(caster)
	_direction = direction.normalized()
	position = caster.position


func _ready() -> void:
	var trail := CPUParticles2D.new()
	if not VfxQuality.shared().claim(trail, TRAIL_PARTICLES):
		trail.free()  # teto de partículas alcançado: o projétil voa sem rastro
		return
	trail.position = Vector2(0, -HEIGHT)
	trail.lifetime = TRAIL_LIFETIME
	trail.local_coords = false
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 1.0
	trail.scale_amount_max = 2.0
	trail.color_ramp = SparkBurst.fade(_ability.vfx_glow_color)
	add_child(trail)


func _physics_process(delta: float) -> void:
	var caster := _caster.get_ref() as Character
	if caster == null:
		queue_free()  # quem lançou saiu (viagem, desconexão): o projétil some junto
		return
	var step := _ability.speed * delta
	position += Iso.ground_to_screen(_direction * step)
	_traveled += step
	var targets := ActorQuery.hostiles_near(caster, position, 0.0, _ability.hit_radius)
	if not targets.is_empty():
		_hit(caster, targets[0])
	elif _traveled >= _ability.max_range:
		queue_free()


func _hit(caster: Character, target: Character) -> void:
	if multiplayer.is_server():
		var info := DamageInfo.create(_ability.damage, _direction, _ability.knockback,
			caster.entity_id, caster.player_id)
		if target.health.apply_damage(info):
			caster.apply_effects(target, _ability.hit_effects)
	# Faíscas no ponto do impacto (ficam na região depois que o projétil some).
	SparkBurst.spawn(get_parent(), position + Vector2(0, -HEIGHT), _ability.vfx_color,
		IMPACT_PARTICLES, IMPACT_SPEED, IMPACT_LIFETIME)
	queue_free()


func _draw() -> void:
	draw_texture(_image_of(_ability), IMAGE_ORIGIN)


static func _image_of(ability: AbilityData) -> ImageTexture:
	if not _images.has(ability):
		_images[ability] = ImageTexture.create_from_image(_paint(ability))
	return _images[ability]


## Pinta o que antes eram três círculos: acende cada pixel cujo centro cai dentro da forma
## (o mesmo critério de `draw_circle`), na ordem sombra → brilho → núcleo.
static func _paint(ability: AbilityData) -> Image:
	var size := Vector2i(ceili(GLOW_RADIUS * 2.0), ceili(HEIGHT + GLOW_RADIUS + SHADOW_SIZE.y))
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var orb := Vector2(0, -HEIGHT)
	for y in size.y:
		for x in size.x:
			var point := IMAGE_ORIGIN + Vector2(x, y) + Vector2.ONE * 0.5
			var color := Color.TRANSPARENT
			if (point / SHADOW_SIZE).length() <= 1.0:
				color = color.blend(SHADOW_COLOR)
			if point.distance_to(orb) <= GLOW_RADIUS:
				color = color.blend(ability.vfx_glow_color)
			if point.distance_to(orb) <= CORE_RADIUS:
				color = color.blend(ability.vfx_color)
			image.set_pixel(x, y, color)
	return image
