class_name ThreatTable
extends RefCounted
## Ameaça de cada jogador contra uma criatura (lógica pura; quem usa é o MonsterBrain, no host).
## Dano soma ameaça; perceber alguém por perto dá só uma ameaça mínima. A criatura persegue quem
## tem mais ameaça, então quem fere de longe (mago, arqueiro) também vira alvo, em vez de só
## quem está colado nela.

## Para trocar de alvo, o outro precisa passar o atual por esta margem; sem ela, dois jogadores
## com ameaça parecida fariam a criatura virar de um lado para o outro.
const SWITCH_MARGIN := 1.1
## Ameaça de quem só foi percebido (entrou no raio de agressão) sem causar dano.
const NOTICE_THREAT := 1.0

var _threat := {}  # player_id (int) -> ameaça (float)


func add(player_id: int, amount: float) -> void:
	_threat[player_id] = get_threat(player_id) + maxf(amount, NOTICE_THREAT)


## Percebeu o jogador: garante a ameaça mínima, sem somar de novo a cada vez.
func notice(player_id: int) -> void:
	_threat[player_id] = maxf(get_threat(player_id), NOTICE_THREAT)


func get_threat(player_id: int) -> float:
	return _threat.get(player_id, 0.0)


func remove(player_id: int) -> void:
	_threat.erase(player_id)


func clear() -> void:
	_threat.clear()


func is_empty() -> bool:
	return _threat.is_empty()


func player_ids() -> Array:
	return _threat.keys()


## Quem perseguir (0 = ninguém): o de maior ameaça, mas o atual só perde o posto por margem.
func pick(current_id: int) -> int:
	var best_id := 0
	var best := 0.0
	for player_id: int in _threat:
		if _threat[player_id] > best:
			best_id = player_id
			best = _threat[player_id]
	if _threat.has(current_id) and best <= _threat[current_id] * SWITCH_MARGIN:
		return current_id
	return best_id
