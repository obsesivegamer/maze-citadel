class_name PlayLog
extends RefCounted
## The record of one game: its setup, every action the player took with the
## sim step it happened on, and what each wave did (how far its creeps
## walked, lives lost, gold in hand). The game writes one per match to
## DIR as JSON (docs/playtests.md). The sim is deterministic, so Replayer
## plays the same game again from the actions alone.
##
## Feed it every batch of drained sim events (observe); nothing here changes
## the sim.

const FORMAT := 1
const DIR := "user://playtests"
## The setting that turns the files off (Settings, HELP).
const SETTING := "playtest_log"
## Sim events after which the game writes the file again, so a game that is
## quit or crashes loses at most the wave in progress.
const SAVE_ON: Array[StringName] = [&"wave_started", &"wave_cleared", &"defeat", &"victory"]

## DIR, unless a test points the files somewhere else.
static var dir := DIR

var actions: Array[Dictionary] = []
## Elements and Interest set up before the game (--picks), for the replay.
var picks: Array[String] = []
var started := Time.get_datetime_string_from_system()

var _rows := {}
## Per creep on its first walk: the route length when first seen, the share
## walked.
var _creeps := {}
## Creeps that leaked and walk again.
var _leaked := {}
var _death_walk := {}
var _path := ""


## The sim step an action taken now falls on: it happens before that step.
static func step_of(sim: GameSim) -> int:
	return roundi(sim.time / GameSim.DT)


## Reads one batch of sim events. `step` is the step the batch's actions were
## taken before: the current one for a player, who acts between steps; a bot
## that acts and steps in one call passes the step from before the call.
func observe(sim: GameSim, events: Array[Dictionary], step := step_of(sim)) -> void:
	for e in events:
		match e.type:
			&"built":
				_act(sim, step, {"do": "build", "tile": _xy(e.tile), "id": String(e.id)})
			&"sold":
				_act(sim, step, {"do": "sell", "tile": _xy(e.tile)})
			&"upgraded":
				_act(sim, step, {"do": "upgrade", "tile": _xy(e.tile)})
			&"fused":
				_act(sim, step, {"do": "fuse", "tile": _xy(e.tile), "with": _xy(e.freed)})
			&"pick_spent":
				_act(sim, step, {"do": "pick", "choice": String(e.choice)})
			&"wave_started":
				_row(sim, e.wave)
			&"wave_cleared":
				for row: Dictionary in _rows.values():
					if row.cleared_t == null:
						row.cleared_t = snappedf(sim.time, 0.01)
			&"leaked":
				var row := _row(sim, e.wave)
				row.leaks += 1
				row.lives_lost += e.cost
				if e.creep != &"guardian":
					row.walked = 1.0
				_creeps.erase(e.id)
				_leaked[e.id] = true
			&"died":
				_died(sim, e)
	_watch_creeps(sim)


## A death counts for its wave unless the creep is a Guardian or had already
## leaked (that one is under `leaks`). The events carry the wave: a creep
## that died this step is already gone from the sim, and one killed on the
## step it entered was never watched, so it died at 0.
func _died(sim: GameSim, e: Dictionary) -> void:
	if _leaked.erase(e.id) or e.creep == &"guardian":
		return
	var walked: float = _creeps[e.id][1] if _creeps.has(e.id) else 0.0
	_creeps.erase(e.id)
	_row(sim, e.wave).deaths += 1
	_death_walk[e.wave] = _death_walk.get(e.wave, 0.0) + walked


## The player called the next wave before its countdown ran out. Not an event
## of its own: the sim starts waves by itself too.
func called_wave(sim: GameSim) -> void:
	_act(sim, step_of(sim), {"do": "call"})


func is_empty() -> bool:
	return actions.is_empty() and _rows.is_empty()


## The whole record. `outcome` is "victory", "defeat" or, for a game left
## early, "unfinished".
func to_dict(sim: GameSim) -> Dictionary:
	var waves: Array[Dictionary] = []
	for w: int in _rows:
		var row: Dictionary = _rows[w].duplicate()
		row.walked = snappedf(row.walked, 0.001)
		var deaths: int = row.deaths
		row.died_at = snappedf(_death_walk.get(w, 0.0) / deaths, 0.001) if deaths > 0 else null
		waves.append(row)
	var towers: Array[Dictionary] = []
	for t: SimTower in sim.towers.values():
		towers.append({"tile": _xy(t.tile), "id": String(t.id), "level": t.level})
	var outcome := "unfinished"
	if sim.phase == GameSim.Phase.VICTORY:
		outcome = "victory"
	elif sim.phase == GameSim.Phase.DEFEAT:
		outcome = "defeat"
	return {
		"format": FORMAT,
		"game_version": ProjectSettings.get_setting("application/config/version", ""),
		"started": started,
		"setup":
		{
			"map": String(sim.grid.map),
			"rules": String(sim.rules),
			"difficulty": String(sim.difficulty),
			"infinite": sim.infinite,
			"twists": sim.twists,
			"twist_seed": sim.twist_seed,
			"picks": picks,
		},
		"actions": actions,
		"waves": waves,
		"result":
		{
			"outcome": outcome,
			"steps": step_of(sim),
			"time": snappedf(sim.time, 0.01),
			"wave": sim.wave,
			"lives": sim.lives,
			"gold": sim.gold,
			"gold_earned": sim.gold_earned,
			"kills": sim.kills,
			"score": sim.score(),
			"towers": towers,
		},
	}


func file_path(sim: GameSim) -> String:
	var stamp := started.replace(":", "-")
	return "%s/%s_%s_%s.json" % [dir, stamp, sim.grid.map, sim.difficulty]


## Writes the record so far over this game's file; returns its path, or ""
## when nothing has happened yet or the file can't be written. A game whose
## difficulty changed since the last save (before wave 1) moves to its new
## name.
func save(sim: GameSim) -> String:
	if is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(dir)
	var path := file_path(sim)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(to_dict(sim), "  ", false))
	if _path != "" and _path != path:
		DirAccess.remove_absolute(_path)
	_path = path
	return path


func _act(sim: GameSim, step: int, what: Dictionary) -> void:
	var a := {"step": step, "t": snappedf(step * GameSim.DT, 0.01), "wave": sim.wave}
	a.merge(what)
	a.gold = sim.gold
	actions.append(a)


## The row for wave `w`, opened with the board as it stands now.
func _row(sim: GameSim, w: int) -> Dictionary:
	if not _rows.has(w):
		var invested := 0
		for t: SimTower in sim.towers.values():
			invested += t.invested
		_rows[w] = {
			"wave": w,
			"t": snappedf(sim.time, 0.01),
			"gold": sim.gold,
			"lives": sim.lives,
			"towers": sim.towers.size(),
			"invested": invested,
			"earned_before": sim.gold_earned,
			"walked": 0.0,
			"died_at": null,
			"deaths": 0,
			"leaks": 0,
			"lives_lost": 0,
			"cleared_t": null,
		}
	return _rows[w]


## How far each creep has got along its route, 0 at the portal to 1 at the
## gate, measured against the whole route as it stood when the creep was
## first seen (so a Felhound summoned halfway starts halfway). A Guardian is
## no part of its wave.
func _watch_creeps(sim: GameSim) -> void:
	for c in sim.creeps:
		if c.leaked or c.progress <= 0.0 or is_inf(c.progress) or c.type == &"guardian":
			continue
		if not _creeps.has(c.id):
			var route := sim.grid.spawn_point.distance_to(sim.grid.gate_point)
			if not c.flying:
				var entry := sim.field.distance(sim.field.entry_tile()) * Grid.TILE + Grid.TILE
				route = maxf(maxf(entry, c.progress), 1.0)
			_creeps[c.id] = [route, 0.0]
		var seen: Array = _creeps[c.id]
		seen[1] = maxf(seen[1], clampf(1.0 - c.progress / seen[0], 0.0, 1.0))
		var row := _row(sim, c.wave)
		row.walked = maxf(row.walked, seen[1])


static func _xy(tile: Vector2i) -> Array[int]:
	return [tile.x, tile.y]
