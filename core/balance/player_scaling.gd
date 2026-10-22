class_name PlayerScaling
extends Resource
## Como o jogo escala com o número de jogadores (ver `docs/04-multiplayer.md`).
## Valores em `data/balance/player_scaling.tres`.

## +X de vida das criaturas por jogador além do primeiro (0,5 = +50% por jogador extra).
@export var monster_health_per_extra_player: float = 0.5
