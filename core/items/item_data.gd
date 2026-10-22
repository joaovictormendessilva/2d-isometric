class_name ItemData
extends Resource
## Definição de um item (um arquivo por item em `data/items/`).

@export var id: StringName
@export var icon: Texture2D
## Quantos cabem num espaço do inventário (ferramentas: 1).
@export var max_stack: int = 99


## Nome no idioma atual (chave `ITEM_<ID>` em `data/i18n/texts.csv`).
func get_display_name() -> String:
	return Texts.name_of("ITEM", id)
