class_name Projectile
extends Node2D
## Projétil de uma habilidade (ADR-026) ou de uma arma à distância (ADR-033): voa em linha reta no
## plano do chão até acertar o primeiro inimigo de quem o soltou ou chegar ao alcance. Em todo
## computador ele voa e some ao tocar alguém (apresentação); só no host o toque causa dano e aplica
## os efeitos. Mora na camada de entidades da região (ordem de desenho pelos pés), mas não é
## entidade: nada dele passa pela rede. Ainda atravessa árvores e pedras (pendência da ADR-026).

## Altura do voo acima do chão, em pixels de tela (meio do corpo).
const HEIGHT := 9.0
const CORE_RADIUS := 2.0
const GLOW_RADIUS := 4.0
const SHADOW_SIZE := Vector2(4.0, 1.5)
const SHADOW_COLOR := Color(0.05, 0.04, 0.1, 0.35)
## Canto de cima à esquerda da imagem do orbe, relativo aos pés.
const ORB_ORIGIN := Vector2(-GLOW_RADIUS, -HEIGHT - GLOW_RADIUS)
## Flecha: comprimento em pixels (ponta e penas inclusas) e quantas direções têm imagem própria
## (pixel art não gira: cada direção é pintada pixel a pixel, sem borrar).
const ARROW_LENGTH := 9
const ARROW_DIRECTIONS := 16
const ARROW_HALF := ceili(ARROW_LENGTH / 2.0)
const ARROW_ORIGIN := Vector2(-ARROW_HALF, -HEIGHT - ARROW_HALF)
const TRAIL_PARTICLES := 6
const TRAIL_LIFETIME := 0.25
const IMPACT_PARTICLES := 8
const IMPACT_SPEED := 40.0
const IMPACT_LIFETIME := 0.3

## Imagens dos projéteis (sombra + corpo), pintadas na primeira vez que cada uma aparece: orbe, uma
## por dado; flecha, uma por dado e direção. Três círculos desenhados por projétil viravam 3
## chamadas de desenho cada (polígonos não se agrupam no renderizador Compatibility): 1000
## projéteis custavam ~7 ms só de desenho (Etapa H). Uma textura por projétil se agrupa com as
## outras iguais.
static var _images := {}

var _data: ProjectileData
var _damage := 0
var _knockback := 0.0
var _effects: Array[StatusEffectData] = []
var _caster: WeakRef
var _direction := Vector2.RIGHT
var _traveled := 0.0
var _image: ImageTexture
var _image_origin := Vector2.ZERO


## Solta um projétil de `caster` na região dele, na direção `direction` (chão). Dano, recuo e
## efeitos são de quem soltou (habilidade ou arma).
static func launch(data: ProjectileData, caster: Character, direction: Vector2, damage: int,
		knockback: float, effects: Array[StatusEffectData]) -> void:
	var region := Region.of(caster)
	if region == null:
		return
	var projectile := Projectile.new()
	projectile.setup(data, caster, direction, damage, knockback, effects)
	region.entities.add_child(projectile)


func setup(data: ProjectileData, caster: Character, direction: Vector2, damage: int,
		knockback: float, effects: Array[StatusEffectData]) -> void:
	_data = data
	_damage = damage
	_knockback = knockback
	_effects = effects
	_caster = weakref(caster)
	_direction = direction.normalized()
	# Nasce na borda da pegada, à frente: não atravessa o corpo de quem soltou.
	position = caster.position + Iso.ground_to_screen(_direction * caster.footprint_radius())


func _ready() -> void:
	if _data.look == ProjectileData.Look.ARROW:
		var turn := _arrow_turn(_direction)
		_image = _cached([_data, turn], _paint_arrow.bind(_data, turn))
		_image_origin = ARROW_ORIGIN
	else:
		_image = _cached([_data], _paint_orb.bind(_data))
		_image_origin = ORB_ORIGIN
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
	trail.color_ramp = SparkBurst.fade(_data.glow_color)
	add_child(trail)


func _physics_process(delta: float) -> void:
	var caster := _caster.get_ref() as Character
	if caster == null:
		queue_free()  # quem soltou saiu (viagem, desconexão): o projétil some junto
		return
	var step := _data.speed * delta
	position += Iso.ground_to_screen(_direction * step)
	_traveled += step
	var targets := ActorQuery.hostiles_near(caster, position, 0.0, _data.hit_radius)
	if not targets.is_empty():
		_hit(caster, targets[0])
	elif _traveled >= _data.max_range:
		queue_free()


func _hit(caster: Character, target: Character) -> void:
	if multiplayer.is_server():
		var info := DamageInfo.create(_damage, _direction, _knockback, caster.entity_id,
			caster.player_id)
		if target.health.apply_damage(info):
			caster.apply_effects(target, _effects)
	# Faíscas no ponto do impacto (ficam na região depois que o projétil some).
	SparkBurst.spawn(get_parent(), position + Vector2(0, -HEIGHT), _data.color,
		IMPACT_PARTICLES, IMPACT_SPEED, IMPACT_LIFETIME)
	queue_free()


func _draw() -> void:
	draw_texture(_image, _image_origin)


static func _cached(key: Array, paint: Callable) -> ImageTexture:
	if not _images.has(key):
		_images[key] = ImageTexture.create_from_image(paint.call())
	return _images[key]


## Qual das `ARROW_DIRECTIONS` imagens mostra o voo em `direction` (chão), pela direção NA TELA.
static func _arrow_turn(direction: Vector2) -> int:
	var on_screen := Iso.ground_to_screen(direction)
	return posmod(roundi(on_screen.angle() / TAU * ARROW_DIRECTIONS), ARROW_DIRECTIONS)


## Acende cada pixel cujo centro cai dentro da forma (o mesmo critério de `draw_circle`), na
## ordem sombra → brilho → núcleo.
static func _paint_orb(data: ProjectileData) -> Image:
	var size := Vector2i(ceili(GLOW_RADIUS * 2.0), ceili(HEIGHT + GLOW_RADIUS + SHADOW_SIZE.y))
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var orb := Vector2(0, -HEIGHT)
	for y in size.y:
		for x in size.x:
			var point := ORB_ORIGIN + Vector2(x, y) + Vector2.ONE * 0.5
			var color := Color.TRANSPARENT
			if (point / SHADOW_SIZE).length() <= 1.0:
				color = color.blend(SHADOW_COLOR)
			if point.distance_to(orb) <= GLOW_RADIUS:
				color = color.blend(data.glow_color)
			if point.distance_to(orb) <= CORE_RADIUS:
				color = color.blend(data.color)
			image.set_pixel(x, y, color)
	return image


## Sombra no chão e uma linha de pixels na direção `turn`: penas (2 px) → haste → ponta (2 px).
static func _paint_arrow(data: ProjectileData, turn: int) -> Image:
	var side := ARROW_HALF * 2 + 1
	var size := Vector2i(side, ceili(HEIGHT + ARROW_HALF + SHADOW_SIZE.y))
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var point := ARROW_ORIGIN + Vector2(x, y) + Vector2.ONE * 0.5
			if (point / SHADOW_SIZE).length() <= 1.0:
				image.set_pixel(x, y, SHADOW_COLOR)
	var along := Vector2.from_angle(turn * TAU / ARROW_DIRECTIONS)
	var middle := Vector2(0, -HEIGHT) - ARROW_ORIGIN
	for i in ARROW_LENGTH:
		var pixel := (middle + along * (i - (ARROW_LENGTH - 1) / 2.0)).round()
		var tip_or_feathers := i < 2 or i >= ARROW_LENGTH - 2
		image.set_pixelv(Vector2i(pixel), data.glow_color if tip_or_feathers else data.color)
	return image
