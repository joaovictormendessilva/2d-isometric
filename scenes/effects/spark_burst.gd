class_name SparkBurst
extends RefCounted
## Faíscas de uma vez só que se espalham em volta de um ponto e somem (impacto de habilidade).
## Só apresentação; cada uma se remove ao terminar.


static func spawn(parent: Node, at: Vector2, color: Color, amount: int, speed: float,
		lifetime: float) -> void:
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = amount
	burst.lifetime = lifetime
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = speed * 0.5
	burst.initial_velocity_max = speed
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.0
	burst.color_ramp = fade(color)
	burst.finished.connect(burst.queue_free)
	parent.add_child(burst)
	burst.emitting = true


## Da cor cheia à transparente (rastros e faíscas).
static func fade(color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	return gradient
