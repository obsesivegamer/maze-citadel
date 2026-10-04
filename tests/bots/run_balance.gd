extends SceneTree
## Headless balance run: every strategy × mode over several bot seeds, prints
## a markdown table. Seed 0 is the bot's plain plan; other seeds vary its
## timing, wall order and tower picks the way different players would.
## --map=rampart plays the Fallen Rampart (default: Citadel Plateau).
## Usage: godot --headless --path . --script res://tests/bots/run_balance.gd
##        [-- --seeds=4 --only=smart:hard --per-wave --twists]
## --per-wave also prints how far each wave got (percent of the route).
## --twists plays Twists mode; bot seed n uses twist schedule n + 1.
## --rules=eletd plays that rule set (default: classic); --only then also
## takes its other difficulties, e.g. smart:easy or smart:very_hard.
## --per-wave also prints the unspent gold at each wave's start.

const Bot := preload("res://src/bots/autoplay_bot.gd")
const RUNS := [
	[&"smart", &"normal"],
	[&"smart", &"hard"],
	[&"archers", &"normal"],
	[&"no_air", &"normal"],
	[&"novice", &"normal"],
]
const MAX_GAME_SECONDS := 6000.0
## A wave is a close call when some creep walked this much of its route.
const CLOSE_CALL := 0.8
const BOSS_WAVES: Array[int] = [10, 20, 30, 40]
## The waves that show whether creeps die at the portal.
const OPENING_WAVES: Array[int] = [1, 2, 3, 4, 5]


func _initialize() -> void:
	var seeds := int(Cli.get_str("seeds", "4"))
	var only := Cli.get_str("only")
	var map := StringName(Cli.get_str("map", MapDefs.DEFAULT))
	if not MapDefs.has(map):
		printerr("unknown map %s (maps: %s)" % [map, ", ".join(MapDefs.ORDER)])
		quit(1)
		return
	var rules := StringName(Cli.get_str("rules", "classic"))
	if not rules in GameSim.RULES:
		printerr("unknown rules %s (rules: %s)" % [rules, ", ".join(GameSim.RULES)])
		quit(1)
		return
	for p in SimElements.parse_picks(Cli.get_str("picks")):
		if rules != &"eletd" or not SimElements.is_choice(p):
			printerr("--picks takes elements and interest, under --rules=eletd (got %s)" % p)
			quit(1)
			return
	var runs: Array = RUNS
	if only != "":
		runs = []
		for label in only.split(","):
			var run := [StringName(label.get_slice(":", 0)), StringName(label.get_slice(":", 1))]
			if not Bot.PATTERNS.has(run[0]) or not run[1] in EletdRules.difficulties(rules):
				printerr("unknown row %s under %s rules" % [label, rules])
				quit(1)
				return
			runs.append(run)
	print(
		(
			"| Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | "
			+ "Walked w1–5 | Walked, non-boss median | "
			+ "Boss walked w10 / w20 / w30 / w40 | Losses |"
		)
	)
	print("|---|---|---|---|---|---|---|---|---|")
	for run in runs:
		var label := "%s:%s" % run
		var results: Array[Dictionary] = []
		for s in seeds:
			results.append(_play(run[0], run[1], s, Cli.has("twists")))
		print(_row(run, results))
		printerr("  %s lives lost per wave, all seeds: %s" % [label, _leaks(results)])
	quit()


## One full game. Tracks lives lost per wave and, per wave, the furthest any
## creep got along its route (0 = killed at the portal, 1 = leaked), which
## shows how close a wave came even when nothing leaked.
func _play(strategy: StringName, difficulty: StringName, bot_seed: int, twists: bool) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var sim := GameSim.new(StringName(Cli.get_str("map", MapDefs.DEFAULT)))
	sim.difficulty = difficulty
	sim.twists = twists
	sim.twist_seed = bot_seed + 1
	sim.rules = StringName(Cli.get_str("rules", "classic"))
	sim.elements.apply_picks(SimElements.parse_picks(Cli.get_str("picks")))
	var bot := Bot.new(sim, strategy, bot_seed)
	var lost_at := {}
	var walked := {}
	var boss_walked := {}
	var start := {}
	var banked := {}
	var fly_route := sim.grid.spawn_point.distance_to(sim.grid.gate_point)
	var picks: Array[String] = []
	var guardians := {"summoned": 0, "leaked": {}, "lives": 0}
	while sim.time < MAX_GAME_SECONDS:
		var wave_before := sim.wave
		bot.step()
		if sim.wave != wave_before:
			banked[sim.wave] = sim.gold
		for e in sim.drain_events():
			if e.type == &"pick_spent":
				picks.append("%s@%d" % [e.choice, sim.wave])
			elif e.type == &"guardian_spawned":
				guardians.summoned += 1
			if e.type == &"leaked":
				var c := sim.creep(e.id)
				lost_at[c.wave] = lost_at.get(c.wave, 0) + e.cost
				if c.type == &"guardian":
					guardians.leaked[c.id] = true
					guardians.lives += e.cost
					continue
				walked[c.wave] = 1.0
				if c.boss:
					boss_walked[c.wave] = 1.0
		for c in sim.creeps:
			# A Guardian (eletd) is no part of its wave: only its leaks count.
			if c.leaked or c.progress <= 0.0 or is_inf(c.progress) or c.type == &"guardian":
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
		var gold := banked.keys().map(func(w: int) -> String: return "%d:%d" % [w, banked[w]])
		printerr("    unspent gold: ", ", ".join(gold))
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
		"walked": walked,
	}
	printerr(
		(
			"  %s/%s seed %d: %s, %d lives, %d close calls, leaks %s, gold %d, %d:%02d (%.1f s)"
			% [
				strategy,
				_mode(difficulty),
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
	if sim.elements.enabled:
		printerr("    elements: %s" % _elements(sim))
		printerr("    picks: %s" % ", ".join(picks))
		printerr(
			(
				"    guardians: %d summoned, %d leaked, %d lives"
				% [guardians.summoned, guardians.leaked.size(), guardians.lives]
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
	var opening: Array[float] = []
	var rest: Array[float] = []
	for r in results:
		for w: int in r.walked:
			if w in OPENING_WAVES:
				opening.append(r.walked[w])
			if not WaveDefs.has_boss(w):
				rest.append(r.walked[w])
	rest.sort()
	return (
		"| %s | %s | %d/%d | %.1f, %d–%d | %.1f | %d%% | %d%% | %s | %s |"
		% [
			run[0],
			_mode(run[1]),
			wins,
			results.size(),
			lives.reduce(func(a: int, b: int) -> int: return a + b, 0) / float(lives.size()),
			lives.min(),
			lives.max(),
			close / results.size(),
			roundi(
				(
					100.0
					* opening.reduce(func(a: float, b: float) -> float: return a + b, 0.0)
					/ opening.size()
				)
			),
			roundi(100.0 * rest[rest.size() / 2]),
			" / ".join(boss),
			", ".join(losses) if not losses.is_empty() else "–",
		]
	)


## Lives lost on each wave, summed over the row's games.
func _leaks(results: Array[Dictionary]) -> Dictionary:
	var total := {}
	for r in results:
		for w: int in r.lost_at:
			total[w] = total.get(w, 0) + r.lost_at[w]
	total.sort()
	return total


## Element levels and Interest picks at the end of a game, e.g. "aqua 2, interest 1".
func _elements(sim: GameSim) -> String:
	var parts: Array[String] = []
	for choice: StringName in Damage.WHEEL + [SimElements.INTEREST]:
		if sim.elements.taken(choice) > 0:
			parts.append("%s %d" % [choice, sim.elements.taken(choice)])
	return ", ".join(parts)


func _mode(difficulty: StringName) -> String:
	return String(difficulty) + (" twists" if Cli.has("twists") else "")
