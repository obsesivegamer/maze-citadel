extends SceneTree
## Plays recorded games again, headless, and prints what each wave did: the
## files the game writes to its playtests folder (docs/playtests.md). Under
## the numbers a game was recorded with this is the same game, and the tool
## says so; under changed numbers it shows how that player's choices would
## have fared, and where the two part.
## Usage: godot --headless --path . --script res://tests/bots/replay.gd
##        -- --file=<a.json>[,<b.json>] [--difficulty=very_hard]
## --difficulty replays the same actions on another difficulty.
## Exits 1 when a file can't be read.


func _initialize() -> void:
	var ok := true
	for path in Cli.get_str("file").split(",", false):
		ok = _replay(path) and ok
	if not Cli.has("file"):
		printerr("usage: replay.gd -- --file=<record.json>[,<record.json>]")
		ok = false
	quit(0 if ok else 1)


func _replay(path: String) -> bool:
	var record := Replayer.load_file(path)
	if record.is_empty():
		return false
	var changed := Cli.has("difficulty")
	if changed:
		record.setup.difficulty = Cli.get_str("difficulty")
	var player := Replayer.new(record)
	player.run()
	var out := player.result()
	var setup: Dictionary = out.setup
	print("\n%s" % path.get_file())
	print(
		(
			"%s · %s · %s · recorded on %s"
			% [setup.map, setup.rules, setup.difficulty, record.get("game_version", "?")]
		)
	)
	print("| Wave | Gold | Towers | Walked | Died at | Leaks | Lives lost | Cleared in |")
	print("|---|---|---|---|---|---|---|---|")
	for row: Dictionary in out.waves:
		print(
			(
				"| %d | %d | %d | %d%% | %s | %d | %d | %s |"
				% [
					row.wave,
					row.gold,
					row.towers,
					roundi(100 * row.walked),
					"–" if row.died_at == null else "%d%%" % roundi(100 * row.died_at),
					row.leaks,
					row.lives_lost,
					"–" if row.cleared_t == null else "%.0f s" % (row.cleared_t - row.t),
				]
			)
		)
	var r: Dictionary = out.result
	print(
		(
			"%s at wave %d: %d lives, %d gold, %d kills, score %d, %s"
			% [r.outcome, r.wave, r.lives, r.gold, r.kills, r.score, _clock(r.time)]
		)
	)
	if not player.refused.is_empty():
		var first: Dictionary = player.refused[0]
		print(
			(
				"%d of %d actions were refused, the first a %s at %s (wave %d)"
				% [
					player.refused.size(),
					record.actions.size(),
					first.do,
					_clock(first.t),
					first.wave
				]
			)
		)
	var diff := player.difference()
	if diff == "":
		print("Same game as recorded.")
	else:
		print(
			"Differs from the recording%s: %s" % [" (difficulty changed)" if changed else "", diff]
		)
	return true


static func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
