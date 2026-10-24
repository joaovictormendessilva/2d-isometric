class_name Passage
extends Area2D
## Passagem para outra região (ADR-020), no fim de um caminho na borda do mapa. Quem entra viaja
## para a passagem `target_passage` da região `target_region` e chega no `Arrival` dela (longe
## do gatilho, para não voltar na hora). Uma parede invisível atrás do gatilho impede sair do
## mapa quando a viagem não acontece. A passagem só avisa; quem decide a viagem é o Main.
## Para a borda oeste, o gerador gira a cena em 180° (gatilho, parede e chegada giram juntos).
## `doorway.tscn` é a mesma passagem sem parede, no meio do mapa (entrada de dungeon): só o
## gatilho, na frente de um objeto do cenário (a boca da caverna), e a chegada logo abaixo.

signal entered_by(player_id: int, passage: Passage)

@export var passage_id: StringName
@export var target_region: StringName
@export var target_passage: StringName


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func arrival_position() -> Vector2:
	return ($Arrival as Marker2D).global_position


func _on_body_entered(body: Node2D) -> void:
	var character := body as Character
	if character and character.player_id != 0:
		entered_by.emit(character.player_id, self)
