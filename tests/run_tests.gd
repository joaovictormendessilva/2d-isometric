extends SceneTree
## Executa todos os testes de `tests/test_*.gd` e sai com código 0 (ok) ou 1 (falhas).
##
## Uso: Godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
## (`--fixed-fps 60` faz cada quadro valer 1/60 s: a física roda rápida e determinística.)

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	var total := 0
	var failed := 0
	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(TEST_DIR + file)
		print("%s" % file)
		for method in script.get_script_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_"):
				continue
			var test: TestCase = script.new()
			test.tree = self
			await test.call(method_name)
			test.cleanup()
			total += 1
			if test.failures.is_empty():
				print("  ok    %s" % method_name)
			else:
				failed += 1
				print("  FALHA %s" % method_name)
				for failure in test.failures:
					print("        - %s" % failure)
	print("\n%d testes, %d falha(s)" % [total, failed])
	quit(1 if failed > 0 else 0)
