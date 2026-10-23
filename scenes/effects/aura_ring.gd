class_name AuraRing
extends Node2D
## Uma metade (a de trás ou a da frente) do anel de uma aura no chão (ADR-029). As duas metades
## ficam em lados opostos do corpo para dar volume na perspectiva isométrica (ADR-007): a de trás
## é desenhada antes do sprite, a da frente depois. O giro e o brilho andam em passos
## (`STEPS_PER_SECOND`), como animação de pixel art; a imagem de cada passo é pintada uma vez e
## dividida por todos os atores com a mesma aura (`AuraRingImage`). As duas metades usam o mesmo
## relógio, então ficam sempre em fase.

enum Half { BACK, FRONT }

const STEPS_PER_SECOND := 12.0

var _image: AuraRingImage


func setup(aura: AuraData, half: Half) -> void:
	_image = AuraRingImage.shared(aura, half)


## Tempo da animação de todas as auras (mesmo relógio para as duas metades).
static func clock() -> float:
	return Time.get_ticks_msec() / 1000.0


## A textura é atualizada no lugar, então o desenho não precisa ser refeito a cada passo.
func _process(_delta: float) -> void:
	_image.show_step(floori(AuraRing.clock() * STEPS_PER_SECOND))


func _draw() -> void:
	draw_texture(_image.texture, -Vector2(_image.offset))
