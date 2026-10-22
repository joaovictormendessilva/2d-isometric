class_name Health
extends Node
## Vida de uma entidade. Só o host chama `apply_damage`/`restore_full`/`set_immune`; na rede,
## os clientes recebem o resultado pelas funções `replicate_*` (via NetSync). Os sinais
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


## Muda vida máxima e defesa sem curar (equipamento vestido/tirado). A vida atual acompanha o
## ganho de máximo e nunca passa do novo máximo.
func set_limits(p_max_health: int, p_defense: int) -> void:
	var gained := maxi(p_max_health - max_health, 0)
	max_health = p_max_health
	defense = p_defense
	if not is_dead():
		current = clampi(current + gained, 1, max_health)
	changed.emit(current, max_health)


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


## Retorna se o dano foi aplicado (falha se já morto, invulnerável ou imune). Fora do host
## não faz nada: cliente nenhum decide dano, nem por engano.
func apply_damage(info: DamageInfo) -> bool:
	if not multiplayer.is_server() or is_dead() or is_invulnerable():
		return false
	if _immune:
		blocked.emit(info)
		return false
	info.amount = CombatRules.mitigate(info.amount, defense)
	_take(info)
	return true


func restore_full() -> void:
	current = max_health
	_invulnerable_left = 0.0
	changed.emit(current, max_health)


## Cliente: aplica um dano que o host já decidiu (`info.amount` é o valor final).
func replicate_damage(info: DamageInfo) -> void:
	if not is_dead():
		_take(info)


## Cliente: o host é a fonte da verdade sobre a vida (corrige qualquer divergência).
func replicate_current(value: int) -> void:
	value = clampi(value, 0, max_health)
	if value != current:
		current = value
		changed.emit(current, max_health)


func replicate_blocked() -> void:
	blocked.emit(DamageInfo.new())


func _take(info: DamageInfo) -> void:
	current = maxi(current - info.amount, 0)
	_invulnerable_left = invulnerability_time
	damaged.emit(info)
	changed.emit(current, max_health)
	if is_dead():
		died.emit(info)


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
