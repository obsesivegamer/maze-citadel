extends SceneTree
## Headless balance run: every strategy × mode over several bot seeds, prints
## a markdown table. Seed 0 is the bot's plain plan; other seeds vary its
## timing, wall order and tower picks the way different players would.
## --map=rampart plays the Fallen Rampart (default: Citadel Plateau).
## Usage: godot --headless --path . --script res://tests/bots/run_balance.gd
##        [-- --seeds=4 --only=smart:hard --per-wave]
## --per-wave also prints how far each wave got (percent of the route).

const Bot := preload("res://src/bots/autoplay_bot.gd")
const RUNS := [
	[&"smart", false],
	[&"smart", true],
	[&"archers", false],
	[&"no_air", false],
]
const MAX_GAME_SECONDS := 6000.0
## A wave is a close call when some creep walked this much of its route.
const CLOSE_CALL := 0.8
const BOSS_WAVES: Array[int] = [10, 20, 30, 40]


func _initialize() -> void:
	var seeds := int(Cli.get_str("seeds", "4"))
	var only := Cli.get_str("only")
	print(
		(
			"| Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | "
			+ "Boss walked w10 / w20 / w30 / w40 | Losses |"
		)
	)
	print("|---|---|---|---|---|---|---|")
	for run in RUNS:
		var label := "%s:%s" % [run[0], "hard" if run[1] else "normal"]
		if only != "" and not label in only.split(","):
			continue
		var results: Array[Dictionary] = []
		for s in seeds:
			results.append(_play(run[0], run[1], s))
		print(_row(run, results))
	quit()


## One full game. Tracks lives lost per wave and, per wave, the furthest any
## creep got along its route (0 = killed at the portal, 1 = leaked), which
## shows how close a wave came even when nothing leaked.
func _play(strategy: StringName, hard: bool, bot_seed: int) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var sim := GameSim.new(StringName(Cli.get_str("map", MapDefs.DEFAULT)))
	sim.hard = hard
	var bot := Bot.new(sim, strategy, bot_seed)
	var lost_at := {}
	var walked := {}
	var boss_walked := {}
	var start := {}
	var fly_route := sim.grid.spawn_point.distance_to(sim.grid.gate_point)
	while sim.time < MAX_GAME_SECONDS:
		bot.step()
		for e in sim.drain_events():
			if e.type == &"leaked":
				var c := sim.creep(e.id)
				lost_at[c.wave] = lost_at.get(c.wave, 0) + e.cost
				walked[c.wave] = 1.0
				if c.boss:
					boss_walked[c.wave] = 1.0
		for c in sim.creeps:
			if c.leaked or c.progress <= 0.0:
				continue
			if not start.has(c.id):
				# The route as it stood when this creep set off.
				start[c.id] = fly_route if c.flying else maxf(c.progress, 1.0)
				continue
			var f := clampf(1.0 - c.progress / start[c.id], 0.0, 1.0)
			walked[c.wave] = maxf(walked.get(c.wave, 0.0), f)
			if c.boss:
				boss_walked[c.wave] = maxf(boss_walked.get(c.wave, 0.0), f)
		if sim.phase == GameSim.Phase.DEFEAT or sim.phase == GameSim.Phase.VICTORY:
			break
	if Cli.has("per-wave"):
		var keys := walked.keys()
		keys.sort()
		var cells := keys.map(func(w: int) -> String: return "%d:%d" % [w, roundi(100 * walked[w])])
		printerr("    walked %: ", ", ".join(cells))
	var close := 0
	for w in walked:
		if walked[w] >= CLOSE_CALL:
			close += 1
	var out := {
		"won": sim.phase == GameSim.Phase.VICTORY,
		"wave": sim.wave,
		"lives": sim.lives,
		"close": close,
		"boss": boss_walked,
		"lost_at": lost_at,
	}
	printerr(
		(
			"  %s/%s seed %d: %s, %d lives, %d close calls, leaks %s, gold %d, %d:%02d (%.1f s)"
			% [
				strategy,
				"hard" if hard else "normal",
				bot_seed,
				"won" if out.won else "lost at wave %d" % sim.wave,
				sim.lives,
				close,
				lost_at,
				sim.gold_earned,
				int(sim.time) / 60,
				int(sim.time) % 60,
				(Time.get_ticks_msec() - t0) / 1000.0,
			]
		)
	)
	return out


func _row(run: Array, results: Array[Dictionary]) -> String:
	var wins := 0
	var lives: Array[int] = []
	var close := 0.0
	var losses: Array[String] = []
	for r in results:
		wins += 1 if r.won else 0
		lives.append(r.lives)
		close += r.close
		if not r.won:
			losses.append("w%d" % r.wave)
	var boss: Array[String] = []
	for w in BOSS_WAVES:
		var reached := results.filter(func(r: Dictionary) -> bool: return r.boss.has(w))
		if reached.is_empty():
			boss.append("–")
			continue
		var sum := 0.0
		for r in reached:
			sum += r.boss[w]
		boss.append("%d%%" % roundi(100.0 * sum / reached.size()))
	return (
		"| %s | %s | %d/%d | %.1f, %d–%d | %.1f | %s | %s |"
		% [
			run[0],
			"hard" if run[1] else "normal",
			wins,
			results.size(),
			lives.reduce(func(a: int, b: int) -> int: return a + b, 0) / float(lives.size()),
			lives.min(),
			lives.max(),
			close / results.size(),
			" / ".join(boss),
			", ".join(losses) if not losses.is_empty() else "–",
		]
	)
