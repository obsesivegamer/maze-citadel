class_name Camper
extends RefCounted
## The camper and idle bots, the balance runs' yardsticks for a human player
## (docs/balance.md). The camper plays the owner's recorded Normal game on the
## Citadel Plateau (0.4.1, issue #33): Archer walls as close under the portal as
## the board allows, every coin spent as it comes, his sell-and-swap habit, his
## five picks and no upgrade before UPGRADE_FROM. The idle bot builds the
## camper's opening from the starting gold and never acts again. Off the
## Citadel both lay Archers along AutoplayBot's plan instead.

## Every tile the owner built on, in the order he first built there. His
## serpentine walls run on rows 1 and 3 right under the portal from the
## starting gold, rows 5 and 7 by wave 12, then down the east edge, far from
## the flyers' line. Where the top of the board is reserved, the whole pattern
## moves down so that his row 1 is the first row free of reserved tiles.
const TILES: Array[Vector2i] = [
	Vector2i(10, 1),
	Vector2i(9, 1),
	Vector2i(11, 1),
	Vector2i(11, 0),
	Vector2i(8, 1),
	Vector2i(7, 1),
	Vector2i(6, 1),
	Vector2i(5, 1),
	Vector2i(4, 1),
	Vector2i(3, 1),
	Vector2i(2, 1),
	Vector2i(1, 1),
	Vector2i(0, 3),
	Vector2i(1, 3),
	Vector2i(2, 3),
	Vector2i(3, 3),
	Vector2i(4, 3),
	Vector2i(5, 3),
	Vector2i(6, 3),
	Vector2i(7, 3),
	Vector2i(8, 3),
	Vector2i(9, 3),
	Vector2i(10, 3),
	Vector2i(11, 3),
	Vector2i(12, 3),
	Vector2i(13, 3),
	Vector2i(13, 2),
	Vector2i(13, 1),
	Vector2i(15, 0),
	Vector2i(15, 1),
	Vector2i(15, 2),
	Vector2i(15, 3),
	Vector2i(15, 4),
	Vector2i(14, 5),
	Vector2i(13, 5),
	Vector2i(12, 5),
	Vector2i(11, 5),
	Vector2i(10, 5),
	Vector2i(9, 5),
	Vector2i(8, 5),
	Vector2i(7, 5),
	Vector2i(6, 5),
	Vector2i(5, 5),
	Vector2i(4, 5),
	Vector2i(3, 5),
	Vector2i(2, 5),
	Vector2i(1, 5),
	Vector2i(0, 7),
	Vector2i(1, 7),
	Vector2i(2, 7),
	Vector2i(3, 7),
	Vector2i(4, 7),
	Vector2i(5, 7),
	Vector2i(6, 7),
	Vector2i(7, 7),
	Vector2i(8, 7),
	Vector2i(9, 7),
	Vector2i(10, 7),
	Vector2i(11, 7),
	Vector2i(12, 7),
	Vector2i(13, 7),
	Vector2i(14, 7),
	Vector2i(15, 7),
	Vector2i(16, 6),
	Vector2i(17, 5),
	Vector2i(17, 4),
	Vector2i(17, 3),
	Vector2i(17, 2),
	Vector2i(17, 1),
	Vector2i(19, 0),
	Vector2i(19, 1),
	Vector2i(19, 2),
	Vector2i(19, 3),
	Vector2i(19, 4),
	Vector2i(19, 5),
	Vector2i(19, 6),
	Vector2i(19, 7),
	Vector2i(17, 6),
	Vector2i(17, 7),
	Vector2i(17, 8),
	Vector2i(19, 8),
	Vector2i(17, 9),
	Vector2i(17, 10),
	Vector2i(17, 11),
	Vector2i(17, 12),
	Vector2i(19, 9),
	Vector2i(19, 10),
	Vector2i(19, 11),
	Vector2i(19, 12),
	Vector2i(19, 13),
	Vector2i(17, 13),
	Vector2i(17, 14),
	Vector2i(17, 15),
	Vector2i(17, 16),
	Vector2i(17, 18),
	Vector2i(17, 17),
	Vector2i(17, 19),
	Vector2i(17, 20),
	Vector2i(17, 21),
	Vector2i(17, 22),
	Vector2i(17, 23),
	Vector2i(17, 24),
	Vector2i(17, 25),
	Vector2i(16, 27),
	Vector2i(17, 27),
	Vector2i(18, 27),
	Vector2i(19, 27),
	Vector2i(15, 27),
	Vector2i(15, 26),
	Vector2i(15, 25),
	Vector2i(15, 24),
	Vector2i(15, 23),
	Vector2i(15, 22),
	Vector2i(15, 21),
	Vector2i(15, 20),
	Vector2i(15, 19),
	Vector2i(15, 18),
	Vector2i(15, 17),
	Vector2i(15, 16),
	Vector2i(15, 15),
	Vector2i(15, 14),
	Vector2i(15, 13),
	Vector2i(15, 12),
	Vector2i(15, 11),
	Vector2i(15, 10),
	Vector2i(15, 9),
	Vector2i(14, 9),
	Vector2i(13, 9),
	Vector2i(12, 9),
	Vector2i(19, 14),
	Vector2i(19, 15),
	Vector2i(19, 16),
	Vector2i(9, 9),
	Vector2i(10, 9),
	Vector2i(8, 9),
	Vector2i(11, 9),
	Vector2i(7, 9),
]
## His hook beside the portal: with his row-1 wall it turned creeps west along
## the north edge. Where it falls in a reserved band, a person closes the
## wall's east end instead, so his row 1 runs on from here to the east edge and
## creeps go round its west end, past the whole wall. Left open, they walked
## round the east end past one Archer and the opening leaked on wave 2.
const HOOK := Vector2i(11, 0)
## The tiles he first built something other than an Archer on, with what. The
## tower falls back to an Archer while its element isn't picked.
const IDS := {
	Vector2i(4, 3): &"cannon",
	Vector2i(15, 0): &"frost",
	Vector2i(15, 1): &"plague",
	Vector2i(19, 16): &"frost",
	Vector2i(9, 9): &"bard",
	Vector2i(10, 9): &"cannon",
	Vector2i(8, 9): &"cannon",
	Vector2i(11, 9): &"frost",
	Vector2i(7, 9): &"frost",
}
## The towers he sold to put another on the same tile, as [wave, tile, id] in
## his order: Frost on the portal wall at wave 2, the rest from wave 20.
const SWAPS := [
	[2, Vector2i(9, 1), &"frost"],
	[2, Vector2i(11, 0), &"frost"],
	[2, Vector2i(6, 1), &"frost"],
	[2, Vector2i(4, 1), &"frost"],
	[3, Vector2i(1, 1), &"frost"],
	[20, Vector2i(13, 5), &"frost"],
	[20, Vector2i(9, 5), &"frost"],
	[20, Vector2i(5, 5), &"frost"],
	[20, Vector2i(2, 5), &"frost"],
	[21, Vector2i(8, 3), &"cannon"],
	[21, Vector2i(12, 3), &"cannon"],
	[21, Vector2i(1, 3), &"cannon"],
	[23, Vector2i(11, 5), &"plague"],
	[23, Vector2i(7, 5), &"plague"],
	[24, Vector2i(4, 5), &"bard"],
	[24, Vector2i(2, 5), &"plague"],
	[24, Vector2i(1, 5), &"frost"],
	[24, Vector2i(4, 3), &"plague"],
	[24, Vector2i(3, 3), &"cannon"],
	[26, Vector2i(11, 3), &"bard"],
	[26, Vector2i(10, 5), &"cannon"],
	[27, Vector2i(8, 1), &"cannon"],
	[29, Vector2i(14, 5), &"shadow"],
	[30, Vector2i(19, 3), &"frost"],
	[30, Vector2i(19, 6), &"frost"],
	[30, Vector2i(19, 8), &"frost"],
	[30, Vector2i(19, 12), &"frost"],
	[30, Vector2i(17, 4), &"plague"],
	[31, Vector2i(17, 8), &"plague"],
	[31, Vector2i(17, 11), &"plague"],
	[31, Vector2i(17, 14), &"plague"],
	[31, Vector2i(17, 17), &"plague"],
	[32, Vector2i(6, 3), &"plague"],
	[32, Vector2i(0, 3), &"plague"],
	[33, Vector2i(3, 7), &"cannon"],
	[34, Vector2i(6, 7), &"cannon"],
]
## His five picks, spent as they come; he left the other three unspent.
const PICKS: Array[StringName] = [&"aqua", &"dark", &"interest", &"interest", &"flame"]
## His first upgrade came on this wave. From then on, one per decision with
## all the gold, in this order.
const UPGRADE_FROM := 21
const UPGRADES: Array[StringName] = [&"cannon", &"bard", &"archer"]

var sim: GameSim
## The tiles still to build on, in order: his, moved down past any reserved
## band with the first wall closed to the east edge, or AutoplayBot's plan off
## the Citadel. Reserved tiles are left out.
var plan: Array[Vector2i] = []
## Placement.Result → how many planned tiles were given up for that reason.
var skip_reasons := {}
var _idle: bool
## Rows his tiles move down by: the first row free of reserved tiles, less one.
var _shift := 0
var _ids := {}
var _swaps := []
var _next_slot := 0


func _init(p_sim: GameSim, idle: bool, fallback: Array[Vector2i]) -> void:
	sim = p_sim
	_idle = idle
	var grid := sim.grid
	if grid.map != &"citadel":
		plan = fallback
		return
	while _shift < Grid.ROWS and _row_reserved(_shift):
		_shift += 1
	_shift = maxi(_shift - 1, 0)
	for t in TILES:
		var at := _moved(t)
		if Grid.in_bounds(at) and not grid.is_reserved(at):
			plan.append(at)
		elif t == HOOK:
			for x in range(HOOK.x + 1, Grid.COLS):
				plan.append(_moved(Vector2i(x, HOOK.y + 1)))
	for t: Vector2i in IDS:
		_ids[_moved(t)] = IDS[t]
	for s: Array in SWAPS:
		_swaps.append([s[0], _moved(s[1]), s[2]])


func decide() -> void:
	if _idle:
		if sim.wave == 0:
			_build()
		return
	_spend_picks()
	_swap()
	_build()
	if sim.wave >= UPGRADE_FROM:
		_upgrade_one()


func _row_reserved(row: int) -> bool:
	for x in Grid.COLS:
		if sim.grid.is_reserved(Vector2i(x, row)):
			return true
	return false


func _moved(t: Vector2i) -> Vector2i:
	return t + Vector2i(0, _shift)


## Every planned tile in order with all the gold in hand, an Archer unless he
## built something else there and its element is held. Before wave 1 he
## built nothing but Archers.
func _build() -> void:
	while _next_slot < plan.size():
		var tile := plan[_next_slot]
		if sim.tower_at(tile) != null:
			_next_slot += 1
			continue
		var id: StringName = _ids.get(tile, &"archer") if sim.wave > 0 else &"archer"
		if sim.elements.needs(id) != "":
			id = &"archer"
		var r := sim.check_build(tile, id)
		if r == Placement.Result.NO_GOLD or r == Placement.Result.CREEP_ON_TILE:
			return
		if r == Placement.Result.OK:
			sim.build(tile, id)
		else:
			skip_reasons[r] = skip_reasons.get(r, 0) + 1
		_next_slot += 1


## His swaps whose wave has come, in order, each once the refund and the gold
## in hand pay for the new tower. A swap whose tile holds no tower, or already
## the new one, is given up. A rebuild refused goes back to _build.
func _swap() -> void:
	while not _swaps.is_empty() and _swaps[0][0] <= sim.wave:
		var tile: Vector2i = _swaps[0][1]
		var id: StringName = _swaps[0][2]
		var old := sim.tower_at(tile)
		if old != null and old.id != id and sim.elements.needs(id) == "":
			var refund := floori(old.invested * GameSim.SELL_REFUND)
			if sim.gold + refund < TowerDefs.build_cost(id):
				return
			sim.sell(tile)
			if sim.build(tile, id) != Placement.Result.OK:
				_next_slot = mini(_next_slot, plan.find(tile))
		_swaps.pop_front()


func _upgrade_one() -> void:
	for id in UPGRADES:
		for tile in plan:
			var t := sim.tower_at(tile)
			if t == null or t.id != id or t.level >= t.max_level():
				continue
			if sim.elements.needs(t.id, t.level + 1) == "" and sim.upgrade(tile):
				return


func _spend_picks() -> void:
	var counts := {}
	for choice in PICKS:
		counts[choice] = counts.get(choice, 0) + 1
		if sim.elements.taken(choice) < counts[choice] and sim.elements.pick(sim, choice):
			return
