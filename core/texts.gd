class_name Texts
extends RefCounted
## Todo texto que o JOGADOR vê passa por aqui: uma chave vira o texto no idioma atual, pela
## tabela `data/i18n/texts.csv` (sistema de tradução da Godot; uma coluna por idioma).
## Nada de texto para o jogador escrito direto no código ou nos dados: novo idioma = nova
## coluna na tabela. (Textos de depuração, como o painel F3, ficam fora.)
##
## Nomes vêm do id: item `wood` → chave `ITEM_WOOD`; tipo de coleta `mining` → `SKILL_MINING`.

## Argumento de linha de comando para escolher o idioma (ex.: `-- --lang=en`).
const LANGUAGE_ARG := "--lang="


static func get_text(key: StringName) -> String:
	return TranslationServer.translate(key)


## Texto com valores: a chave traz os marcadores (`%s`, `%d`) na ordem de `args`.
static func format(key: StringName, args: Array) -> String:
	return get_text(key) % args


## Nome de algo definido em `data/` pelo tipo (ITEM, SKILL, NODE, MONSTER) e id.
static func name_of(kind: String, id: StringName) -> String:
	return get_text(StringName("%s_%s" % [kind, String(id).to_upper()]))


## Usa `--lang=<código>` se veio na linha de comando; senão, o idioma do sistema.
static func apply_command_line(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with(LANGUAGE_ARG):
			TranslationServer.set_locale(arg.trim_prefix(LANGUAGE_ARG))


## Tecla da ação no layout do teclado do jogador (ex.: "E"), para mostrar em avisos.
static func action_key(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key and key.physical_keycode != KEY_NONE:
			var keycode := key.physical_keycode
			if DisplayServer.get_name() != "headless":  # sem janela não há layout de teclado
				keycode = DisplayServer.keyboard_get_keycode_from_physical(keycode)
			return OS.get_keycode_string(keycode)
	return String(action)
