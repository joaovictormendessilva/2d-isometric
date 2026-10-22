class_name Health
extends Node
## Vida de uma entidade. Só a autoridade chama `apply_damage`/`restore_full`; os sinais
## alimentam apresentação (números, flash, HUD) e regras (recuo, morte, drops).

signal damaged(info: DamageInfo)  ## `info.amount` já é o dano final, depois da defesa.
signal died(info: DamageInfo)
signal changed(current: int, maximum: int)
signal blocked(info: DamageInfo)  ## Golpe recusado por imunidade (ex.: criatura voltando para casa).
signal immunity_changed(immune: bool)

var max_health := 1
var current := 1
var defense := 0
var invulnerability_time := 0.0

var _invulnerable_left := 0.0
var _immune := false


func setup(p_max_health: int, p_defense: int, p_invulnerability_time: float) -> void:
	max_health = p_max_health
	defense = p_defense
	invulnerability_time = p_invulnerability_time
	restore_full()


func is_dead() -> bool:
	return current <= 0


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Imunidade por regra de jogo, sem prazo (diferente da invulnerabilidade curta após um golpe).
func is_immune() -> bool:
	return _immune


func set_immune(value: bool) -> void:
	if value != _immune:
		_immune = value
		immunity_changed.emit(value)


## Retorna se o dano foi aplicado (falha se já morto, invulnerável ou imune).
func apply_damage(info: DamageInfo) -> bool:
	if is_dead() or is_invulnerable():
		return false
	if _immune:
		blocked.emit(info)
		return false
	info.amount = CombatRules.mitigate(info.amount, defense)
	current = maxi(current - info.amount, 0)
	_invulnerable_left = invulnerability_time
	damaged.emit(info)
	changed.emit(current, max_health)
	if is_dead():
		died.emit(info)
	return true


func restore_full() -> void:
	current = max_health
	_invulnerable_left = 0.0
	changed.emit(current, max_health)


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
