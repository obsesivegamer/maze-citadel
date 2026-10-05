extends "res://tests/test_case.gd"
## The camper and idle bots (Camper), the balance runs' yardsticks for a
## human player: the opening the owner built under the portal, moved below
## the no-build band by the portal, and an idle bot that stops there.

const Bot := preload("res://src/bots/autoplay_bot.gd")
## Rows the Element TD rules keep clear at the top of the board.
const BAND := EletdRules.PORTAL_ROWS
## The waves the idle bot is watched through.
const TO_WAVE := 3


## The Citadel under the Element TD rules; without `band`, open up to the
## portal as it was when the owner played his game.
func _sim(band := true) -> GameSim:
	var sim := GameSim.new(&"citadel")
	sim.rules = &"eletd"
	if not band:
		sim.grid.portal_rows = 0
	return sim


## The first row with no reserved tile: the owner's row 1, right under the portal.
func _first_free_row(grid: Grid) -> int:
	for y in Grid.ROWS:
		if range(Grid.COLS).all(func(x: int) -> bool: return not grid.is_reserved(Vector2i(x, y))):
			return y
	return -1


## Plays the bot's first decision and checks the opening it built: the whole
## starting gold on Archers, most of them on the first free row and none more
## than three rows below it.
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
	var row := _first_free_row(sim.grid)
	var on_row := 0
	for t: SimTower in sim.towers.values():
		check_eq(t.id, &"archer", "%s: tower on %s" % [label, t.tile])
		check(not sim.grid.is_reserved(t.tile), "%s: %s is reserved" % [label, t.tile])
		check(
			t.tile.y >= row - 1 and t.tile.y <= row + 2, "%s: %s under the portal" % [label, t.tile]
		)
		on_row += 1 if t.tile.y == row else 0
	check(on_row >= 11, "%s: %d Archers on row %d" % [label, on_row, row])


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


func test_both_skip_reserved_tiles() -> void:
	for strategy in [&"camper", &"idle"]:
		var sim := _sim()
		var bot := Bot.new(sim, strategy)
		check(bot.plan.size() > 100, "%s: plan kept" % strategy)
		for t in bot.plan:
			check(not sim.grid.is_reserved(t), "%s plans reserved %s" % [strategy, t])
		check_eq(_first_free_row(sim.grid), BAND, "band")
		_check_opening(sim, bot, "%s with a band" % strategy)
		check(sim.tower_at(Vector2i(10, BAND)) != null, "%s: his first tower moved down" % strategy)


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
