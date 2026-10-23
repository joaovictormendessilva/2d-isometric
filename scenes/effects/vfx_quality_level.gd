class_name VfxQualityLevel
extends Resource
## Um nível de qualidade dos efeitos (ADR-028). Valores em `data/vfx/quality.tres`.

## Nome curto no painel de debug (F3); vira texto traduzível quando houver menu de opções.
@export var id: StringName
## Fração das partículas pedidas por cada efeito (1 = tudo o que o dado pede).
@export_range(0.1, 1.0) var particle_scale: float = 1.0
## Teto de partículas vivas somando todos os efeitos deste computador.
@export_range(0, 5000) var particle_budget: int = 600
