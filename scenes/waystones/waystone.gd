class_name Waystone
extends StaticBody2D
## Pedra de portal (ADR-037). Criada pelo host via EntitySpawner quando a região carrega, igual em
## todos os computadores. Acesa para quem já a ativou: cada computador a mostra como o jogador
## LOCAL a deixou. Ativar e viajar são pedidos ao host (PlayerStateSync).

const GROUP := &"waystones"
## Distância (chão) dos pés do jogador até a pedra para usá-la.
const INTERACT_RANGE := 32.0
const FOOTPRINT_RADIUS := 7.0
## Onde aparece quem chega por ela: na frente (px de tela).
const ARRIVAL_OFFSET := Vector2(0, 10)
## Faíscas arcanas ao acender (só apresentação).
const SPARK_COLOR := Color("b48ae8")
const SPARK_AMOUNT := 16
const SPARK_SPEED := 45.0
const SPARK_TIME := 0.6
const SPARK_HEIGHT := 20.0
## Viajar: segundos parado na pedra antes de partir (dano ou andar interrompem).
const CHANNEL_TIME := 1.0

@export var dormant_texture: Texture2D
@export var lit_texture: Texture2D

var data: WaystoneData
## Lista de pedras ativadas do jogador LOCAL (Callable → WaystoneLog, ou null enquanto ele não
## chegou a este computador).
var local_log := Callable()
var _lit := false

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	($Footprint as Footprint).radius = FOOTPRINT_RADIUS
	add_to_group(GROUP)
	_show()


## Espera a lista do jogador local existir: acende se ele já ativou e passa a ouvir as ativações.
func _process(_delta: float) -> void:
	var known: WaystoneLog = local_log.call() if local_log.is_valid() else null
	if known == null:
		return
	set_process(false)
	if known.knows(data.id):
		light(true)
	known.activated.connect(func(waystone_id: StringName, is_new: bool) -> void:
		if waystone_id == data.id:
			light(not is_new))


## Os pés em `at` estão perto o bastante para usar a pedra?
func reaches(at: Vector2) -> bool:
	return Iso.ground_distance(position, at) <= INTERACT_RANGE


func arrival_position() -> Vector2:
	return position + ARRIVAL_OFFSET


func is_lit() -> bool:
	return _lit


## Acende (o jogador local a ativou) com faíscas; `quietly` (já estava ativada: save, viagem), sem.
func light(quietly: bool) -> void:
	if _lit:
		return
	_lit = true
	_show()
	if not quietly:
		SparkBurst.spawn(self, Vector2(0.0, -SPARK_HEIGHT), SPARK_COLOR, SPARK_AMOUNT, SPARK_SPEED,
			SPARK_TIME)


func _show() -> void:
	var texture := lit_texture if _lit else dormant_texture
	_sprite.texture = texture
	_sprite.offset = RewardChestData.sprite_offset(texture)
