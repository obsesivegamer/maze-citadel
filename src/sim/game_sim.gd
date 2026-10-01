class_name GameSim
extends RefCounted
## Authoritative game state, advanced on a fixed 30 Hz step. The presentation
## layer reads state and drains `events`; tests and balance bots drive it
## headless. ×2/×3 speed means more steps per frame, never a bigger step.

enum Phase { BUILD, WAVE, DEFEAT, VICTORY }

const DT := 1.0 / 30.0
const START_GOLD := 220
const START_LIVES := 20
const OPENING_BUILD_TIME := 45.0
const BREATHER := 5.0
const SPAWN_INTERVAL := 0.9
const FAST_SPAWN_INTERVAL := 0.5
const SELL_REFUND := 0.75
const CREEP_RADIUS := 0.45

var grid := Grid.new()
var field := FlowField.new()
var gold := START_GOLD
var lives := START_LIVES
var phase := Phase.BUILD
## Last wave started; 0 before wave 1.
var wave := 0
## Seconds until the next wave starts on its own; -1 while one is running.
var countdown := OPENING_BUILD_TIME
var time := 0.0
var kills := 0
var gold_earned := 0
var creeps: Array[SimCreep] = []
## Vector2i tile → {"id": StringName, "level": int, "invested": int}
var towers := {}
var events: Array[Dictionary] = []

var _spawn_queue: Array[StringName] = []
var _spawn_wave: Array[int] = []
var _spawn_timer := 0.0
var _next_id := 1


func _init() -> void:
	field.compute(grid)


func drain_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out


# --- Building ---------------------------------------------------------------


## Tiles touched by any ground creep's body; towers can't go there.
func creep_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in creeps:
		if not c.alive or c.flying:
			continue
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var t := Grid.tile_at(c.pos + corner * CREEP_RADIUS)
			if not t in out:
				out.append(t)
	return out


func check_build(tile: Vector2i, id: StringName) -> Placement.Result:
	var result := Placement.check(grid, tile, creep_tiles())
	if result == Placement.Result.OK and gold < TowerDefs.build_cost(id):
		return Placement.Result.NO_GOLD
	return result


func build(tile: Vector2i, id: StringName) -> Placement.Result:
	var result := check_build(tile, id)
	if result != Placement.Result.OK:
		events.append({"type": &"build_refused", "tile": tile, "reason": result})
		return result
	var cost := TowerDefs.build_cost(id)
	gold -= cost
	towers[tile] = {"id": id, "level": 1, "invested": cost}
	grid.set_blocked(tile, true)
	field.compute(grid)
	events.append({"type": &"built", "tile": tile, "id": id})
	events.append({"type": &"path_changed"})
	return result


func sell(tile: Vector2i) -> int:
	if not towers.has(tile):
		return 0
	var refund := floori(towers[tile].invested * SELL_REFUND)
	gold += refund
	towers.erase(tile)
	grid.set_blocked(tile, false)
	field.compute(grid)
	events.append({"type": &"sold", "tile": tile, "refund": refund})
	events.append({"type": &"path_changed"})
	return refund


# --- Waves ------------------------------------------------------------------


## Starts the next wave now (also how `N` calls a wave early; waves may overlap).
func start_next_wave() -> void:
	if phase == Phase.DEFEAT or phase == Phase.VICTORY or wave >= WaveDefs.count():
		return
	wave += 1
	for type in WaveDefs.spawn_list(wave):
		_spawn_queue.append(type)
		_spawn_wave.append(wave)
	phase = Phase.WAVE
	countdown = -1.0
	events.append({"type": &"wave_started", "wave": wave})


func step() -> void:
	if phase == Phase.DEFEAT or phase == Phase.VICTORY:
		return
	time += DT
	if countdown >= 0.0:
		countdown -= DT
		if countdown <= 0.0:
			start_next_wave()
	_spawn()
	for c in creeps:
		if c.alive:
			_move(c)
	var alive: Array[SimCreep] = []
	for c in creeps:
		if c.alive:
			alive.append(c)
	creeps = alive
	_check_wave_cleared()


func _spawn() -> void:
	if _spawn_queue.is_empty():
		return
	_spawn_timer -= DT
	if _spawn_timer > 0.0:
		return
	var type: StringName = _spawn_queue.pop_front()
	var w: int = _spawn_wave.pop_front()
	var def: Dictionary = CreepDefs.CREEPS[type]
	var c := SimCreep.new()
	c.id = _next_id
	_next_id += 1
	c.type = type
	c.wave = w
	c.pos = Grid.SPAWN_POINT
	c.prev_pos = c.pos
	c.max_hp = CreepDefs.max_hp(type, w)
	c.hp = c.max_hp
	c.speed = def.speed
	c.armor = def.armor
	c.armor_class = def.class
	c.element = WaveDefs.element(w)
	c.flying = def.get("flying", false)
	c.boss = CreepDefs.is_boss(type)
	c.bounty = CreepDefs.bounty(w) * (10 if c.boss else 1)
	creeps.append(c)
	_spawn_timer = FAST_SPAWN_INTERVAL if def.speed >= 4.5 else SPAWN_INTERVAL
	events.append({"type": &"spawned", "id": c.id, "creep": type})


func _check_wave_cleared() -> void:
	if phase != Phase.WAVE or not _spawn_queue.is_empty() or not creeps.is_empty():
		return
	events.append({"type": &"wave_cleared", "wave": wave})
	if wave >= WaveDefs.count():
		phase = Phase.VICTORY
		events.append({"type": &"victory"})
		return
	phase = Phase.BUILD
	countdown = BREATHER


# --- Creeps -----------------------------------------------------------------


func _move(c: SimCreep) -> void:
	c.prev_pos = c.pos
	var target := _steer_target(c)
	var to := target - c.pos
	var d := to.length()
	if d > 0.0001:
		c.heading = to / d
		c.pos += c.heading * minf(c.speed * DT, d)
	if c.pos.y >= Grid.GATE_POINT.y - 0.05:
		_leak(c)


func _steer_target(c: SimCreep) -> Vector2:
	if c.flying:
		return Grid.GATE_POINT
	var t := Grid.tile_at(c.pos)
	if t.y < 0:
		return Grid.center(field.entry_tile())
	if not Grid.in_bounds(t) or field.distance(t) == 0.0:
		return Grid.GATE_POINT
	return Grid.center(field.next_tile(t))


func _leak(c: SimCreep) -> void:
	var cost := 2 if c.boss else 1
	lives = maxi(lives - cost, 0)
	c.leaked = true
	c.pos = Grid.SPAWN_POINT
	c.prev_pos = c.pos
	events.append({"type": &"leaked", "id": c.id, "cost": cost, "lives": lives})
	if lives == 0:
		phase = Phase.DEFEAT
		events.append({"type": &"defeat", "wave": wave})


## Removes a creep, paying its bounty unless it already leaked.
func kill(c: SimCreep) -> void:
	if not c.alive:
		return
	c.alive = false
	kills += 1
	var paid := 0 if c.leaked else c.bounty
	gold += paid
	gold_earned += paid
	events.append({"type": &"died", "id": c.id, "bounty": paid, "pos": c.pos})
