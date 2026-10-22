class_name UserSettings
extends RefCounted
## Preferências locais de quem joga neste computador (posição de janelas...), em
## `user://settings.cfg`. Nada de estado de jogo aqui: só conforto de interface.

const PATH := "user://settings.cfg"


static func get_value(section: String, key: String, default: Variant) -> Variant:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return default
	var value: Variant = config.get_value(section, key, default)
	return value if typeof(value) == typeof(default) else default  # arquivo mexido à mão


static func set_value(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(PATH)  # sem arquivo ainda: começa vazio
	config.set_value(section, key, value)
	config.save(PATH)
