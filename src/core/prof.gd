class_name Prof
extends RefCounted
## Tiny CPU profiler for benchmarks: accumulates microseconds per named
## section; Bench reads and resets it every frame. Off (two branch checks per
## call) unless a Bench enables it.

static var enabled := false
static var _start := {}
static var _total := {}


static func begin(section: StringName) -> void:
	if enabled:
		_start[section] = Time.get_ticks_usec()


static func end(section: StringName) -> void:
	if enabled and _start.has(section):
		_total[section] = _total.get(section, 0) + Time.get_ticks_usec() - _start[section]


## Milliseconds per section since the last call, then clears.
static func take() -> Dictionary:
	var out := {}
	for k in _total:
		out[k] = _total[k] / 1000.0
	_total.clear()
	return out
