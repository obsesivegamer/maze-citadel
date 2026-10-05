extends "res://tests/test_case.gd"
## How the smart bot spends element picks under eletd (RouteLiner): the rules
## a sensible player keeps, read off the sim's events whatever the bot's
## reasons. The first pick goes before wave 1; no more than MAX_HELD picks
## are carried into a wave unless a Guardian is walking; and no Guardian is
## summoned in the breather before a boss wave.

const Bot := preload("res://src/bots/autoplay_bot.gd")
## Far enough for the picks of waves 5, 10 and 15 and the wave-10 boss.
const TO_WAVE := 16
const MAX_HELD := 2


## Plays the bot until wave `to` starts, checking the rules at every event.
func _watch(sim: GameSim, bot: RefCounted, to: int, label: String) -> void:
	# Summons come only between waves, so this is the wave just cleared.
	var cur := sim.wave
	while sim.wave < to and sim.phase != GameSim.Phase.DEFEAT:
		bot.step()
		for e in sim.drain_events():
			match e.type:
				&"wave_started":
					if e.wave == 1:
						check(sim.elements.spent >= 1, "%s: first pick spent before wave 1" % label)
					var walking := sim.creeps.any(
						func(c: SimCreep) -> bool: return c.type == &"guardian"
					)
					var held := sim.elements.pending_picks()
					check(
						walking or held <= MAX_HELD,
						"%s: %d picks held into wave %d" % [label, held, e.wave]
					)
					cur = e.wave
				&"guardian_spawned":
					check(
						not WaveDefs.has_boss(cur + 1),
						"%s: Guardian summoned before boss wave %d" % [label, cur + 1]
					)
	check(sim.wave >= to, "%s: lost on wave %d" % [label, sim.wave])


func test_smart_bot_spends_picks_like_a_player() -> void:
	for map in MapDefs.ORDER:
		var sim := GameSim.new(map)
		sim.rules = &"eletd"
		_watch(sim, Bot.new(sim, &"smart"), TO_WAVE, map)


## With no towers and no gold no Guardian can be killed, so the bot holds its
## picks; but a third one is let go before the wave after it is granted.
func test_smart_bot_lets_go_of_a_third_pick_it_cannot_use() -> void:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	sim.elements.pick(sim, &"dark")
	while sim.wave < 15:
		sim.start_next_wave()
		while sim.phase == GameSim.Phase.WAVE:
			sim.step()
			for c: SimCreep in sim.creeps.duplicate():
				sim.kill(c)
	sim.drain_events()
	sim.gold = 0
	check_eq(sim.elements.pending_picks(), 3, "picks of waves 5, 10 and 15 in hand")
	_watch(sim, Bot.new(sim, &"smart"), 16, "empty board")


## Once wave 35's pick is in no later one is coming, so holding out for an
## element the route can't take buys nothing: the bot takes Interest instead
## rather than carry picks to the end of the game.
func test_smart_bot_spends_its_last_picks_while_interest_is_open() -> void:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	sim.elements.pick(sim, &"dark")
	while sim.wave < 35:
		sim.start_next_wave()
		while sim.phase == GameSim.Phase.WAVE:
			sim.step()
			for c: SimCreep in sim.creeps.duplicate():
				sim.kill(c)
	for e: StringName in [&"dark", &"dark", &"light", &"light", &"aqua"]:
		sim.elements.pick(sim, e)
		for c: SimCreep in sim.creeps.duplicate():
			sim.kill(c)
	check_eq(sim.elements.pending_picks(), 2, "two picks in hand after wave 35")
	# No gold, so the board stays empty and the bot expects every Guardian to
	# leak; the creeps are killed by hand so the waves still end.
	var bot := Bot.new(sim, &"smart")
	while sim.wave < 38:
		sim.gold = 0
		bot.step()
		for c: SimCreep in sim.creeps.duplicate():
			sim.kill(c)
	check(sim.towers.is_empty(), "nothing built")
	check_eq(sim.elements.interest_picks, 2, "both went on Interest")
	check_eq(sim.elements.pending_picks(), 0, "none held into wave 38")
