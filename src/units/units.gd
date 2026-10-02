class_name Units
extends Node3D
## Draws what the sim holds (GDD §7, §8, §12): creeps (pooled per type and
## interpolated between sim steps), towers (TowerView per tile) and shots in
## flight (ProjectileViews). Reads sim state every frame in sync() and reacts
## to sim events for one-off animation (flinch, death, recoil, build).

var _game: Game
var _creeps := {}
var _pools := {}
var _towers := {}
var _selling: Array[TowerView] = []
var _shots := ProjectileViews.new()
var _frame := 0
var _quality := 1.0
var _finished: Array[int] = []
var _cam_right := Vector3.RIGHT


func setup(game: Game) -> void:
	_game = game
	_shots.name = "Projectiles"
	add_child(_shots)
	_shots.setup(game)
	game.sim_event.connect(_on_sim_event)
	game.quality_changed.connect(_on_quality_changed)


## Called every frame by Game with the interpolation factor between steps.
func sync(alpha: float) -> void:
	_frame += 1
	var speed := 0.0 if _game.paused or _game.is_over() else float(_game.speed)
	var dt := get_process_delta_time() * speed
	_update_camera()
	for c in _game.sim.creeps:
		var v: CreepView = _creeps.get(c.id)
		if v == null:
			v = _acquire(c, alpha)
		v.stamp = _frame
		if not v.dying:
			v.update(c, alpha, dt, speed, _cam_right)
	_finished.clear()
	for id: int in _creeps:
		var v: CreepView = _creeps[id]
		if v.stamp == _frame:
			continue
		v.on_died()
		if v.update_dead(dt, speed):
			_finished.append(id)
	for id in _finished:
		_release(id)
	_sync_towers(dt)
	_shots.sync(alpha, dt)


func _update_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var basis := cam.global_basis
	_cam_right = basis.x
	var hit: Variant = Plane(Vector3.UP, Coords.PLATEAU_TOP).intersects_ray(
		cam.global_position, -basis.z
	)
	var dist := cam.global_position.distance_to(hit) if hit != null else 60.0
	UnitStyle.update_outlines(dist, cam.fov, get_viewport().get_visible_rect().size.y)


# --- Creeps -----------------------------------------------------------------


func _acquire(c: SimCreep, alpha: float) -> CreepView:
	var pool: Array = _pools.get(c.type, [])
	_pools[c.type] = pool
	var v: CreepView
	if pool.is_empty():
		v = CreepView.new()
		v.name = "%s_%d" % [c.type, c.id]
		add_child(v)
		v.setup(c.type)
		for p in v.emitters():
			ParticleKit.apply_quality(p, _quality)
	else:
		v = pool.pop_back()
	v.activate(c, alpha)
	_creeps[c.id] = v
	return v


func _release(id: int) -> void:
	var v: CreepView = _creeps[id]
	_creeps.erase(id)
	v.deactivate()
	(_pools[v.type] as Array).append(v)


func _creep_view(id: int) -> CreepView:
	return _creeps.get(id)


# --- Towers -----------------------------------------------------------------


func _sync_towers(dt: float) -> void:
	for tile: Vector2i in _towers:
		(_towers[tile] as TowerView).update(_game.sim.tower_at(tile), dt)
	for i in range(_selling.size() - 1, -1, -1):
		if not _selling[i].update(null, dt):
			_selling[i].queue_free()
			_selling.remove_at(i)


func _place_tower(tile: Vector2i) -> void:
	var t := _game.sim.tower_at(tile)
	if t == null:
		return
	_sell_tower(tile)
	var v := TowerView.new()
	v.name = "Tower_%d_%d" % [tile.x, tile.y]
	add_child(v)
	v.setup(t, _quality)
	_towers[tile] = v


func _refresh_tower(tile: Vector2i) -> void:
	var v: TowerView = _towers.get(tile)
	var t := _game.sim.tower_at(tile)
	if v == null or t == null:
		_place_tower(tile)
		return
	v.rebuild(t, &"pop")


func _sell_tower(tile: Vector2i) -> void:
	var v: TowerView = _towers.get(tile)
	if v == null:
		return
	_towers.erase(tile)
	v.start_sell()
	_selling.append(v)


# --- Events -----------------------------------------------------------------


func _on_sim_event(e: Dictionary) -> void:
	match e.type:
		&"built":
			_place_tower(e.tile)
		&"upgraded":
			_refresh_tower(e.tile)
		&"fused":
			_sell_tower(e.freed)
			_refresh_tower(e.tile)
		&"sold":
			_sell_tower(e.tile)
		&"fired":
			var tv: TowerView = _towers.get(e.tile)
			if tv:
				tv.on_fired()
		&"hit":
			var v := _creep_view(e.id)
			if v:
				v.on_hit(e.counter)
		&"died":
			var v := _creep_view(e.id)
			if v:
				v.on_died()
		&"downed":
			var v := _creep_view(e.id)
			if v:
				v.on_downed()
		&"revived":
			var v := _creep_view(e.id)
			if v:
				v.on_revived()
		&"heal":
			var v := _creep_view(e.id)
			if v:
				v.on_heal()
		&"summoned":
			var v := _creep_view(e.id)
			if v:
				v.on_cast()


func _on_quality_changed(_preset: Quality.Preset) -> void:
	_quality = _game.quality_settings.particles
	for type in _pools:
		for v: CreepView in _pools[type]:
			for p in v.emitters():
				ParticleKit.apply_quality(p, _quality)
	for id: int in _creeps:
		for p in (_creeps[id] as CreepView).emitters():
			ParticleKit.apply_quality(p, _quality)
	for tile: Vector2i in _towers:
		(_towers[tile] as TowerView).apply_quality(_quality)
	_shots.apply_quality(_quality)
