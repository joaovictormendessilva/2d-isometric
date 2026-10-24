extends SceneTree
## Executa todos os testes de `tests/test_*.gd` e sai com código 0 (ok) ou 1 (falhas).
## Qualquer erro de script ou da engine durante um teste também o reprova.
##
## Uso: Godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd [-- <filtro>]
## Com filtro, roda só os arquivos cujo nome contém o texto (ex.: `-- network`).
## (`--fixed-fps 60` faz cada quadro valer 1/60 s: a física roda rápida e determinística.)

const TEST_DIR := "res://tests/"
## Preferências de interface dos testes: arquivo próprio, zerado antes de cada teste.
const TEST_SETTINGS := "user://test_settings.cfg"
## Identidade de rede dos clientes dos testes (não a de quem joga neste computador).
const TEST_PROFILE := "user://test_profile.cfg"


## Captura erros reportados pela engine (SCRIPT ERROR, push_error...) enquanto um teste roda.
class ErrorCollector extends Logger:
	var _mutex := Mutex.new()
	var _errors := PackedStringArray()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		_errors.append("erro: %s (%s:%d)" % [rationale if rationale else code, file, line])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var errors := _errors
		_errors = PackedStringArray()
		_mutex.unlock()
		return errors


var _errors := ErrorCollector.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	UserSettings.path = TEST_SETTINGS
	SaveService.default_path = ""  # o jogo dos testes não lê nem grava save; test_save escolhe o dele
	PlayerProfile.path = TEST_PROFILE
	_run_all.call_deferred()


func _run_all() -> void:
	var total := 0
	var failed := 0
	var filter := "" if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()[0]
	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or not (filter.is_empty() or file.contains(filter)):
			continue
		var script: GDScript = load(TEST_DIR + file)
		print("%s" % file)
		if script == null or not script.can_instantiate():
			# Arquivo que não compila não pode passar em silêncio (os testes dele nem rodariam).
			total += 1
			failed += 1
			print("  FALHA arquivo não compila:")
			for error in _errors.take():
				print("        - %s" % error)
			continue
		for method in script.get_script_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_"):
				continue
			_errors.take()
			UserSettings.clear()
			var test: TestCase = script.new()
			test.tree = self
			await test.call(method_name)
			test.cleanup()
			for error in _errors.take():
				if not test.is_expected_error(error):
					test.failures.append(error)
			total += 1
			if test.failures.is_empty():
				print("  ok    %s" % method_name)
			else:
				failed += 1
				print("  FALHA %s" % method_name)
				for failure in test.failures:
					print("        - %s" % failure)
	print("\n%d testes, %d falha(s)" % [total, failed])
	OS.remove_logger(_errors)
	quit(1 if failed > 0 else 0)
