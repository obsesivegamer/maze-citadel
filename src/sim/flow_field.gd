class_name FlowField
extends RefCounted
## Distance to the gate for every tile (Dijkstra, 8-way moves, diagonal cost
## √2). A diagonal step is allowed only when both side tiles are open, so
## creeps never squeeze between two towers touching at a corner (GDD §2).
## One field serves every ground creep; it is recomputed on each build or sell.

const DIRS: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
]
const DIAGONAL := 1.4142135

var dist := PackedFloat32Array()
var _grid: Grid


func compute(grid: Grid) -> void:
	_grid = grid
	dist.resize(Grid.COLS * Grid.ROWS)
	dist.fill(INF)
	var heap := MinHeap.new()
	for g in grid.goal_tiles:
		if grid.is_walkable(g):
			dist[Grid.index(g)] = 0.0
			heap.push(0.0, Grid.index(g))
	while not heap.is_empty():
		var d := heap.top_key()
		var i := heap.pop()
		if d > dist[i]:
			continue
		var t := Grid.tile_of(i)
		for dir in DIRS:
			if not can_step(grid, t, dir):
				continue
			var n := Grid.index(t + dir)
			var nd := d + (DIAGONAL if dir.x != 0 and dir.y != 0 else 1.0)
			if nd < dist[n]:
				dist[n] = nd
				heap.push(nd, n)


static func can_step(grid: Grid, from: Vector2i, dir: Vector2i) -> bool:
	if not grid.is_walkable(from + dir):
		return false
	if dir.x != 0 and dir.y != 0:
		return (
			grid.is_walkable(from + Vector2i(dir.x, 0))
			and grid.is_walkable(from + Vector2i(0, dir.y))
		)
	return true


func reachable(t: Vector2i) -> bool:
	return Grid.in_bounds(t) and dist[Grid.index(t)] < INF


func distance(t: Vector2i) -> float:
	return dist[Grid.index(t)] if Grid.in_bounds(t) else INF


## The neighbour a creep on `t` should walk to next; `t` itself at the goal or
## when nothing is reachable. Ties keep DIRS order, so paths are deterministic.
func next_tile(t: Vector2i) -> Vector2i:
	var here := distance(t)
	var best := t
	var best_d := INF
	for dir in DIRS:
		if not can_step(_grid, t, dir) or distance(t + dir) >= here:
			continue
		var cost := DIAGONAL if dir.x != 0 and dir.y != 0 else 1.0
		var d := distance(t + dir) + cost
		if d < best_d - 0.0001:
			best_d = d
			best = t + dir
	return best


## The spawn tile creeps enter through: the reachable one closest to the gate.
func entry_tile() -> Vector2i:
	var best := _grid.spawn_tiles[0]
	for s in _grid.spawn_tiles:
		if distance(s) < distance(best):
			best = s
	return best


## Tile centres from the portal to the gate along the current field.
func route() -> PackedVector2Array:
	var out := PackedVector2Array([_grid.spawn_point])
	var t := entry_tile()
	if not reachable(t):
		return out
	for _i in Grid.COLS * Grid.ROWS:
		out.append(Grid.center(t))
		if distance(t) == 0.0:
			break
		t = next_tile(t)
	out.append(_grid.gate_point)
	return out


## Route length in metres, portal to gate.
func route_length() -> float:
	var r := route()
	var total := 0.0
	for i in range(1, r.size()):
		total += r[i - 1].distance_to(r[i])
	return total


class MinHeap:
	extends RefCounted
	var _keys := PackedFloat32Array()
	var _vals := PackedInt32Array()

	func is_empty() -> bool:
		return _keys.is_empty()

	func top_key() -> float:
		return _keys[0]

	func push(key: float, val: int) -> void:
		_keys.append(key)
		_vals.append(val)
		var i := _keys.size() - 1
		while i > 0:
			var parent := (i - 1) / 2
			if _keys[parent] <= _keys[i]:
				break
			_swap(i, parent)
			i = parent

	func pop() -> int:
		var top := _vals[0]
		var last := _keys.size() - 1
		_swap(0, last)
		_keys.resize(last)
		_vals.resize(last)
		var i := 0
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < last and _keys[l] < _keys[m]:
				m = l
			if r < last and _keys[r] < _keys[m]:
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func _swap(a: int, b: int) -> void:
		var k := _keys[a]
		_keys[a] = _keys[b]
		_keys[b] = k
		var v := _vals[a]
		_vals[a] = _vals[b]
		_vals[b] = v
