class_name BossEventData
extends Resource
## Evento de chefe errante (ADR-036): de tempos em tempos o chefe surge num ponto livre de uma
## das regiões abertas onde há jogadores, com aviso para todos; se ninguém o derrota em
## `stay_time`, ele vai embora. Quem o feriu ganha o baú de recompensa (um para cada um abrir).
## Um arquivo por evento em `data/boss_events/`.

@export var id: StringName
## Cena da criatura (com os dados dela: vida, ataques, drops normais).
@export var monster_scene: PackedScene
## Regiões onde o evento pode acontecer (ids de `data/regions/`; nunca dungeons).
@export var regions: Array[StringName] = []
@export_group("Tempo (s)")
## Intervalo entre o fim de um evento (ou o começo da partida) e o próximo: sorteado entre os dois.
@export var interval_min: float = 600.0
@export var interval_max: float = 1200.0
## Quanto tempo o chefe fica antes de ir embora (se não estiver lutando).
@export var stay_time: float = 300.0
@export_group("Recompensa")
## Baú que surge onde o chefe caiu, só para quem o feriu.
@export var reward_chest: RewardChestData

var _boss_data: MonsterData


## Dados da criatura (nome no aviso), lidos da cena na primeira vez.
func boss_data() -> MonsterData:
	if _boss_data == null:
		var boss := monster_scene.instantiate()
		_boss_data = boss.get(&"data")
		boss.free()
	return _boss_data
