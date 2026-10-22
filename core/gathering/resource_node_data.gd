class_name ResourceNodeData
extends Resource
## Um tipo de ponto de coleta (árvore de lenha, veio de cobre...). Cada coleta leva um tempo,
## rende itens (tabela com chances, como os drops) e dá experiência no tipo de coleta. Depois
## de `charges` coletas o ponto se esgota e volta após `respawn_time`. Valores em
## `data/resource_nodes/`.

@export var id: StringName
@export var display_name: String
@export var skill: GatheringSkillData
@export_group("Requisitos")
## Nível mínimo de ferramenta (0 = as mãos servem).
@export var min_tool_tier: int = 0
@export var min_skill_level: int = 1
@export_group("Coleta")
## Segundos por coleta com ferramenta de velocidade 1 e nível 1.
@export var gather_time: float = 1.2
@export var charges: int = 4
@export var respawn_time: float = 45.0
@export var xp_per_gather: int = 5
@export var yields: Array[DropEntry] = []
@export_group("Aparência")
@export var texture: Texture2D
@export var depleted_texture: Texture2D
