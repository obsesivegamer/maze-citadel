extends SceneTree
## Headless test runner: every `test_*` method in tests/unit/test_*.gd.
## Exits 0 when all pass, 1 otherwise.


## Script errors abort a test function without raising, so they are caught
## here and turned into failures instead of silently passing.
class ErrorCatcher:
	extends Logger
	var errors: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace],
	) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append(
			"%s:%d %s %s" % [file.get_file(), line, function, rationale if rationale else code]
		)
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := errors
		errors = []
		_mutex.unlock()
		return out


func _initialize() -> void:
	var passed := 0
	var failed := 0
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
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
			catcher.take()
			case.call(test_name)
			for err in catcher.take():
				case.failures.append("engine error: " + err)
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
