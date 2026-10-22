class_name OccluderFade
extends Area2D
## Deixa um objeto alto semitransparente enquanto um observador (o personagem do jogador
## local) está ATRÁS dele, para o jogador nunca perder o próprio personagem de vista.
## A zona de detecção é calculada a partir do sprite; objetos baixos demais para esconder
## alguém (ex.: pedras) desligam o efeito sozinhos. Só apresentação: não afeta regras.

## Grupo dos nós cuja visibilidade importa nesta tela (o personagem do jogador local).
const VIEWER_GROUP := &"occlusion_viewer"
## Sprites mais baixos que isto não escondem um personagem.
const MIN_HIDING_HEIGHT := 20.0
## Folga em volta do desenho para o efeito começar antes de o personagem sumir.
const MARGIN := 4.0

@export var sprite: Sprite2D
@export_range(0.0, 1.0) var faded_alpha: float = 0.45
@export var fade_time: float = 0.15

var _viewers: Array[Node2D] = []
var _faded := false
var _tween: Tween


func _ready() -> void:
	var rect := sprite.get_rect()
	if rect.size.y < MIN_HIDING_HEIGHT:
		queue_free()
		return
	collision_layer = 0
	collision_mask = PhysicsLayers.ACTORS
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = rect.grow(MARGIN).size
	var zone := CollisionShape2D.new()
	zone.shape = shape
	zone.position = rect.get_center()
	add_child(zone)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(VIEWER_GROUP):
		_viewers.append(body)
		set_physics_process(true)


func _on_body_exited(body: Node2D) -> void:
	_viewers.erase(body)
	if _viewers.is_empty():
		set_physics_process(false)
		_set_faded(false)


## Só roda enquanto há observador na zona: "atrás" = pés acima da base do objeto.
func _physics_process(_delta: float) -> void:
	_set_faded(_viewers.any(func(v: Node2D) -> bool: return v.global_position.y < global_position.y))


func _set_faded(faded: bool) -> void:
	if faded == _faded:
		return
	_faded = faded
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(sprite, "modulate:a", faded_alpha if faded else 1.0, fade_time)
