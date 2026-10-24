class_name WaystoneData
extends Resource
## Uma pedra de portal (ADR-037): fica numa região aberta, perto de uma passagem (`anchor`) ou da
## entrada da região (`anchor` vazio). O host a põe num ponto livre perto do ponto de referência
## ao carregar a região. Listadas em `RegionData.waystones`.

## Id único no mundo inteiro (vai no save e na rede); nome em `WAYSTONE_<ID>`.
@export var id: StringName
## Passagem de referência (id); vazio = ponto de entrada da região.
@export var anchor: StringName
## Deslocamento (px de tela) a partir do ponto de referência.
@export var offset := Vector2.ZERO


func get_display_name() -> String:
	return Texts.name_of("WAYSTONE", id)
