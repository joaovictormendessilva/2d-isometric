class_name DamageInfo
extends RefCounted
## Um acerto já decidido pela autoridade (host). Vai para `Health.apply_damage`.

var amount: int
## Direção do golpe no plano do chão (normalizada), usada no recuo.
var direction: Vector2
var knockback: float
var source_entity_id: int
## Jogador responsável (0 = criatura/ambiente). Usado para drops pessoais.
var source_player_id: int
## Dano de efeito (veneno...): ignora defesa e invulnerabilidade, não atordoa nem empurra.
var periodic := false


static func create(p_amount: int, p_direction: Vector2, p_knockback: float,
		p_source_entity_id: int, p_source_player_id: int) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.direction = p_direction
	info.knockback = p_knockback
	info.source_entity_id = p_source_entity_id
	info.source_player_id = p_source_player_id
	return info


static func create_periodic(p_amount: int, p_source_player_id: int) -> DamageInfo:
	var info := create(p_amount, Vector2.ZERO, 0.0, 0, p_source_player_id)
	info.periodic = true
	return info
