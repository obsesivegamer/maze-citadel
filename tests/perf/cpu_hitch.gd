extends SceneTree
## Headless CPU-hitch probe: the balance bot plays from wave 1 at normal speed,
## one 60 Hz frame at a time, and every frame whose game code (sim, units, HUD,
## effects, sound) runs longer than the budget is listed with its CPU sections
## and the sim events that fired in it. GPU work isn't included, so these are
## stalls that would hitch on any machine. Usage:
##   godot --headless --fixed-fps 60 --path . --script res://tests/perf/cpu_hitch.gd \
##     -- --waves=12 --budget-ms=6 [--sync-boot]

var game: Game
var _waves := 12
var _budget_ms := 6.0
var _last_us := 0
var _frames := 0
var _events := {}
var _hits: Array[Dictionary] = []
var _buckets := {4.0: 0, 8.0: 0, 16.0: 0, 33.0: 0}
var _total_ms := 0.0


func _initialize() -> void:
	# The Citadel Plateau under classic rules, as docs/perf.md measured them,
	# unless --map or --rules says otherwise; never the player's last pick.
	Game._carry = {
		"map": Cli.get_str("map", MapDefs.DEFAULT), "rules": Cli.get_str("rules", "classic")
	}
	_waves = int(Cli.get_str("waves", "12"))
	_budget_ms = Cli.get_float("budget-ms", 6.0)
	game = Game.new()
	# The shipped boot (loading screen, pre-built creep views, warm-up
	# rehearsal) unless --sync-boot asks for the one-frame setup.
	game.async_boot = not Cli.has("sync-boot")
	root.add_child(game)
	if game.is_booted:
		process_frame.connect(_go, CONNECT_ONE_SHOT)
	else:
		game.booted.connect(_go, CONNECT_ONE_SHOT)


func _go() -> void:
	game.autoplay = AutoplayBot.new(game.sim, &"smart")
	game.choose_build(&"")
	game.sim_event.connect(
		func(e: Dictionary) -> void: _events[e.type] = _events.get(e.type, 0) + 1
	)
	Prof.enabled = true
	Prof.take()
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	if _last_us == 0:
		return false
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	_frames += 1
	_total_ms += ms
	for b: float in _buckets:
		if ms > b:
			_buckets[b] += 1
	var sections := Prof.take()
	if ms > _budget_ms:
		var hit := {"frame": _frames, "ms": snappedf(ms, 0.1), "wave": game.sim.wave}
		hit["phase"] = game.sim.phase
		hit["creeps"] = game.sim.creeps.size()
		for k: StringName in sections:
			if sections[k] >= 0.5:
				hit[k] = snappedf(sections[k], 0.1)
		hit["events"] = _events.duplicate()
		_hits.append(hit)
	_events.clear()
	if game.sim.wave > _waves or game.is_over():
		_report()
		return true
	return false


func _report() -> void:
	_hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ms > b.ms)
	print(
		(
			"frames %d (%.0f s game time), mean %.2f ms; over 4/8/16/33 ms: %s"
			% [_frames, _frames / 60.0, _total_ms / maxi(_frames, 1), _buckets.values()]
		)
	)
	print("slowest frames over %.1f ms (%d):" % [_budget_ms, _hits.size()])
	for h in _hits.slice(0, 30):
		print("  ", JSON.stringify(h))
