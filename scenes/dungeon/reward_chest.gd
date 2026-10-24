class_name RewardChest
extends StaticBody2D
## Baú de recompensa de uma dungeon (ADR-032). Criado pelo host via EntitySpawner, igual em todos
## os computadores. Cada jogador abre o seu uma vez: o host guarda quem já abriu e manda ao dono
## o baú aberto (cada computador mostra o baú como o jogador LOCAL o deixou). Quem sorteia e
## solta a recompensa é o host (PlayerStateSync).

const GROUP := &"reward_chests"
## Faíscas douradas ao surgir e ao abrir (só apresentação).
const SPARK_COLOR := Color("f6dc7a")
const SPARK_AMOUNT := 14
const SPARK_SPEED := 40.0
const SPARK_TIME := 0.5
## Altura (tela) das faíscas acima dos pés: saem da tampa.
const SPARK_HEIGHT := 8.0

var data: RewardChestData

## Host: jogadores que já abriram.
var _opened_by: Dictionary[int, bool] = {}
## O jogador local já abriu (o que este computador mostra).
var _open_here := false

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	($Footprint as Footprint).radius = data.footprint_radius
	_show(data.closed_texture)
	add_to_group(GROUP)
	_sparkle()


## Os pés em `at` estão perto o bastante para abrir?
func reaches(at: Vector2) -> bool:
	return Iso.ground_distance(position, at) <= data.interact_range


## Host: o jogador já abriu este baú?
func was_opened_by(player_id: int) -> bool:
	return _opened_by.has(player_id)


## O jogador local já abriu este baú? (Prévia do rótulo e da tecla; quem decide é o host.)
func is_open_here() -> bool:
	return _open_here


## Host: marca o baú como aberto pelo jogador e mostra isso no computador dele.
func open_for(player_id: int) -> void:
	_opened_by[player_id] = true
	if player_id == multiplayer.get_unique_id():
		_opened()
	elif player_id in multiplayer.get_peers():
		_opened.rpc_id(player_id)


@rpc("authority", "call_remote", "reliable")
func _opened() -> void:
	if _open_here:
		return
	_open_here = true
	_show(data.open_texture)
	_sparkle()


## Faíscas douradas saindo da tampa: quando o baú surge e quando abre.
func _sparkle() -> void:
	SparkBurst.spawn(self, Vector2(0.0, -SPARK_HEIGHT), SPARK_COLOR, SPARK_AMOUNT, SPARK_SPEED,
		SPARK_TIME)


func _show(texture: Texture2D) -> void:
	_sprite.texture = texture
	_sprite.offset = RewardChestData.sprite_offset(texture)
