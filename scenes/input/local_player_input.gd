class_name LocalPlayerInput
extends Node
## Lê teclado/controle do jogador LOCAL e entrega a intenção de movimento ao personagem dele.
## As direções da tela viram direções no plano do chão (cima na tela = "norte" do chão),
## então as diagonais andam alinhadas às bordas dos tiles.
## No coop, esta intenção será enviada ao host em vez de aplicada direto.

var player_id := 0
var target: Character


func _ready() -> void:
	# Roda antes da física dos personagens, para a intenção valer no mesmo quadro.
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	target.set_move_intent(Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"))
