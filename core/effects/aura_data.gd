class_name AuraData
extends Resource
## Aura em volta de um ator (ADR-029): anel no chão com runas girando, brilho pulsando e faíscas
## subindo. Só apresentação: não muda atributo nem regra. Quem a liga (equipamento hoje; efeitos e
## criaturas depois) só aponta para um arquivo de `data/auras/`.

## Raio do anel no plano do chão, em pixels (na tela vira uma elipse com metade da altura).
@export_range(4.0, 48.0) var radius: float = 14.0
@export var ring_color := Color(1, 1, 1)
@export var rune_color := Color(1, 1, 1)
## Runas espalhadas por igual no anel (0 = anel liso).
@export_range(0, 12) var rune_count: int = 4
## Voltas por segundo do anel de runas (negativo gira ao contrário).
@export var turns_per_second: float = 0.1
## Brilho: o anel e as runas clareiam até `pulse_light` (0 = nada, 1 = branco) e voltam, a cada
## `pulse_period` segundos.
@export_range(0.2, 10.0) var pulse_period: float = 2.0
@export_range(0.0, 1.0) var pulse_light: float = 0.35
## Luz no chão dentro do anel, na cor do anel: opacidade no pico do pulso (0 = sem luz); no
## vale, metade disso.
@export_range(0.0, 1.0) var glow_alpha: float = 0.25
## Faíscas subindo de dentro do anel (antes do corte do nível de qualidade, ADR-028).
@export_range(0, 24) var sparkle_amount: int = 6
@export var sparkle_color := Color(1, 1, 1)
@export var sparkle_rise_speed: float = 10.0
@export_range(0.2, 4.0) var sparkle_lifetime: float = 1.2
