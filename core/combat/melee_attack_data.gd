class_name MeleeAttackData
extends Resource
## Um ataque corpo a corpo (espada do jogador, bote do slime...). Fases: preparação
## (telegrafia) → golpe (instante do acerto) → recuperação. Valores em `data/`.

@export var damage: int = 10
## Alcance a partir da borda da pegada do atacante, no plano do chão (px).
@export var reach: float = 24.0
## Abertura do arco do golpe, em graus (360 = em volta toda).
@export_range(1.0, 360.0) var arc_degrees: float = 120.0
## Recuo aplicado no alvo (px/s no chão).
@export var knockback: float = 150.0
## Impulso do próprio atacante na direção do golpe (px/s no chão); 0 = parado.
@export var lunge: float = 0.0
@export_group("Tempo (s)")
@export var windup: float = 0.05
@export var recovery: float = 0.3
@export_group("")
## Se falso, levar dano não interrompe a preparação: o bote telegrafado sempre sai.
## Evita que golpes seguidos travem o inimigo (stun-lock) e premia quem lê o aviso.
@export var interruptible: bool = true
## Velocidade de movimento do atacante durante o ataque (1 = normal).
@export_range(0.0, 1.0) var move_multiplier: float = 0.4
