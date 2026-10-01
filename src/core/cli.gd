class_name Cli
extends RefCounted
## User arguments passed after `--` on the command line.
## `--key=value` maps key to value; a bare `--flag` maps flag to "true".

static var _args: Dictionary = {}
static var _parsed := false


static func parse(raw: PackedStringArray) -> Dictionary:
	var out := {}
	for item in raw:
		var arg := item.trim_prefix("--")
		var eq := arg.find("=")
		if eq == -1:
			out[arg] = "true"
		else:
			out[arg.substr(0, eq)] = arg.substr(eq + 1)
	return out


static func args() -> Dictionary:
	if not _parsed:
		_args = parse(OS.get_cmdline_user_args())
		_parsed = true
	return _args


static func has(key: String) -> bool:
	return args().has(key)


static func get_str(key: String, fallback := "") -> String:
	return args().get(key, fallback)


static func get_float(key: String, fallback := 0.0) -> float:
	return float(args()[key]) if has(key) else fallback
