extends SceneTree
## Headless experiment under the eletd rules: what one tower adds to a fixed
## mid-game board, in the sim and in the smart bot's price model (RouteLiner),
## for docs/balance.md. The board is the smart bot's own (seed 0) after wave
## --board. On each of the --tiles board tiles with the most route beside
## them, the tower there is swapped for a dead one (it blocks but never
## fires), then for each candidate tower in turn, and waves --from to --to are
## played one at a time. A slow or shred shows up as damage the other towers
## deal, so a tower's worth is what the whole board deals with it, minus what
## it deals with the dead one.
##
## Two measures per wave. "Pass": creeps can't die, so every creep walks the
## route once and the damage is the board's whole output, as the bot prices
## it. "Real": creep HP is scaled so the plain board lets --leak of the wave's
## HP through, and the tower's worth is the HP it stops: what matters at the
## edge of a wave the board almost holds. A leaked creep is removed.
## --pass skips the real measure, which takes three quarters of the time.
## Usage: godot --headless --path . --script res://tests/bots/support_value.gd
##        [-- --map=rampart --board=20 --from=21 --to=28 --tiles=4 --only=frost,roots
##        --levels=1,3 --pass]

const Bot := preload("res://src/bots/autoplay_bot.gd")
const TOWERS: Array[StringName] = [
	&"frost",
	&"roots",
	&"runesmith",
	&"shadow",
	&"plague",
	&"archer",
	&"cannon",
	&"ballista",
	&"demolisher",
]
## Creeps that can't die get this many times their HP.
const UNDYING := 10000.0
const MAX_WAVE_SECONDS := 400.0

var _map: StringName
## The board as [tile, id, level] in build order.
var _board: Array = []
var _waves: Array[int] = []
## Wave → the HP scale at which the plain board lets --leak of the HP through.
var _scale := {}
## [tile, wave, scale] → the wave played with the dead tower on that tile.
var _dead := {}


func _initialize() -> void:
	_map = StringName(Cli.get_str("map", MapDefs.DEFAULT))
	var board_wave := int(Cli.get_str("board", "20"))
	for w in range(int(Cli.get_str("from", "21")), int(Cli.get_str("to", "28")) + 1):
		if not WaveDefs.has_boss(w):
			_waves.append(w)
	_board = _bot_board(board_wave)
	var tiles := _best_tiles(int(Cli.get_str("tiles", "4")))
	var leak := Cli.get_float("leak", 0.15)
	for w in _waves:
		if not Cli.has("pass"):
			_scale[w] = _calibrate(tiles[0], w, leak)
	printerr(
		(
			"board after wave %d: %d towers; tiles %s; scales %s"
			% [board_wave, _board.size(), tiles, _scale]
		)
	)
	var only := Cli.get_str("only")
	print(
		(
			"| Tower | Level | Gold | Pass: added per creep | of it, own | others' | "
			+ "bot's model | Real: HP stopped | per 100 gold | own share |"
		)
	)
	print("|---|---|---|---|---|---|---|---|---|---|")
	for id in TOWERS:
		if only != "" and not String(id) in only.split(","):
			continue
		for lvl in Cli.get_str("levels", "1,3").split(","):
			print(_row(id, int(lvl), tiles))
	quit()


## The smart bot's board after wave `w`, played on seed 0.
func _bot_board(w: int) -> Array:
	var sim := GameSim.new(_map)
	sim.rules = &"eletd"
	var bot := Bot.new(sim, &"smart")
	while not (sim.wave >= w and sim.phase == GameSim.Phase.BUILD):
		bot.step()
		sim.drain_events()
		if sim.phase == GameSim.Phase.DEFEAT:
			break
	var out := []
	for tile: Vector2i in sim.towers:
		var t: SimTower = sim.towers[tile]
		out.append([tile, t.id, t.level])
	return out


## `k` board tiles with at least three route tiles in reach, spread evenly
## from the portal end of the route to the gate end, Bards and Epics aside:
## near the portal every creep of a wave is still alive, near the gate few.
func _best_tiles(k: int) -> Array[Vector2i]:
	var sim := _sim()
	var route := {}
	for p in sim.field.route():
		route[Grid.tile_at(p)] = true
	var tiles: Array[Vector2i] = []
	var along := {}
	for b: Array in _board:
		if b[1] == &"bard" or b[1] in TowerDefs.EPICS:
			continue
		var n := 0
		var far := 0.0
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var o: Vector2i = b[0] + Vector2i(dx, dy)
				if route.has(o):
					n += 1
					far = maxf(far, sim.field.distance(o))
		if n >= 3:
			along[b[0]] = far
			tiles.append(b[0])
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return along[a] > along[b])
	var out: Array[Vector2i] = []
	for i in k:
		out.append(tiles[roundi(i * (tiles.size() - 1) / maxf(k - 1, 1.0))])
	return out


## The board, every element at level 3, with the tower on `tile` swapped for
## `id` at `lvl`, or for a dead one when `id` is empty.
func _sim(tile := Vector2i(-1, -1), id := &"", lvl := 1) -> GameSim:
	var sim := GameSim.new(_map)
	sim.rules = &"eletd"
	var all: Array[StringName] = []
	for e in Damage.WHEEL:
		all.append_array([e, e, e])
	sim.elements.apply_picks(all)
	sim.gold = 1_000_000
	sim.lives = 1_000_000
	for b: Array in _board:
		var swap: bool = b[0] == tile
		var bid: StringName = (id if id != &"" else &"archer") if swap else b[1]
		var blvl: int = lvl if swap else b[2]
		if bid in TowerDefs.EPICS:
			sim.build(b[0], &"archer")
			sim.tower_at(b[0]).id = bid
			continue
		sim.build(b[0], bid)
		while sim.tower_at(b[0]).level < blvl:
			sim.upgrade(b[0])
		if swap and id == &"":
			sim.tower_at(b[0]).cooldown = INF
	return sim


## Plays wave `w` on `sim` with creep HP times `scale`, every creep walking
## the route once: {dealt, own (the tower on `tile`), hp, leaked, n}.
func _play(sim: GameSim, w: int, scale: float, tile: Vector2i) -> Dictionary:
	sim.wave = w - 1
	sim.start_next_wave()
	var out := {"dealt": 0.0, "own": 0.0, "hp": 0.0, "leaked": 0.0, "n": 0}
	while (sim.spawning() or not sim.creeps.is_empty()) and sim.time < MAX_WAVE_SECONDS:
		sim.step()
		for e in sim.drain_events():
			if e.type != &"spawned" and e.type != &"leaked":
				continue
			var c := sim.creep(e.id)
			if e.type == &"spawned":
				c.max_hp *= scale
				c.hp *= scale
				out.hp += c.max_hp
				out.n += 1
			elif e.type == &"leaked":
				out.leaked += maxf(c.hp, 0.0)
				sim.kill(c)
	for t: SimTower in sim.towers.values():
		out.dealt += t.damage_dealt
	if sim.tower_at(tile) != null:
		out.own = sim.tower_at(tile).damage_dealt
	return out


## The HP scale at which the plain board lets about `share` of wave `w`'s HP
## through, by bisection on a log scale.
func _calibrate(tile: Vector2i, w: int, share: float) -> float:
	var lo := 0.1
	var hi := 20.0
	for _i in 9:
		var mid := sqrt(lo * hi)
		var r := _play(_sim(tile), w, mid, tile)
		if r.leaked / r.hp < share:
			lo = mid
		else:
			hi = mid
	return sqrt(lo * hi)


func _row(id: StringName, lvl: int, tiles: Array[Vector2i]) -> String:
	var gold := TowerDefs.build_cost(id)
	for l in range(1, lvl):
		gold += TowerDefs.upgrade_cost(id, l)
	var pass_added := 0.0
	var pass_own := 0.0
	var model := 0.0
	var stopped := 0.0
	var real_own := 0.0
	var creeps := 0
	for tile in tiles:
		for w in _waves:
			var dead := _dead_play(tile, w, UNDYING)
			var with := _play(_sim(tile, id, lvl), w, UNDYING, tile)
			pass_added += with.dealt - dead.dealt
			pass_own += with.own
			creeps += with.n
			model += _model(tile, id, lvl, w)
			if _scale.is_empty():
				continue
			var dead_real := _dead_play(tile, w, _scale[w])
			var with_real := _play(_sim(tile, id, lvl), w, _scale[w], tile)
			stopped += dead_real.leaked - with_real.leaked
			real_own += with_real.own
	var k := float(tiles.size())
	return (
		"| %s | %d | %d | %.0f | %.0f | %.0f | %.0f | %.0f | %.0f | %d%% |"
		% [
			TowerDefs.TOWERS[id].name,
			lvl,
			gold,
			pass_added / creeps,
			pass_own / creeps,
			(pass_added - pass_own) / creeps,
			model / creeps,
			stopped / k,
			100.0 * stopped / k / gold,
			roundi(100.0 * real_own / maxf(stopped, 1.0)),
		]
	)


func _dead_play(tile: Vector2i, w: int, scale: float) -> Dictionary:
	var key := [tile, w, scale]
	if not _dead.has(key):
		_dead[key] = _play(_sim(tile), w, scale, tile)
	return _dead[key]


## What the smart bot reckons the tower adds to wave `w`, summed over its
## creeps: RouteLiner's damage per creep of each kind times the count.
func _model(tile: Vector2i, id: StringName, lvl: int, w: int) -> float:
	var sim := _sim(tile)
	var liner: RouteLiner = Bot.new(sim, &"smart")._liner
	var weights: Array[float] = [1.0]
	liner._read_waves(w, weights)
	liner._price_towers()
	liner._read_board()
	var raw := liner.added(tile, id, lvl)
	var counts := {}
	for e in WaveDefs.spawn_list(w, sim.rules):
		var key: String = "%s/%s" % [e[0], e[1]]
		counts[key] = counts.get(key, 0) + 1
	var total := 0.0
	# The first two foes are the bot's yardsticks, not creeps of the wave.
	var f := 2
	for key: String in counts:
		total += counts[key] * raw[f]
		f += 1
	return total
