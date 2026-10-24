class_name AttackData
extends Resource
## Um ataque: corpo a corpo (espada do jogador, bote do slime...) ou à distância (arco, cajado:
## ADR-033). Fases: preparação (telegrafia) → golpe (instante do acerto ou do disparo) →
## recuperação. Valores em `data/`.

@export var damage: int = 10
## À distância: no golpe sai este projétil na direção do ataque, em vez de acertar quem está no
## arco (`reach` e `arc_degrees` não valem). Null = corpo a corpo.
@export var projectile: ProjectileData
## Alcance a partir da borda da pegada do atacante, no plano do chão (px).
@export var reach: float = 24.0
## Abertura do arco do golpe, em graus (360 = em volta toda).
@export_range(1.0, 360.0) var arc_degrees: float = 120.0
## Recuo aplicado no alvo (px/s no chão).
@export var knockback: float = 150.0
## Impulso do próprio atacante na direção do golpe (px/s no chão); 0 = parado.
@export var lunge: float = 0.0
## Depois do golpe, o avanço (`lunge`) continua acertando quem ele tocar por este tempo (s): o
## bote de uma criatura vira uma investida de verdade. Cada alvo leva no máximo um acerto.
@export var lunge_hit_time: float = 0.0
## IA: começa o ataque quando a folga até o alvo (chão) for até esta; 0 = 80% do alcance.
## Investidas começam de mais longe (o avanço cobre a distância).
@export var engage_distance: float = 0.0
@export_group("Tempo (s)")
@export var windup: float = 0.05
@export var recovery: float = 0.3
@export_group("")
## Se falso, levar dano não interrompe a preparação: o bote telegrafado sempre sai.
## Evita que golpes seguidos travem o inimigo (stun-lock) e premia quem lê o aviso.
@export var interruptible: bool = true
## Velocidade de movimento do atacante durante o ataque (1 = normal).
@export_range(0.0, 1.0) var move_multiplier: float = 0.4
