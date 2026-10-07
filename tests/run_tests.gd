extends SceneTree
## Minimal test runner, no addons needed. Run from the project folder:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits with code 1 if any test fails.

const TEST_DIR := "res://tests"


func _init() -> void:
	var total := 0
	var failures: Array[String] = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var suite: RefCounted = load(TEST_DIR.path_join(file)).new()
		for method in suite.get_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			total += 1
			suite.current_test = "%s::%s" % [file.get_basename(), test_name]
			suite.call(test_name)
		failures.append_array(suite.failures)

	for failure in failures:
		printerr("FAIL ", failure)
	print("%d tests, %d failures" % [total, failures.size()])
	quit(1 if failures.size() > 0 else 0)
