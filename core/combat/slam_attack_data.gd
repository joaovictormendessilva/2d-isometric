class_name SlamAttackData
extends Resource
## Salto com queda em área (chefes, F4). Fases: aviso no chão onde vai cair (o alvo tem tempo
## de sair) → voo até lá → impacto em volta do ponto → recuperação parada (janela para bater).
## Valores em `data/`; distâncias no plano do chão (px).

@export var damage: int = 20
## Raio do impacto a partir do ponto de queda (a pegada do alvo conta).
@export var radius: float = 34.0
## Recuo para fora do ponto de queda (px/s no chão).
@export var knockback: float = 220.0
## Só salta até alvos entre estas distâncias; mais perto, usa o golpe comum.
@export var min_distance: float = 50.0
@export var max_distance: float = 170.0
@export_group("Tempo (s)")
## Aviso no chão antes de sair do lugar.
@export var windup: float = 0.9
@export var air_time: float = 0.6
## Parado depois de cair.
@export var recovery: float = 1.2
## Desde a queda até poder saltar de novo.
@export var cooldown: float = 3.5
@export_group("Apresentação")
## Altura do arco do salto na tela (px).
@export var height: float = 36.0
## Tremor de câmera na queda, para quem está a até `shake_reach` (chão) dela (px, s).
@export var shake_strength: float = 2.0
@export var shake_time: float = 0.15
@export var shake_reach: float = 180.0
