class_name PerfFlags
extends RefCounted
## Experiment switches for performance work, set as `--pf-<name>=<value>` after
## `--` on the command line. Code reads each with its shipped default, so a
## run without flags behaves exactly like the shipped game. Flags that win on
## the target Mac graduate into Quality presets and are then removed.

const PREFIX := "pf-"


static func has(flag: String) -> bool:
	return Cli.has(PREFIX + flag)


static func get_float(flag: String, fallback: float) -> float:
	return Cli.get_float(PREFIX + flag, fallback)


static func get_int(flag: String, fallback: int) -> int:
	return int(Cli.get_float(PREFIX + flag, fallback))


static func get_bool(flag: String, fallback: bool) -> bool:
	if not has(flag):
		return fallback
	return Cli.get_str(PREFIX + flag) in ["true", "1", "on", "yes"]


static func get_str(flag: String, fallback: String) -> String:
	return Cli.get_str(PREFIX + flag, fallback)


## Every flag set for this run, for benchmark reports.
static func active() -> Dictionary:
	var out := {}
	for key: String in Cli.args():
		if key.begins_with(PREFIX):
			out[key.trim_prefix(PREFIX)] = Cli.args()[key]
	return out
