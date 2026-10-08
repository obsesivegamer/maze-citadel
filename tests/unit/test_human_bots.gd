extends "res://tests/test_case.gd"
## The camper and idle bots (Camper), the balance runs' yardsticks for a
## human player: the opening the owner built under the portal, with the ring
## round the portal's edge built in place of his tiles on it, and an idle bot
## that stops there.

const Bot := preload("res://src/bots/autoplay_bot.gd")
## The waves the idle bot is watched through.
const TO_WAVE := 3
## The Citadel's ring round the portal.
const RING: Array[Vector2i] = [
	Vector2i(8, 0),
	Vector2i(11, 0),
	Vector2i(8, 1),
	Vector2i(9, 1),
	Vector2i(10, 1),
	Vector2i(11, 1)
]
## The ring's edge on the board side, all but the way out west along row 0.
const EDGE: Array[Vector2i] = [
	Vector2i(7, 1),
	Vector2i(8, 2),
	Vector2i(9, 2),
	Vector2i(10, 2),
	Vector2i(11, 2),
	Vector2i(12, 1),
	Vector2i(12, 0),
]


## The Citadel under the Element TD rules; without `ring`, open up to the
## portal as it was when the owner played his game.
func _sim(ring := true) -> GameSim:
	var sim := GameSim.new(&"citadel")
	sim.rules = &"eletd"
	if not ring:
		sim.grid.portal_ring = false
	return sim


## Plays the bot's first decision and checks the opening it built: the whole
## starting gold on Archers, none on a reserved tile, most of them on rows 1
## and 2 and none below row 3.
func _check_opening(sim: GameSim, bot: RefCounted, label: String) -> void:
	var start_gold := sim.gold
	bot.step()
	var refused := sim.drain_events().filter(
		func(e: Dictionary) -> bool: return e.type == &"build_refused"
	)
	check_eq(refused, [], "%s: no build refused" % label)
	var cost := TowerDefs.build_cost(&"archer")
	check_eq(sim.towers.size(), start_gold / cost, "%s: Archers bought" % label)
	check(sim.gold < cost, "%s: starting gold spent, %d left" % [label, sim.gold])
	var near := 0
	for t: SimTower in sim.towers.values():
		check_eq(t.id, &"archer", "%s: tower on %s" % [label, t.tile])
		check(not sim.grid.is_reserved(t.tile), "%s: %s is reserved" % [label, t.tile])
		check(t.tile.y <= 3, "%s: %s under the portal" % [label, t.tile])
		near += 1 if t.tile.y in [1, 2] else 0
	check(near >= 11, "%s: %d Archers on rows 1 and 2" % [label, near])


func test_camper_opening_spends_starting_gold_on_archers_under_the_portal() -> void:
	var sim := _sim(false)
	_check_opening(sim, Bot.new(sim, &"camper"), "camper")
	check_eq(sim.tower_at(Vector2i(10, 1)).id, &"archer", "his first tower")


func test_idle_builds_the_camper_opening_then_never_acts() -> void:
	var camper_sim := _sim()
	Bot.new(camper_sim, &"camper").step()
	var sim := _sim()
	var bot := Bot.new(sim, &"idle")
	_check_opening(sim, bot, "idle")
	check_eq(sim.towers.keys(), camper_sim.towers.keys(), "the camper's opening")
	var towers := sim.towers.duplicate()
	while sim.wave < TO_WAVE and sim.phase != GameSim.Phase.DEFEAT:
		bot.step()
		for e in sim.drain_events():
			var acted: bool = e.type in [&"built", &"sold", &"upgraded", &"fused", &"pick_spent"]
			check(not acted, "idle acted on wave %d: %s" % [sim.wave, e])
	check_eq(sim.wave, TO_WAVE, "played to wave %d" % TO_WAVE)
	check_eq(sim.towers, towers, "the same towers")
	check(sim.gold > 0, "gold banked, not spent")


## Both skip the ring and spend the starting gold on Archers beside it.
func test_both_build_beside_the_ring() -> void:
	for strategy in [&"camper", &"idle"]:
		var sim := _sim()
		var bot := Bot.new(sim, strategy)
		check(bot.plan.size() > 100, "%s: plan kept" % strategy)
		for t in bot.plan:
			check(not sim.grid.is_reserved(t), "%s plans reserved %s" % [strategy, t])
		check_eq(sim.grid.portal_ring_tiles().size(), RING.size(), "the ring")
		for t in RING:
			check(sim.grid.near_portal(t), "%s is a ring tile" % t)
		_check_opening(sim, bot, "%s with a ring" % strategy)
		for t in EDGE:
			check(sim.tower_at(t) != null, "%s: an Archer beside the ring on %s" % [strategy, t])


## As in his game, creeps leave the portal west along row 0, past his row-1
## wall, and turn down only at the west edge.
func test_with_the_ring_creeps_walk_his_wall() -> void:
	var sim := _sim()
	Bot.new(sim, &"camper").step()
	check(sim.field.reachable(sim.field.entry_tile()), "creeps still have a way through")
	var route: Array[Vector2i] = []
	for p in sim.field.route():
		var t := Grid.tile_at(p)
		if Grid.in_bounds(t) and not t in route:
			route.append(t)
	for x in range(0, 8):
		check(Vector2i(x, 0) in route, "the route walks row 0 at column %d" % x)
	for t in route:
		if t.y == 2:
			check(t.x == 0, "they leave the top rows at the west edge, not at %s" % t)
			break


func test_off_the_citadel_both_lay_archers_along_the_plan() -> void:
	for map in [&"rampart", &"causeway"]:
		for strategy in [&"camper", &"idle"]:
			var sim := GameSim.new(map)
			sim.rules = &"eletd"
			var bot := Bot.new(sim, strategy)
			check(not bot.plan.is_empty(), "%s on %s: a plan" % [strategy, map])
			bot.step()
			var cost := TowerDefs.build_cost(&"archer")
			check(sim.gold < cost, "%s on %s: gold spent" % [strategy, map])
			for t: SimTower in sim.towers.values():
				check_eq(t.id, &"archer", "%s on %s: %s" % [strategy, map, t.tile])
				check(t.tile in bot.plan, "%s on %s: %s planned" % [strategy, map, t.tile])
