class_name PeerGuard
extends RefCounted
## Limite de pedidos por cliente no host (ADR-013, Etapa H4): cada cliente tem uma cota que se
## recarrega com o tempo do HOST; quem a esgota está inundando o host de pedidos (programa
## adulterado) e é desconectado. Um jogador de verdade fica muito abaixo: 20 estados de
## movimento por segundo mais alguns golpes, cliques e habilidades.
##
## Vale para pedidos de ação e para os que fazem o host responder muito (estado inteiro do
## inventário). Não conta os pedidos "uma vez por computador" ao receber uma entidade (centenas
## de uma vez ao entrar numa região; repetidos não custam nada ao host).

const RATE := 60.0  # pedidos por segundo, em média
const BURST := 120.0  # folga para rajadas curtas
const _META := &"peer_guard"

var _tokens: Dictionary[int, float] = {}
var _updated: Dictionary[int, float] = {}
var _expelled: Dictionary[int, bool] = {}


## Host: o pedido sendo atendido cabe na cota do remetente? Se não, desconecta-o. Pedidos do
## próprio host (sem remetente remoto) sempre cabem.
static func allow(api: MultiplayerAPI) -> bool:
	var sender := api.get_remote_sender_id()
	if sender == 0 or sender == api.get_unique_id():
		return true
	if not api.has_meta(_META):
		api.set_meta(_META, PeerGuard.new())  # um por conexão (os testes rodam duas no processo)
	return (api.get_meta(_META) as PeerGuard)._take(api as SceneMultiplayer, sender)


func _take(api: SceneMultiplayer, peer: int) -> bool:
	if _expelled.has(peer):
		return false  # pedidos que já estavam a caminho
	var now := NetRules.now()
	var tokens := minf(_tokens.get(peer, BURST) + (now - _updated.get(peer, now)) * RATE, BURST)
	_updated[peer] = now
	if tokens < 1.0:
		_expelled[peer] = true
		_tokens.erase(peer)
		_updated.erase(peer)
		print("[net] jogador %d desconectado: pedidos demais" % peer)
		# Pela conexão, depois dos pedidos já na fila (recusados acima): a saída chega como
		# qualquer outra (o save guarda o personagem). `SceneMultiplayer.disconnect_peer` o
		# esqueceria sem avisar a saída.
		(func() -> void:
			if peer in api.get_peers():
				api.multiplayer_peer.disconnect_peer(peer)).call_deferred()
		return false
	_tokens[peer] = tokens - 1.0
	return true
