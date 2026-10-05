extends SceneTree
## Scratch probe (not committed): the first pick's options per map and seed.

const Bot := preload("res://src/bots/autoplay_bot.gd")


func _initialize() -> void:
	for map in [&"citadel", &"rampart"]:
		for s in 4:
			var sim := GameSim.new(map)
			sim.rules = &"eletd"
			var bot := Bot.new(sim, &"smart", s)
			var liner: RouteLiner = bot._liner
			var parts: Array[String] = []
			for o in liner._pick_options():
				if o.worth > 0.0:
					parts.append("%s %.1f" % [o.choice, o.worth])
			print(map, " ", s, ": ", ", ".join(parts))
	quit()
