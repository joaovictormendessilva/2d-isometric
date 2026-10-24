class_name NetRules
extends RefCounted
## Regras e validações de rede compartilhadas (ADR-012, ADR-013). Tudo o que chega de outro
## computador é tratado como NÃO confiável: estas funções rejeitam valores inválidos (NaN,
## infinito, fora de faixa) antes que qualquer sistema os use.

## Identifica o jogo e a versão do protocolo no aperto de mão. Mudou o formato de alguma
## mensagem? Aumente a versão: computadores com versões diferentes não se conectam.
const PROTOCOL_ID := "2d-isometric"
const PROTOCOL_VERSION := 16
const DEFAULT_PORT := 24680
## Porta da frente (DoorProtocol) = porta do jogo + isto.
const DOOR_PORT_OFFSET := 1
## Quanto o cliente espera a porta da frente responder antes de desistir (s).
const DOOR_TIMEOUT := 3.0
## Coop de até 4 jogadores: o host e mais 3.
const MAX_CLIENTS := 3
## Tempo para um computador concluir o aperto de mão antes de ser desconectado (s).
const AUTH_TIMEOUT := 3.0
## Limite de qualquer mensagem de sincronização (bytes); nada nosso chega perto disso.
const MAX_PACKET_SIZE := 1024
## Coordenadas válidas no mundo (px). Bem além de qualquer região, só barra lixo.
const MAX_COORDINATE := 100000.0


static func is_valid_vector(value: Vector2) -> bool:
	return value.is_finite() and absf(value.x) <= MAX_COORDINATE and absf(value.y) <= MAX_COORDINATE


## Direção recebida pela rede, normalizada; ZERO se inválida.
static func clean_direction(value: Vector2) -> Vector2:
	return clean_aim(value).normalized()


## Mira recebida pela rede (direção E distância até o ponto mirado, no chão); ZERO se inválida.
## Quem usa a distância a limita ao próprio alcance (ver AbilityData.area_offset).
static func clean_aim(value: Vector2) -> Vector2:
	if not value.is_finite() or value.is_zero_approx() or value.length() > MAX_COORDINATE:
		return Vector2.ZERO
	return value


## Conectado de fato (host ou cliente)? Offline o jogo usa o OfflineMultiplayerPeer.
static func is_online(api: MultiplayerAPI) -> bool:
	return api.has_multiplayer_peer() and not api.multiplayer_peer is OfflineMultiplayerPeer


## Host: o computador ainda recebe mensagens? Saindo (desconexão pedida, à espera da
## confirmação) não recebe mais: o ENet já desfez os canais dele.
static func is_reachable(api: MultiplayerAPI, peer: int) -> bool:
	var enet := api.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return true
	var connection := enet.get_peer(peer)
	return connection != null and connection.get_state() == ENetPacketPeer.STATE_CONNECTED


## Relógio de jogo deste computador (s), em passos de física: estável e igual em todos.
static func now() -> float:
	return float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
