class_name CoinLabel
extends HBoxContainer
## Moedas do jogador, centralizadas na coluna: ícone de moeda e o valor, sempre o oficial (o
## host manda, ver Wallet). Usado no inventário e na loja.

const COIN_ICON := preload("res://assets/sprites/placeholder/icon_coin.png")

var _amount: Label


func setup(wallet: Wallet) -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tooltip_text = Texts.get_text(&"COINS")
	var chip := ListRow.chip(COIN_ICON, wallet.coins())
	add_child(chip)
	_amount = chip.get_child(1)  # rótulo do chip (ver ListRow.chip)
	_amount.modulate = UiStyle.ACCENT
	wallet.changed.connect(func(coins: int) -> void: _amount.text = str(coins))
