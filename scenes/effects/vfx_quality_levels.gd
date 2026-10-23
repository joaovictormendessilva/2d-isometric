class_name VfxQualityLevels
extends Resource
## Lista dos níveis de qualidade, do mais leve ao mais caprichado (ADR-028).

@export var levels: Array[VfxQualityLevel] = []
## Nível de quem ainda não escolheu (índice em `levels`).
@export var default_level := 0
