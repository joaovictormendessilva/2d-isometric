extends TestCase
## Textos do jogador centralizados (`data/i18n/texts.csv`): todo idioma completo e coerente,
## todo dado com nome, e a troca de idioma funcionando.

const TABLE := "res://data/i18n/texts.csv"
const NAMED_DATA := {
	"ITEM": "res://data/items/",
	"SKILL": "res://data/skills/",
	"NODE": "res://data/resource_nodes/",
	"MONSTER": "res://data/monsters/",
	"NPC": "res://data/npcs/",
	"EFFECT": "res://data/effects/",
}


func test_every_language_has_every_text_with_the_same_placeholders() -> void:
	var rows := _read_table()
	var languages: PackedStringArray = rows[0].slice(1)
	check(languages.size() >= 2, "há pelo menos dois idiomas (%s)" % [languages])
	var keys := {}
	for row: PackedStringArray in rows.slice(1):
		check(not keys.has(row[0]), "chave repetida: %s" % row[0])
		keys[row[0]] = true
		check(row.size() == languages.size() + 1, "%s tem uma coluna por idioma" % row[0])
		var expected := _placeholders(row[1])
		for column in range(1, row.size()):
			var language := languages[column - 1]
			check(not row[column].strip_edges().is_empty(), "%s em %s não está vazio" % [row[0], language])
			check(_placeholders(row[column]) == expected,
				"%s em %s tem os mesmos marcadores (%s)" % [row[0], language, expected])


## Cada item, tipo de coleta, ponto e criatura em `data/` tem nome em todos os idiomas.
func test_all_named_data_has_a_translated_name() -> void:
	var previous := TranslationServer.get_locale()
	for locale in ["pt_BR", "en"]:
		TranslationServer.set_locale(locale)
		for kind: String in NAMED_DATA:
			for entry in DataCatalog.new(NAMED_DATA[kind]).entries():
				var name: String = entry.get_display_name()
				check(not name.begins_with(kind + "_"),
					"%s \"%s\" tem nome em %s (veio \"%s\")" % [kind, entry.id, locale, name])
	TranslationServer.set_locale(previous)


func test_switching_language_switches_texts() -> void:
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("pt_BR")
	var wood_pt := Texts.name_of("ITEM", &"wood")
	var gather_pt := Texts.format(&"GATHER_NEEDS_TOOL", [2])
	TranslationServer.set_locale("en")
	check(wood_pt == "Madeira" and Texts.name_of("ITEM", &"wood") == "Wood", "nome do item troca")
	check(gather_pt != Texts.format(&"GATHER_NEEDS_TOOL", [2]), "frases com valores trocam")
	TranslationServer.set_locale(previous)


func _read_table() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file := FileAccess.open(TABLE, FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 1:
			rows.append(row)
	return rows


## Marcadores de valores na ordem (`%s`, `%d`...), ignorando o `%%` literal.
static func _placeholders(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	var regex := RegEx.create_from_string("%(%|[sdf])")
	for match_ in regex.search_all(text):
		if match_.get_string(1) != "%":
			found.append(match_.get_string())
	return found
