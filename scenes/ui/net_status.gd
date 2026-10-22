class_name NetStatus
extends Label
## Situação da rede no canto superior direito (host/cliente, jogadores, ping). Some offline.

const REFRESH_INTERVAL := 0.5

var network: Network

var _refresh_left := 0.0


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left > 0.0 or network == null:
		return
	_refresh_left = REFRESH_INTERVAL
	text = network.status_text()
	visible = not text.is_empty()
