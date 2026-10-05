class_name Replayer
extends RefCounted
## Plays a recorded game (PlayLog) again: the same setup, the same actions on
## the same sim steps. Under the numbers the game was recorded with, the
## result is the same game; under changed numbers it shows how that player's
## choices would have fared. `log` records the replay the way the game
## recorded the original, so the two compare row for row.

var sim: GameSim
var log := PlayLog.new()
## Actions the sim turned down on replay (short of gold, tile taken, ...).
var refused: Array[Dictionary] = []

var _record: Dictionary
var _next := 0


## A record read from `path`, or {} with the reason printed.
static func load_file(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text) if text != "" else null
	if not data is Dictionary or not data.has("setup") or not data.has("actions"):
		printerr("%s is not a playtest record" % path)
		return {}
	if int(data.get("format", 0)) != PlayLog.FORMAT:
		printerr(
			"%s is format %s, this build reads %d" % [path, data.get("format"), PlayLog.FORMAT]
		)
		return {}
	return data


func _init(record: Dictionary) -> void:
	_record = record
	var setup: Dictionary = record.setup
	sim = GameSim.new(StringName(setup.map))
	sim.rules = StringName(setup.rules)
	sim.difficulty = StringName(setup.difficulty)
	sim.infinite = setup.infinite
	sim.twists = setup.twists
	sim.twist_seed = int(setup.twist_seed)
	var picks: Array[StringName] = []
	for p: String in setup.picks:
		picks.append(StringName(p))
		log.picks.append(p)
	sim.elements.apply_picks(picks)
	log.started = record.get("started", "")


## Takes the actions due before this step, then steps the sim.
func step() -> void:
	var now := PlayLog.step_of(sim)
	var actions: Array = _record.actions
	while _next < actions.size() and int(actions[_next].step) <= now:
		if not _apply(actions[_next]):
			refused.append(actions[_next])
		_next += 1
		log.observe(sim, sim.drain_events())
	sim.step()
	log.observe(sim, sim.drain_events())


## Plays to the step the record ends on, or to the end of the game.
func run() -> void:
	var steps := int(_record.get("result", {}).get("steps", 0))
	while not over() and PlayLog.step_of(sim) < steps:
		step()


func over() -> bool:
	return sim.phase == GameSim.Phase.DEFEAT or sim.phase == GameSim.Phase.VICTORY


## What the replay is, in the record's own shape.
func result() -> Dictionary:
	return log.to_dict(sim)


## Where the replay first differs from the record, or "" when it is the same
## game: the same waves with the same leaks, and the same end.
func difference() -> String:
	var mine := result()
	var theirs_waves: Array = _record.get("waves", [])
	for i in mini(mine.waves.size(), theirs_waves.size()):
		for key: String in ["wave", "gold", "lives", "towers", "leaks", "lives_lost", "deaths"]:
			if int(mine.waves[i][key]) != int(theirs_waves[i][key]):
				return (
					"wave %d %s: recorded %d, replayed %d"
					% [mine.waves[i].wave, key, theirs_waves[i][key], mine.waves[i][key]]
				)
	if mine.waves.size() != theirs_waves.size():
		return "recorded %d waves, replayed %d" % [theirs_waves.size(), mine.waves.size()]
	var theirs: Dictionary = _record.get("result", {})
	for key: String in ["steps", "wave", "lives", "gold", "kills", "score"]:
		if int(mine.result[key]) != int(theirs.get(key, -1)):
			return "%s: recorded %d, replayed %d" % [key, theirs.get(key, -1), mine.result[key]]
	if mine.result.outcome != theirs.get("outcome"):
		return "recorded %s, replayed %s" % [theirs.get("outcome"), mine.result.outcome]
	return ""


func _apply(a: Dictionary) -> bool:
	var ok := false
	match a.do:
		"build":
			ok = sim.build(_tile(a.tile), StringName(a.id)) == Placement.Result.OK
		"sell":
			ok = sim.tower_at(_tile(a.tile)) != null
			sim.sell(_tile(a.tile))
		"upgrade":
			ok = sim.upgrade(_tile(a.tile))
		"fuse":
			ok = sim.fuse(_tile(a.tile), _tile(a.with))
		"pick":
			ok = sim.elements.pick(sim, StringName(a.choice))
		"call":
			var before := sim.wave
			sim.start_next_wave()
			ok = sim.wave > before
			if ok:
				log.called_wave(sim)
	return ok


static func _tile(xy: Array) -> Vector2i:
	return Vector2i(int(xy[0]), int(xy[1]))
