extends SceneTree
## Headless test runner: every `test_*` method in tests/unit/test_*.gd.
## Exits 0 when all pass, 1 otherwise.


func _initialize() -> void:
	var passed := 0
	var failed := 0
	for path in _files("res://tests/unit", "test_", ".gd"):
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("FAIL %s (does not compile)" % path)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			var case: RefCounted = script.new()
			case.call(test_name)
			if case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FAIL %s::%s" % [path.get_file(), test_name])
				for msg in case.failures:
					print("     ", msg)
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


static func _files(dir: String, prefix: String, suffix: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(prefix) and f.ends_with(suffix):
			out.append(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(sub), prefix, suffix))
	return out
