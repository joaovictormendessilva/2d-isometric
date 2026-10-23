class_name StatusEffects
extends Node
## Buffs e debuffs do Character pai (ADR-025). Só o host aplica efeitos e cobra os ticks (dano e
## cura pela Health); os clientes recebem a lista pelo NetSync e só contam o tempo para mostrar.
## Morrer ou ficar imune (criatura voltando para casa) limpa tudo.

## Jogadores: o da sessão, posto pelo EntitySpawner antes de entrar na árvore (o personagem é
## recriado a cada viagem; os efeitos continuam). Criaturas: este, próprio.
var effects := ActiveEffects.new()

@onready var _body: Character = get_parent()


func _ready() -> void:
	# Sem efeitos, nada a contar: centenas de criaturas não pagam um processamento vazio por quadro.
	effects.changed.connect(_update_processing)
	_update_processing()
	if multiplayer.is_server() and _body.health:
		_body.health.died.connect(effects.clear.unbind(1))
		_body.health.immunity_changed.connect(func(immune: bool) -> void:
			if immune:
				effects.clear())


## Host: aplica (ou renova) o efeito. Recusa em quem está morto ou imune.
func apply(data: StatusEffectData, source_player_id: int = 0) -> bool:
	if not multiplayer.is_server() or not _body.is_alive() \
			or (_body.health and _body.health.is_immune()):
		return false
	effects.apply(data, source_player_id)
	return true


func _update_processing() -> void:
	set_physics_process(not effects.is_empty())


func _physics_process(delta: float) -> void:
	var ticked := effects.advance(delta)
	if not multiplayer.is_server() or _body.health == null:
		return
	for entry in ticked:
		if _body.health.is_dead():
			return
		if entry.data.damage_per_tick > 0:
			_body.health.apply_damage(
				DamageInfo.create_periodic(entry.data.damage_per_tick, entry.source_player_id))
		if entry.data.heal_per_tick > 0:
			_body.health.heal(entry.data.heal_per_tick)
