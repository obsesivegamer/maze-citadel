extends SceneTree
## Headless balance run: every strategy × mode, prints a markdown table.
## Usage: godot --headless --path . --script res://tests/bots/run_balance.gd

const Bot := preload("res://src/bots/autoplay_bot.gd")
const RUNS := [
	[&"smart", false],
	[&"smart", true],
	[&"archers", false],
	[&"no_air", false],
]
const MAX_GAME_SECONDS := 6000.0


func _initialize() -> void:
	print(
		"| Strategy | Mode | Result | Lives | Kills | Gold earned | Towers | Route m | Game time |"
	)
	print("|---|---|---|---|---|---|---|---|---|")
	for run in RUNS:
		var t0 := Time.get_ticks_msec()
		var sim := GameSim.new()
		sim.hard = run[1]
		var bot := Bot.new(sim, run[0])
		var lost_at := {}
		while sim.time < MAX_GAME_SECONDS:
			bot.step()
			for e in sim.drain_events():
				if e.type == &"leaked":
					lost_at[sim.wave] = lost_at.get(sim.wave, 0) + e.cost
			if sim.phase == GameSim.Phase.DEFEAT or sim.phase == GameSim.Phase.VICTORY:
				break
		var result := (
			"victory" if sim.phase == GameSim.Phase.VICTORY else "lost at wave %d" % sim.wave
		)
		print(
			(
				"| %s | %s | %s | %d | %d | %d | %d | %.0f | %d:%02d |"
				% [
					run[0],
					"hard" if run[1] else "normal",
					result,
					sim.lives,
					sim.kills,
					sim.gold_earned,
					sim.towers.size(),
					sim.field.route_length(),
					int(sim.time) / 60,
					int(sim.time) % 60,
				]
			)
		)
		printerr(
			(
				"  %s/%s leaks by wave: %s  (%.1f s real)"
				% [
					run[0],
					"hard" if run[1] else "normal",
					lost_at,
					(Time.get_ticks_msec() - t0) / 1000.0
				]
			)
		)
	quit()
