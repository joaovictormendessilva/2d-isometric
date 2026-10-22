class_name HostBroadcast
extends RefCounted
## Mensagens do host sobre UM nó, só para os clientes que já têm esse nó (ADR-012).
## O cliente avisa que tem o nó pedindo o estado completo (`request_from_host`); o host
## registra o computador (`add_peer`) e responde. Assim nenhuma mensagem chega a um nó que
## ainda não existe no cliente (recém-criado, ou cliente entrando no meio da partida).
## Usado por NetSync (atores) e ResourceNode (pontos de coleta).

var _node: Node
var _peers: Dictionary[int, bool] = {}


## Chame no `_ready` do nó (precisa estar na árvore para conhecer a rede).
func _init(node: Node) -> void:
	_node = node
	if NetRules.is_online(node.multiplayer) and node.multiplayer.is_server():
		node.multiplayer.peer_disconnected.connect(_on_peer_disconnected)


## Host: registra o computador. Retorna falso se ele já estava registrado (pedido repetido).
func add_peer(peer: int) -> bool:
	if _peers.has(peer):
		return false
	_peers[peer] = true
	return true


## Host: chama a RPC `method` em todos os clientes registrados, exceto `except_peer`.
func send(method: StringName, args: Array, except_peer: int = 0) -> void:
	if not NetRules.is_online(_node.multiplayer) or not _node.multiplayer.is_server():
		return
	for peer in _peers:
		if peer != except_peer:
			_node.callv(&"rpc_id", [peer, method] + args)


## Cliente: chama a RPC `method` no host assim que estiver conectado (os nós da região
## existem antes da conexão terminar).
static func request_from_host(node: Node, method: StringName) -> void:
	var api := node.multiplayer
	if not NetRules.is_online(api) or api.is_server():
		return
	if api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		node.rpc_id(1, method)
	else:
		# Callable do próprio nó: some sozinho se o nó for liberado antes da conexão.
		api.connected_to_server.connect(Callable(node, &"rpc_id").bind(1, method), CONNECT_ONE_SHOT)


func _on_peer_disconnected(peer: int) -> void:
	_peers.erase(peer)
