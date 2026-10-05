extends SceneTree
## Scratch probe (not committed): the smart bot's pick options at each pick.

const Bot := preload("res://src/bots/autoplay_bot.gd")


func _initialize() -> void:
	var sim := GameSim.new(StringName(Cli.get_str("map", "citadel")))
	sim.rules = &"eletd"
	var bot := Bot.new(sim, &"smart", int(Cli.get_str("seed", "0")))
	var liner: RouteLiner = bot._liner
	var last := -1
	while sim.wave < 36 and sim.phase != GameSim.Phase.DEFEAT:
		if (
			sim.phase == GameSim.Phase.BUILD
			and sim.elements.pending_picks() > 0
			and last != sim.wave
		):
			last = sim.wave
			var opts := liner._pick_options()
			var parts: Array[String] = []
			for o in opts:
				parts.append("%s %.3f/%d" % [o.choice, o.worth, o.lives])
			var best := liner._actions[0] if not liner._actions.is_empty() else {}
			print(
				(
					"w%d gold %d: %s | best %s %s %.4f"
					% [
						sim.wave,
						sim.gold,
						", ".join(parts),
						best.get("kind", ""),
						best.get("id", ""),
						best.get("ratio", 0.0)
					]
				)
			)
			var counts := {}
			for t: SimTower in sim.towers.values():
				var k := "%s%d" % [t.id, t.level]
				counts[k] = counts.get(k, 0) + 1
			print("   towers: ", counts)
		bot.step()
		for e in sim.drain_events():
			if e.type == &"pick_spent":
				print("   spent ", e.choice, " at wave ", sim.wave)
	quit()
