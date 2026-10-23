class_name HostRequests
extends Node
## Base dos nós de estado por jogador que só o host decide (PlayerStateSync, AbilitySync): o dono
## PEDE ao host (`_request`), o host confere e aplica, e responde só ao dono (`_send`). Offline (e
## no host) o pedido é aplicado na hora. Quem herda define as RPCs; o nó precisa ter o mesmo
## caminho em todos os computadores.


func _request(method: StringName, args: Array) -> void:
	if multiplayer.is_server():
		callv(method, args)  # host (ou offline): aplica direto
	else:
		callv(&"rpc_id", [1, method] + args)


func _send(player_id: int, method: StringName, args: Array) -> void:
	if player_id in multiplayer.get_peers():
		callv(&"rpc_id", [player_id, method] + args)


## Quem fez o pedido que está sendo atendido (no host, sem rede, é ele mesmo).
func _requester() -> int:
	var sender := multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()
