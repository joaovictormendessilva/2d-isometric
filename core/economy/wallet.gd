class_name Wallet
extends RefCounted
## Moedas de UM jogador: uma carteira separada do inventário (escolha do João, F3), sem ocupar
## espaço. Só o host altera (`add`/`spend`); na rede, o dono recebe o valor oficial
## (`replicate`). Mesmo padrão do Inventory e do SkillProgress.

signal changed(coins: int)
## Ganho de moedas (apresentação: "+12 moedas"). Só ganhos novos (venda), nunca o save.
signal earned(amount: int)

## Teto da carteira: bem acima de qualquer economia do jogo, longe do limite de um inteiro.
const MAX_COINS := 999_999_999

var _coins := 0


func coins() -> int:
	return _coins


func can_afford(amount: int) -> bool:
	return amount >= 0 and _coins >= amount


## Cabe mais `amount` sem passar do teto?
func can_receive(amount: int) -> bool:
	return amount >= 0 and _coins + amount <= MAX_COINS


## Host: moedas novas. Tudo ou nada (passar do teto não guarda nada).
func add(amount: int) -> bool:
	if amount <= 0 or not can_receive(amount):
		return false
	_assign(_coins + amount)
	earned.emit(amount)
	return true


## Host: gasta `amount`. Tudo ou nada.
func spend(amount: int) -> bool:
	if amount <= 0 or not can_afford(amount):
		return false
	_assign(_coins - amount)
	return true


## Cliente (valor oficial do host) e host ao carregar o save (CharacterRecord).
func replicate(value: int) -> void:
	_assign(clampi(value, 0, MAX_COINS))


## Cliente: o host avisou um ganho (só apresentação).
func notify_earned(amount: int) -> void:
	earned.emit(amount)


func _assign(value: int) -> void:
	if value != _coins:
		_coins = value
		changed.emit(value)
