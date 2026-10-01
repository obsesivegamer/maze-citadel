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
const INTEREST_PERIOD := 15.0
const INTEREST_RATE := 0.02
const INTEREST_CAP := 20
const HARD_HP := 1.3
const HARD_BOUNTY := 1.2
const INFINITE_HP_GROWTH := 1.08
const DOT_REPORT_PERIOD := 0.5

const TANK_IMMUNE_PERIOD := 6.0
const TANK_IMMUNE_TIME := 1.5
const HEAL_PERIOD := 2.0
const HEAL_RADIUS := 5.0
const HEAL_FRACTION := 0.04
const GHOUL_REVIVE_TIME := 1.5
const OGRE_AURA_RADIUS := 6.0
const OGRE_AURA_ARMOR := 3.0
const OGRE_AURA_HASTE := 0.1
const SUMMON_PERIOD := 10.0
const SUMMON_COUNT := 3
const SHRED_MAX := 10.0
const SHRED_TIME := 6.0
const BOLT_HIT_RADIUS := 0.8

var grid := Grid.new()
var field := FlowField.new()
var gold := START_GOLD
var lives := START_LIVES
var phase := Phase.BUILD
var hard := false
var infinite := false
## Last wave started; 0 before wave 1.
var wave := 0
## Seconds until the next wave starts on its own; -1 while one is running.
var countdown := OPENING_BUILD_TIME
var interest_timer := INTEREST_PERIOD
var time := 0.0
var kills := 0
var gold_earned := 0
var creeps: Array[SimCreep] = []
var towers := {}
var projectiles: Array[SimProjectile] = []
var zones: Array[SimZone] = []
var events: Array[Dictionary] = []

var _by_id := {}
var _spawn_queue: Array = []
var _spawn_timer := 0.0
var _next_id := 1


func _init() -> void:
	field.compute(grid)


func drain_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out


func score() -> int:
	var s := 10 * kills + 500 * lives + gold
	return roundi(s * (1.3 if hard else 1.0))


func creep(id: int) -> SimCreep:
	return _by_id.get(id)


func tower_at(tile: Vector2i) -> SimTower:
	return towers.get(tile)


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
	var t := SimTower.new()
	t.id = id
	t.tile = tile
	t.pos = Grid.center(tile)
	t.invested = cost
	towers[tile] = t
	grid.set_blocked(tile, true)
	field.compute(grid)
	_refresh_auras()
	events.append({"type": &"built", "tile": tile, "id": id})
	events.append({"type": &"path_changed"})
	return result


func sell(tile: Vector2i) -> int:
	var t := tower_at(tile)
	if t == null:
		return 0
	var refund := floori(t.invested * SELL_REFUND)
	gold += refund
	_remove_tower(t)
	events.append({"type": &"sold", "tile": tile, "refund": refund})
	return refund


func upgrade(tile: Vector2i) -> bool:
	var t := tower_at(tile)
	if t == null or t.level >= t.max_level():
		return false
	var cost := TowerDefs.upgrade_cost(t.id, t.level)
	if gold < cost:
		return false
	gold -= cost
	t.level += 1
	t.invested += cost
	_refresh_auras()
	events.append({"type": &"upgraded", "tile": tile, "level": t.level})
	return true


## The Epic that two towers would fuse into, or &"" if they can't.
func fusion_result(a_tile: Vector2i, b_tile: Vector2i) -> StringName:
	var a := tower_at(a_tile)
	var b := tower_at(b_tile)
	if a == null or b == null or a == b or a.is_epic() or b.is_epic():
		return &""
	if a.level < TowerDefs.MAX_LEVEL or b.level < TowerDefs.MAX_LEVEL:
		return &""
	if a.family() != b.family():
		return &""
	return TowerDefs.FUSIONS.get(a.family(), &"")


## Fuses two max-level towers of one family into an Epic on `a_tile`; the
## second tile is freed (which can only open the maze, never block it).
func fuse(a_tile: Vector2i, b_tile: Vector2i) -> bool:
	var epic := fusion_result(a_tile, b_tile)
	if epic == &"":
		return false
	var cost: int = TowerDefs.TOWERS[epic].fuse_cost
	if gold < cost:
		return false
	gold -= cost
	var a := tower_at(a_tile)
	var b := tower_at(b_tile)
	var invested := a.invested + b.invested + cost
	_remove_tower(b)
	a.id = epic
	a.level = 1
	a.invested = invested
	a.cooldown = 0.0
	a.clouds = 0
	_refresh_auras()
	events.append({"type": &"fused", "tile": a_tile, "freed": b_tile, "id": epic})
	return true


func _remove_tower(t: SimTower) -> void:
	towers.erase(t.tile)
	grid.set_blocked(t.tile, false)
	field.compute(grid)
	_refresh_auras()
	events.append({"type": &"path_changed"})


## Each tower takes the strongest Bard aura covering it (auras don't stack).
func _refresh_auras() -> void:
	for t in towers.values():
		t.aura = 0.0
		t.haste = 0.0
	for bard in towers.values():
		if bard.stat("kind") != &"aura":
			continue
		var r: float = bard.stat("range")
		for t in towers.values():
			if t != bard and t.pos.distance_to(bard.pos) <= r:
				t.aura = maxf(t.aura, bard.stat("aura_damage"))
				t.haste = maxf(t.haste, bard.stat("aura_haste"))


# --- Waves ------------------------------------------------------------------


func last_wave() -> int:
	return 1_000_000 if infinite else WaveDefs.count()


## Starts the next wave now (also how `N` calls a wave early; waves may overlap).
func start_next_wave() -> void:
	if phase == Phase.DEFEAT or phase == Phase.VICTORY or wave >= last_wave():
		return
	wave += 1
	for entry in WaveDefs.spawn_list(wave):
		_spawn_queue.append([entry[0], entry[1], wave])
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
	_pay_interest()
	_spawn()
	_update_auras_on_creeps()
	for c: SimCreep in creeps.duplicate():
		if c.alive:
			_update_creep(c)
	for c in creeps:
		if c.alive:
			_move(c)
	for t in towers.values():
		_tower_act(t)
	_update_projectiles()
	_update_zones()
	_cleanup()
	_check_wave_cleared()


func _pay_interest() -> void:
	interest_timer -= DT
	if interest_timer > 0.0:
		return
	interest_timer += INTEREST_PERIOD
	var amount := mini(floori(gold * INTEREST_RATE), INTEREST_CAP)
	gold += amount
	gold_earned += amount
	events.append({"type": &"interest", "amount": amount})


func _spawn() -> void:
	if _spawn_queue.is_empty():
		return
	_spawn_timer -= DT
	if _spawn_timer > 0.0:
		return
	var entry: Array = _spawn_queue.pop_front()
	var c := spawn_creep(entry[0], entry[1], entry[2], Grid.SPAWN_POINT)
	_spawn_timer = FAST_SPAWN_INTERVAL if c.speed >= 4.5 else SPAWN_INTERVAL


func spawn_creep(type: StringName, element: StringName, w: int, at: Vector2) -> SimCreep:
	var def: Dictionary = CreepDefs.CREEPS[type]
	var c := SimCreep.new()
	c.id = _next_id
	_next_id += 1
	c.type = type
	c.wave = w
	c.pos = at
	c.prev_pos = at
	var hp_mult := HARD_HP if hard else 1.0
	if w > WaveDefs.count():
		hp_mult *= pow(INFINITE_HP_GROWTH, w - WaveDefs.count())
	c.max_hp = CreepDefs.max_hp(type, w, hp_mult)
	c.hp = c.max_hp
	c.speed = def.speed
	c.armor = def.armor
	c.armor_class = def.class
	c.element = element
	c.flying = def.get("flying", false)
	c.boss = CreepDefs.is_boss(type)
	var bounty_mult := HARD_BOUNTY if hard else 1.0
	var boss_mult := 25 if type == &"dreadlord" else (10 if c.boss else 1)
	c.bounty = roundi(CreepDefs.bounty(w) * boss_mult * bounty_mult)
	match type:
		&"steam_tank":
			c.ability_timer = TANK_IMMUNE_PERIOD
		&"priestess":
			c.ability_timer = HEAL_PERIOD
		&"dreadlord":
			c.ability_timer = SUMMON_PERIOD
	creeps.append(c)
	_by_id[c.id] = c
	events.append({"type": &"spawned", "id": c.id, "creep": type})
	return c


func _check_wave_cleared() -> void:
	if phase != Phase.WAVE or not _spawn_queue.is_empty() or not creeps.is_empty():
		return
	events.append({"type": &"wave_cleared", "wave": wave})
	if wave >= last_wave():
		phase = Phase.VICTORY
		events.append({"type": &"victory"})
		return
	phase = Phase.BUILD
	countdown = BREATHER


# --- Creeps -----------------------------------------------------------------


func _update_auras_on_creeps() -> void:
	for c in creeps:
		c.aura_armor = 0.0
		c.aura_haste = 0.0
	for ogre in creeps:
		if ogre.type != &"ogre" or not ogre.targetable():
			continue
		for c in creeps:
			if c != ogre and c.pos.distance_to(ogre.pos) <= OGRE_AURA_RADIUS:
				c.aura_armor = OGRE_AURA_ARMOR
				c.aura_haste = OGRE_AURA_HASTE


func _update_creep(c: SimCreep) -> void:
	if c.revive_time > 0.0:
		c.revive_time -= DT
		if c.revive_time <= 0.0:
			c.hp = c.max_hp / 3.0
			events.append({"type": &"revived", "id": c.id})
		return
	c.slow_time -= DT
	if c.slow_time <= 0.0:
		c.slow = 0.0
	c.root_time = maxf(c.root_time - DT, 0.0)
	c.immune_time = maxf(c.immune_time - DT, 0.0)
	c.shred_time -= DT
	if c.shred_time <= 0.0:
		c.shred = 0.0
	_tick_poison(c)
	if not c.alive:
		return
	match c.type:
		&"steam_tank":
			c.ability_timer -= DT
			if c.ability_timer <= 0.0:
				c.ability_timer += TANK_IMMUNE_PERIOD
				c.immune_time = TANK_IMMUNE_TIME
				events.append({"type": &"immune", "id": c.id})
		&"priestess":
			c.ability_timer -= DT
			if c.ability_timer <= 0.0:
				c.ability_timer += HEAL_PERIOD
				_heal_around(c)
		&"dreadlord":
			c.ability_timer -= DT
			if c.ability_timer <= 0.0:
				c.ability_timer += SUMMON_PERIOD
				for i in SUMMON_COUNT:
					var offset := Vector2.from_angle(TAU * i / SUMMON_COUNT) * 1.2
					spawn_creep(&"felhound", &"dark", c.wave, c.pos + offset)
				events.append({"type": &"summoned", "id": c.id})


func _heal_around(priestess: SimCreep) -> void:
	for c in creeps:
		if c == priestess or not c.targetable():
			continue
		if c.pos.distance_to(priestess.pos) > HEAL_RADIUS or c.hp >= c.max_hp:
			continue
		var amount := c.max_hp * HEAL_FRACTION * (0.5 if not c.poison.is_empty() else 1.0)
		c.hp = minf(c.hp + amount, c.max_hp)
	events.append({"type": &"heal", "id": priestess.id})


func _tick_poison(c: SimCreep) -> void:
	if c.poison.is_empty():
		return
	var total := 0.0
	for i in range(c.poison.size() - 1, -1, -1):
		total += c.poison[i].x * DT
		c.poison[i].y -= DT
		if c.poison[i].y <= 0.0:
			c.poison.remove_at(i)
	_apply_dot(c, total, null)


func _move(c: SimCreep) -> void:
	c.prev_pos = c.pos
	var target := _steer_target(c)
	var to := target - c.pos
	var d := to.length()
	if d > 0.0001:
		c.heading = to / d
		c.pos += c.heading * minf(c.effective_speed() * DT, d)
	c.progress = _progress(c)
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


func _progress(c: SimCreep) -> float:
	if c.flying:
		return Grid.GATE_POINT.distance_to(c.pos)
	var t := Grid.tile_at(c.pos)
	if t.y < 0:
		return field.distance(field.entry_tile()) * Grid.TILE + Grid.TILE
	if not Grid.in_bounds(t):
		return 0.0
	return field.distance(t) * Grid.TILE + c.pos.distance_to(Grid.center(t)) * 0.1


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
func kill(c: SimCreep, by: SimTower = null) -> void:
	if not c.alive:
		return
	c.alive = false
	kills += 1
	var paid := 0 if c.leaked else c.bounty
	gold += paid
	gold_earned += paid
	if by != null:
		by.kills += 1
	events.append({"type": &"died", "id": c.id, "bounty": paid, "pos": c.pos})


func _cleanup() -> void:
	var alive: Array[SimCreep] = []
	for c in creeps:
		if c.alive:
			alive.append(c)
		else:
			_by_id.erase(c.id)
	creeps = alive


# --- Damage -----------------------------------------------------------------


## A direct hit. Returns the damage dealt.
func hit(c: SimCreep, base: float, t: SimTower, aura: float) -> float:
	if not c.targetable() or base <= 0.0:
		return 0.0
	if c.immune_time > 0.0:
		events.append({"type": &"hit", "id": c.id, "amount": 0.0, "counter": &"immune"})
		return 0.0
	var attack: StringName = t.stat("attack")
	var element: StringName = t.stat("element")
	var amount := Damage.amount(base, attack, element, c, aura, c.effective_armor())
	c.hp -= amount
	t.damage_dealt += amount
	var counter := Damage.counter(element, c.element)
	events.append({"type": &"hit", "id": c.id, "amount": amount, "counter": counter})
	if c.hp <= 0.0:
		_on_zero_hp(c, t)
	return amount


func _apply_dot(c: SimCreep, amount: float, t: SimTower) -> void:
	if not c.targetable() or c.immune_time > 0.0 or amount <= 0.0:
		return
	c.hp -= amount
	if t != null:
		t.damage_dealt += amount
	c.dot_accum += amount
	c.dot_timer -= DT
	if c.dot_timer <= 0.0:
		c.dot_timer = DOT_REPORT_PERIOD
		events.append({"type": &"dot", "id": c.id, "amount": c.dot_accum})
		c.dot_accum = 0.0
	if c.hp <= 0.0:
		_on_zero_hp(c, t)


func _on_zero_hp(c: SimCreep, t: SimTower) -> void:
	if c.type == &"ghoul" and not c.revived:
		c.revived = true
		c.revive_time = GHOUL_REVIVE_TIME
		c.hp = 0.0
		c.poison.clear()
		c.slow = 0.0
		events.append({"type": &"downed", "id": c.id})
		return
	kill(c, t)


## Damage, slows, roots, poison and shred all bounce off an immune creep.
func affectable(c: SimCreep) -> bool:
	return c.targetable() and c.immune_time <= 0.0


func apply_slow(c: SimCreep, amount: float, duration: float) -> void:
	if not affectable(c):
		return
	if c.boss:
		duration *= 0.5
	if amount > c.slow + 0.001 or c.slow_time <= 0.0:
		c.slow = amount
		c.slow_time = duration
	elif absf(amount - c.slow) <= 0.001:
		c.slow_time = maxf(c.slow_time, duration)


func apply_root(c: SimCreep, duration: float) -> void:
	if affectable(c) and not c.boss:
		c.root_time = maxf(c.root_time, duration)


# --- Towers -----------------------------------------------------------------


func _targets_in_range(t: SimTower, count: int) -> Array[SimCreep]:
	var r: float = t.stat("range")
	var min_r: float = t.stat("min_range", 0.0)
	var air: bool = t.stat("air", false)
	var found: Array[SimCreep] = []
	for c in creeps:
		if not c.targetable() or (c.flying and not air):
			continue
		var d := c.pos.distance_to(t.pos)
		if d <= r and d >= min_r:
			found.append(c)
	found.sort_custom(func(a: SimCreep, b: SimCreep) -> bool: return a.progress < b.progress)
	return found.slice(0, count)


func _tower_act(t: SimTower) -> void:
	var kind: StringName = t.stat("kind")
	if kind == &"aura":
		return
	t.cooldown -= DT * (1.0 + t.haste)
	if t.cooldown > 0.0:
		return
	var fired := false
	match kind:
		&"projectile":
			for c in _targets_in_range(t, t.stat("multishot", 1)):
				_launch(t, &"homing", c)
				fired = true
		&"shell", &"bolt":
			var found := _targets_in_range(t, 1)
			if not found.is_empty():
				_launch(t, &"shell" if kind == &"shell" else &"bolt", found[0])
				fired = true
		&"nova":
			fired = _nova(t)
		&"cloud":
			fired = _cloud(t)
		&"cone":
			fired = _cone(t)
	if fired:
		t.shots += 1
		t.cooldown = t.stat("cooldown")


func _launch(t: SimTower, kind: StringName, c: SimCreep) -> void:
	var p := SimProjectile.new()
	p.kind = kind
	p.tower = t
	p.level = t.level
	p.aura = t.aura
	p.shot = t.shots + 1
	p.start = t.pos
	p.pos = t.pos
	p.target_id = c.id
	p.speed = t.stat("speed", 20.0)
	t.aim = (c.pos - t.pos).normalized()
	match kind:
		&"shell":
			p.flight_time = t.stat("flight_time")
			p.time_left = p.flight_time
			p.target_point = c.pos + c.heading * c.effective_speed() * p.flight_time
		&"bolt":
			p.direction = t.aim
			p.max_distance = t.stat("range") + 1.0
	projectiles.append(p)
	events.append({"type": &"fired", "tile": t.tile, "kind": kind, "target": c.id})


func _update_projectiles() -> void:
	var keep: Array[SimProjectile] = []
	for p in projectiles:
		match p.kind:
			&"homing":
				_step_homing(p)
			&"shell":
				_step_shell(p)
			&"bolt":
				_step_bolt(p)
		if p.alive:
			keep.append(p)
	projectiles = keep


func _step_homing(p: SimProjectile) -> void:
	var c := creep(p.target_id)
	if c == null or not c.targetable():
		p.alive = false
		return
	var to := c.pos - p.pos
	var step := p.speed * DT
	if to.length() > step:
		p.pos += to.normalized() * step
		return
	p.pos = c.pos
	p.alive = false
	_on_direct_hit(p, c)


func _on_direct_hit(p: SimProjectile, c: SimCreep) -> void:
	var t := p.tower
	var lvl := p.level
	hit(c, TowerDefs.stat(t.id, "damage", lvl), t, p.aura)
	match t.id:
		&"frost":
			var slow: float = TowerDefs.stat(t.id, "slow", lvl)
			var slow_time: float = TowerDefs.stat(t.id, "slow_time", lvl)
			var splash: float = TowerDefs.stat(t.id, "slow_splash", lvl)
			var ring_every: int = TowerDefs.stat(t.id, "ring_every", lvl)
			var radius := splash
			if ring_every > 0 and p.shot % ring_every == 0:
				radius = TowerDefs.stat(t.id, "ring_radius", lvl)
				events.append({"type": &"frost_ring", "pos": c.pos, "radius": radius})
			for other in creeps:
				if other == c or (radius > 0.0 and other.pos.distance_to(c.pos) <= radius):
					if other.targetable():
						apply_slow(other, slow, slow_time)
		&"plague":
			if not affectable(c):
				return
			var dps: float = TowerDefs.stat(t.id, "poison_dps", lvl)
			dps *= Damage.element_mult(TowerDefs.stat(t.id, "element"), c.element)
			dps *= 1.0 + p.aura
			c.poison.append(Vector2(dps, TowerDefs.stat(t.id, "poison_time", lvl)))
			if c.poison.size() > TowerDefs.stat(t.id, "poison_stacks", lvl):
				c.poison.remove_at(0)
		&"runesmith":
			if affectable(c):
				c.shred = minf(c.shred + TowerDefs.stat(t.id, "shred", lvl), SHRED_MAX)
				c.shred_time = SHRED_TIME


func _step_shell(p: SimProjectile) -> void:
	p.time_left -= DT
	var k := 1.0 - maxf(p.time_left, 0.0) / p.flight_time
	p.pos = p.start.lerp(p.target_point, k)
	if p.time_left > 0.0:
		return
	p.alive = false
	var t := p.tower
	var radius: float = TowerDefs.stat(t.id, "splash", p.level)
	var base: float = TowerDefs.stat(t.id, "damage", p.level)
	for c: SimCreep in creeps.duplicate():
		if c.flying:
			continue
		var d := c.pos.distance_to(p.target_point)
		if d <= radius:
			hit(c, base * (1.0 - 0.5 * d / radius), t, p.aura)
	events.append({"type": &"shell_landed", "pos": p.target_point, "radius": radius, "tower": t.id})
	var crater_dps: float = TowerDefs.stat(t.id, "crater_dps", p.level, 0.0)
	if crater_dps > 0.0:
		var z := SimZone.new()
		z.kind = &"crater"
		z.tower = t
		z.pos = p.target_point
		z.radius = TowerDefs.stat(t.id, "crater_radius", p.level)
		z.dps = crater_dps
		z.time_left = TowerDefs.stat(t.id, "crater_time", p.level)
		z.aura = p.aura
		zones.append(z)


func _step_bolt(p: SimProjectile) -> void:
	var step := p.speed * DT
	p.pos += p.direction * step
	p.travelled += step
	var pierce: int = TowerDefs.stat(p.tower.id, "pierce", p.level)
	var base: float = TowerDefs.stat(p.tower.id, "damage", p.level)
	for c in creeps:
		if p.hit_ids.size() >= pierce:
			break
		if not c.targetable() or c.id in p.hit_ids:
			continue
		if c.pos.distance_to(p.pos) <= BOLT_HIT_RADIUS:
			p.hit_ids.append(c.id)
			hit(c, base, p.tower, p.aura)
	if p.travelled >= p.max_distance or p.hit_ids.size() >= pierce:
		p.alive = false


func _nova(t: SimTower) -> bool:
	var r: float = t.stat("range")
	var victims: Array[SimCreep] = []
	for c in creeps:
		if c.targetable() and not c.flying and c.pos.distance_to(t.pos) <= r:
			victims.append(c)
	if victims.is_empty():
		return false
	for c in victims:
		hit(c, t.stat("damage"), t, t.aura)
		if c.targetable():
			apply_slow(c, t.stat("slow"), t.stat("slow_time"))
			apply_root(c, t.stat("root"))
	events.append({"type": &"nova", "tile": t.tile, "radius": r})
	return true


func _cloud(t: SimTower) -> bool:
	if t.clouds >= int(t.stat("max_clouds")):
		return false
	var found := _targets_in_range(t, 1)
	if found.is_empty():
		return false
	var c := found[0]
	var z := SimZone.new()
	z.kind = &"cloud"
	z.tower = t
	z.pos = c.pos + c.heading * c.effective_speed() * 0.5
	z.radius = t.stat("cloud_radius")
	z.dps = t.stat("cloud_dps")
	z.time_left = t.stat("cloud_time")
	z.aura = t.aura
	zones.append(z)
	t.clouds += 1
	t.aim = (c.pos - t.pos).normalized()
	events.append({"type": &"cloud", "tile": t.tile, "pos": z.pos, "radius": z.radius})
	return true


func _cone(t: SimTower) -> bool:
	var found := _targets_in_range(t, 1)
	if found.is_empty():
		return false
	t.aim = (found[0].pos - t.pos).normalized()
	var half := deg_to_rad(float(t.stat("cone_degrees")) * 0.5)
	var freeze_every: int = t.stat("freeze_every", 0)
	var freeze := freeze_every > 0 and (t.shots + 1) % freeze_every == 0
	for c: SimCreep in creeps.duplicate():
		if not c.targetable() or c.pos.distance_to(t.pos) > float(t.stat("range")):
			continue
		if absf(t.aim.angle_to(c.pos - t.pos)) > half:
			continue
		hit(c, t.stat("damage"), t, t.aura)
		if c.targetable():
			apply_slow(c, t.stat("slow"), t.stat("slow_time"))
			if freeze:
				apply_root(c, t.stat("freeze"))
	events.append({"type": &"breath", "tile": t.tile, "aim": t.aim, "freeze": freeze})
	return true


func _update_zones() -> void:
	var keep: Array[SimZone] = []
	for z in zones:
		z.time_left -= DT
		var attack: StringName = z.tower.stat("attack")
		var element: StringName = z.tower.stat("element")
		for c in creeps:
			if c.flying or not c.targetable() or c.pos.distance_to(z.pos) > z.radius:
				continue
			var a := Damage.amount(z.dps * DT, attack, element, c, z.aura, c.effective_armor())
			_apply_dot(c, a, z.tower)
		if z.time_left > 0.0:
			keep.append(z)
		elif z.kind == &"cloud":
			z.tower.clouds = maxi(z.tower.clouds - 1, 0)
	zones = keep
