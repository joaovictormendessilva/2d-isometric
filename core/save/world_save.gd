class_name WorldSave
extends RefCounted
## O save de um mundo (ADR-019): progresso de cada personagem que já jogou nele (chave = a
## identidade do jogador, ver Network.player_key) e o estado de cada região. Só o host lê e
## grava; quem entra no mundo de outro não guarda nada.
##
## Segurança: JSON puro (nunca objetos, recursos ou scripts), tamanho limitado e versão
## conferida; cada parte confere os próprios valores ao usar (CharacterRecord, SaveService).
## Gravação: escreve num arquivo temporário e só então troca; o save anterior vira `.bak`.
## Arquivo ilegível nunca é sobrescrito: é guardado de lado (`.corrupt`) e o mundo começa novo.

const VERSION := 1
const MAX_FILE_SIZE := 4 * 1024 * 1024

## Chave do jogador -> registro (CharacterRecord).
var players: Dictionary = {}
## Id da região -> estado dela (SaveService).
var regions: Dictionary = {}


## Null se o arquivo é ilegível E não pôde sair do caminho: aí ninguém deve gravar por cima.
static func load_file(path: String) -> WorldSave:
	var save := WorldSave.new()
	if not FileAccess.file_exists(path):
		return save
	var data: Variant = _read(path)
	if not data is Dictionary or SaveValues.to_int(data.get("version"), 1, VERSION, 0) == 0:
		return save if _set_aside(path) else null
	if data.get("players") is Dictionary:
		save.players = data["players"]
	if data.get("regions") is Dictionary:
		save.regions = data["regions"]
	return save


func save_file(path: String) -> Error:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var temp := absolute + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(
		{"version": VERSION, "players": players, "regions": regions}, "\t"))
	file.close()
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute + ".bak")
		DirAccess.rename_absolute(absolute, absolute + ".bak")
	return DirAccess.rename_absolute(temp, absolute)


static func _read(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_SIZE:
		return null
	var json := JSON.new()  # `parse` só devolve o erro (não registra erro da engine)
	return json.data if json.parse(file.get_as_text()) == OK else null


static func _set_aside(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var stamp := "%s.corrupt-%d" % [absolute, Time.get_unix_time_from_system()]
	var aside := stamp
	var attempt := 1
	while FileAccess.file_exists(aside):
		attempt += 1
		aside = "%s-%d" % [stamp, attempt]
	if DirAccess.rename_absolute(absolute, aside) != OK:
		return false
	print("[save] arquivo ilegível ou de outra versão guardado em %s; mundo novo" % aside)
	return true
