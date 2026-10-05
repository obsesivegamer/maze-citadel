class_name CreepView
extends Node3D
## One pooled creep on screen: interpolated position and facing, a run cycle
## whose speed follows the sim, flinches, status washes, vines, HP bar, and a
## death that sinks and fades after the sim has dropped the creep.

const TURN_RATE := 10.0
## Moves larger than this between frames are teleports (leak loop): snap.
const TELEPORT := 6.0
const FLY_BOB := 0.25
const FLASH_TIME := 0.08
const ONESHOT_BLEND := 0.08
const LOOP_BLEND := 0.18

const BAR_SIZE := Vector2(1.1, 0.13)
const BOSS_BAR_SIZE := Vector2(2.8, 0.24)
const BAR_BORDER := 0.05
const BAR_GAP := 0.45
const BAR_COLORS: Array[Color] = [
	Color(0.25, 0.95, 0.3), Color(1.0, 0.82, 0.15), Color(1.0, 0.22, 0.12)
]
const BOSS_BAR_COLOR := Color(1.0, 0.35, 0.95)
const BAR_BG := Color(0.03, 0.02, 0.02, 0.85)

const DEATH_HOLD := 1.0
const SINK_TIME := 1.5
const SINK_DEPTH := 1.4
const FALL_TIME := 0.55
## Ghoul: collapse duration, and how early the rise starts before revival.
const DOWN_TIME := 0.7
const RISE_LEAD := 0.85
const VINE_GROW := 0.15
const VINE_RADIUS := 0.32
const VINE_HEIGHT := 0.55

const OGRE_RING := Color(1.0, 0.32, 0.08, 0.6)
const OGRE_RING_SPIN := 0.6
const HEAL_PULSE := 0.6
const CAST_RATE := 1.3
## Blob shadow (UnitPerf creep-shadow=blob): darkness, radius per metre of height.
const BLOB := Color(0.0, 0.0, 0.0, 0.5)
const BLOB_RADIUS := 0.3
const BLOB_LIFT := 0.06

static var _bar_meshes := {}
static var _bar_mats := {}

var type: StringName
var id := -1
var dying := false
## Frame on which the sim last listed this creep.
var stamp := 0

var _rig: CreepModels.Rig
var _spec: Dictionary
var _boss := false
## Model scale: a Bulky creep (eletd) is drawn larger.
var _size := 1.0
var _fly := 0.0
var _age := 0.0
var _yaw := 0.0
var _hit_cd := 0.0
var _oneshot := 0.0
var _flash := 0.0
var _status := &"-"
var _plain := false
var _down := false
var _rising := false
var _death_t := 0.0
var _fall_from := 0.0
var _vine_t := 0.0
var _pulse := 0.0
var _bar_bucket := -1
var _bar_bg := MeshInstance3D.new()
var _bar_fill := MeshInstance3D.new()
var _vines := MeshInstance3D.new()
var _ring: MeshInstance3D
var _steam: GPUParticles3D
var _shroud: GPUParticles3D
var _blob: MeshInstance3D
var _emission_status := false
var _anim_rate := 1
var _anim_acc := 0.0


func setup(creep_type: StringName) -> void:
	type = creep_type
	_spec = CreepModels.spec(type)
	_boss = CreepDefs.is_boss(type)
	_fly = _spec.get("fly", 0.0)
	_rig = CreepModels.build(type)
	add_child(_rig.root)
	var size := BOSS_BAR_SIZE if _boss else BAR_SIZE
	_bar_bg.mesh = _bar_mesh(size + Vector2.ONE * BAR_BORDER * 2.0, false)
	_bar_bg.material_override = _bar_mat(BAR_BG, 10)
	_bar_fill.mesh = _bar_mesh(size, true)
	for n: GeometryInstance3D in [_bar_bg, _bar_fill, _vines]:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.visible = false
		add_child(n)
	_vines.mesh = UnitMeshes.vines()
	var r := clampf(_rig.height * VINE_RADIUS, 0.35, 1.0)
	_vines.scale = Vector3(r, _rig.height * VINE_HEIGHT, r)
	_vines.position.y = -0.05
	match type:
		&"ogre":
			_ring = MeshInstance3D.new()
			_ring.mesh = UnitMeshes.disc()
			_ring.material_override = UnitStyle.additive(OGRE_RING, UnitStyle.ring_texture())
			_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_ring.scale = Vector3.ONE * GameSim.OGRE_AURA_RADIUS
			_ring.position.y = 0.06
			add_child(_ring)
		&"steam_tank":
			_steam = ParticleKit.make(UnitFx.spec(&"steam"))
			_steam.position = Vector3(0, _rig.height * 0.82, -_rig.height * 0.18)
			_rig.root.add_child(_steam)
			_shroud = ParticleKit.make(UnitFx.spec(&"shroud"))
			_shroud.position.y = _rig.height * 0.5
			_shroud.emitting = false
			add_child(_shroud)
	_setup_perf()
	visible = false


## UnitPerf creep-status, creep-shadow and creep-anim-rate.
func _setup_perf() -> void:
	_emission_status = UnitPerf.creep_status() == "emission"
	if UnitPerf.creep_shadow() == "blob":
		_blob = MeshInstance3D.new()
		_blob.mesh = UnitMeshes.disc()
		_blob.material_override = UnitStyle.translucent(BLOB, UnitStyle.soft_dot())
		_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r := _rig.height * BLOB_RADIUS
		_blob.scale = Vector3(r, 1, r)
		add_child(_blob)
	_anim_rate = UnitPerf.creep_anim_rate()
	if _anim_rate > 1:
		for ap in [_rig.ap, _rig.rider_ap]:
			if ap != null:
				(ap as AnimationPlayer).callback_mode_process = (
					AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				)


func emitters() -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = []
	for p in [_steam, _shroud]:
		if p != null:
			out.append(p)
	return out


func activate(c: SimCreep, alpha: float) -> void:
	id = c.id
	dying = false
	_age = randf() * 10.0
	_hit_cd = 0.0
	_oneshot = 0.0
	_flash = 0.0
	_down = false
	_rising = false
	_death_t = 0.0
	_pulse = 0.0
	_vine_t = 0.0
	_bar_bucket = -1
	_status = &"-"
	_set_plain(false)
	for mi in _rig.meshes:
		mi.transparency = 0.0
	_rig.root.position = Vector3.ZERO
	_size = EletdRules.BULKY_SCALE if c.bulky else 1.0
	_rig.root.scale = Vector3.ONE * _size
	_yaw = atan2(c.heading.x, c.heading.y)
	_rig.root.rotation.y = _yaw
	if _ring:
		_ring.visible = true
	if _steam:
		_steam.emitting = true
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	_rig.ap.active = true
	if _rig.rider_ap:
		_rig.rider_ap.active = true
		_rig.rider_ap.play(&"Idle")
	_play_loop(0.0)
	position = _world(c, alpha)
	if _emission_status:
		_apply_materials()
	if _blob:
		_blob.transparency = 0.0
		_place_blob()
	if _anim_rate > 1:
		_anim_acc = 0.0
		_rig.ap.advance(0.0)
		if _rig.rider_ap:
			_rig.rider_ap.advance(0.0)


func deactivate() -> void:
	id = -1
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_rig.ap.active = false
	if _rig.rider_ap:
		_rig.rider_ap.active = false
	for p in emitters():
		p.emitting = false


## `dt` is game-scaled seconds (0 while paused); `speed` the game speed.
func update(c: SimCreep, alpha: float, dt: float, speed: float, cam_right: Vector3) -> void:
	_age += dt
	var target := _world(c, alpha)
	var jumped := target.distance_to(position) > TELEPORT
	position = target
	if c.effective_speed() > 0.01:
		var want := atan2(c.heading.x, c.heading.y)
		if jumped:
			_yaw = want
		_yaw = lerp_angle(_yaw, want, 1.0 - exp(-TURN_RATE * dt))
		_rig.root.rotation.y = _yaw
	_hit_cd -= dt
	if _down:
		_update_down(c)
		_rig.ap.speed_scale = speed
	elif _oneshot > 0.0:
		_oneshot -= dt
		_rig.ap.speed_scale = speed
		if _oneshot <= 0.0:
			_play_loop(LOOP_BLEND)
	else:
		_rig.ap.speed_scale = speed * c.effective_speed() / maxf(c.speed, 0.01)
	if _rig.rider_ap:
		_rig.rider_ap.speed_scale = speed
	_update_status(c, dt)
	_update_vines(c, dt)
	_update_bar(c, cam_right)
	_update_extras(c, dt)
	if _blob:
		_place_blob()
	if _anim_rate > 1:
		_advance_anim()


func on_hit(counter: StringName) -> void:
	if dying or _down:
		return
	if counter != &"immune":
		_flash = FLASH_TIME
	var hit: StringName = _spec.get("hit", &"")
	if _hit_cd <= 0.0 and hit != &"" and _rig.ap.has_animation(hit):
		_hit_cd = _spec.get("hit_cooldown", CreepModels.DEFAULT_HIT_COOLDOWN)
		_one_shot(hit, _spec.get("hit_rate", CreepModels.DEFAULT_HIT_RATE))


func on_cast() -> void:
	var cast: StringName = _spec.get("cast", &"")
	if cast != &"" and not dying and _rig.ap.has_animation(cast):
		_one_shot(cast, CAST_RATE)


func on_heal() -> void:
	_pulse = HEAL_PULSE


## Ghouls and Undying creeps fall; types without a "down" pose use their death.
func on_downed() -> void:
	var anim: StringName = _spec.get("down", _spec.get("death", &""))
	if anim == &"" or not _rig.ap.has_animation(anim):
		return
	_down = true
	_rising = false
	_oneshot = 0.0
	_rig.ap.play(anim, ONESHOT_BLEND, _rig.ap.get_animation(anim).length / DOWN_TIME)


func on_revived() -> void:
	if _down:
		_down = false
		_play_loop(LOOP_BLEND)


func on_died() -> void:
	if dying:
		return
	dying = true
	_down = false
	_death_t = 0.0
	_fall_from = position.y
	for n: Node3D in [_bar_bg, _bar_fill, _vines]:
		n.visible = false
	if _ring:
		_ring.visible = false
	for p in emitters():
		p.emitting = false
	_set_status(&"")
	var anim: StringName = _spec.death
	if _rig.ap.has_animation(anim):
		_rig.ap.play(anim, ONESHOT_BLEND)


## Advances the death; true once the body has sunk and faded.
func update_dead(dt: float, speed: float) -> bool:
	_death_t += dt
	_rig.ap.speed_scale = speed
	if _fly > 0.0:
		var k := clampf(_death_t / FALL_TIME, 0.0, 1.0)
		position.y = lerpf(_fall_from, Coords.PLATEAU_TOP, k * k)
	if _death_t > DEATH_HOLD:
		_set_plain(true)
		var k := clampf((_death_t - DEATH_HOLD) / SINK_TIME, 0.0, 1.0)
		_rig.root.position.y = -SINK_DEPTH * k * k
		for mi in _rig.meshes:
			mi.transparency = k
		if _blob:
			_blob.transparency = k
	if _blob:
		_place_blob()
	if _anim_rate > 1:
		_advance_anim()
	return _death_t >= DEATH_HOLD + SINK_TIME


func _world(c: SimCreep, alpha: float) -> Vector3:
	var h := 0.0
	if _fly > 0.0:
		h = _fly + sin(_age * 2.2 + id) * FLY_BOB
	return Coords.to_world(c.prev_pos.lerp(c.pos, alpha), Coords.PLATEAU_TOP + h)


func _play_loop(blend: float) -> void:
	var loop: StringName = _spec.loop
	if _rig.ap.has_animation(loop):
		_rig.ap.play(loop, blend, _spec.rate)


func _one_shot(anim: StringName, rate: float) -> void:
	_rig.ap.play(anim, ONESHOT_BLEND, rate)
	_oneshot = _rig.ap.get_animation(anim).length / rate


func _update_down(c: SimCreep) -> void:
	var rise: StringName = _spec.get("rise", &"")
	if _rising or rise == &"" or c.revive_time > RISE_LEAD or c.revive_time <= 0.0:
		return
	_rising = true
	_rig.ap.play(rise, ONESHOT_BLEND, _rig.ap.get_animation(rise).length / RISE_LEAD)


func _update_status(c: SimCreep, dt: float) -> void:
	var kind := &""
	if c.immune_time > 0.0:
		kind = &"immune"
	elif c.root_time > 0.0:
		kind = &"root"
	elif c.slow > 0.0 and not c.poison.is_empty():
		kind = &"slow_poison"
	elif c.slow > 0.0:
		kind = &"slow"
	elif not c.poison.is_empty():
		kind = &"poison"
	if _flash > 0.0:
		_flash -= dt
		kind = &"flash"
	_set_status(kind)


func _set_status(kind: StringName) -> void:
	if kind == _status:
		return
	_status = kind
	if _emission_status:
		_apply_materials()
		return
	var mat := UnitStyle.status_overlay(kind)
	for mi in _rig.meshes:
		mi.material_overlay = mat


func _set_plain(on: bool) -> void:
	if on == _plain:
		return
	_plain = on
	_apply_materials()


func _apply_materials() -> void:
	var sets: Array = _rig.plain if _plain else _rig.outlined
	if _emission_status and not _plain and _status != &"" and _status != &"-":
		sets = CreepModels.status_set(_rig, _status)
	for i in _rig.meshes.size():
		var mats: Array = sets[i]
		for s in mats.size():
			_rig.meshes[i].set_surface_override_material(s, mats[s])


func _update_vines(c: SimCreep, dt: float) -> void:
	var rooted := c.root_time > 0.0 and not _boss and not _down
	_vine_t = clampf(_vine_t + (dt if rooted else -dt * 2.0), 0.0, VINE_GROW)
	_vines.visible = _vine_t > 0.0
	if _vines.visible:
		var k := _vine_t / VINE_GROW
		var r := _vines.scale.x
		_vines.scale = Vector3(r, maxf(_rig.height * VINE_HEIGHT * k, 0.01), r)


func _update_bar(c: SimCreep, cam_right: Vector3) -> void:
	var frac := clampf(c.hp / maxf(c.max_hp, 0.001), 0.0, 1.0)
	var show := (_boss or frac < 0.999) and not _down and frac > 0.0
	_bar_bg.visible = show
	_bar_fill.visible = show
	if not show:
		return
	var size := BOSS_BAR_SIZE if _boss else BAR_SIZE
	var center := Vector3(0, _rig.height * _size + BAR_GAP, 0)
	_bar_bg.position = center
	_bar_fill.position = center - cam_right * size.x * 0.5
	_bar_fill.scale = Vector3(maxf(frac, 0.001), 1, 1)
	var bucket := 3 if _boss else (0 if frac > 0.6 else (1 if frac > 0.3 else 2))
	if bucket != _bar_bucket:
		_bar_bucket = bucket
		var col: Color = BOSS_BAR_COLOR if bucket == 3 else BAR_COLORS[bucket]
		_bar_fill.material_override = _bar_mat(col, 11)


## Keeps the blob on the plateau under fliers and falling bodies.
func _place_blob() -> void:
	_blob.position.y = Coords.PLATEAU_TOP + BLOB_LIFT - position.y


## Manual animation callback: one advance every `_anim_rate` frames,
## staggered by id so creeps don't all update on the same frame.
func _advance_anim() -> void:
	_anim_acc += get_process_delta_time()
	if (Engine.get_process_frames() + id) % _anim_rate != 0:
		return
	_rig.ap.advance(_anim_acc)
	if _rig.rider_ap:
		_rig.rider_ap.advance(_anim_acc)
	_anim_acc = 0.0


func _update_extras(c: SimCreep, dt: float) -> void:
	if _ring:
		_ring.rotation.y += OGRE_RING_SPIN * dt
	if _shroud:
		_shroud.emitting = c.immune_time > 0.0
	if _rig.staff_glow:
		_pulse = maxf(_pulse - dt, 0.0)
		var k := sin(_pulse / HEAL_PULSE * PI) if _pulse > 0.0 else 0.0
		_rig.staff_glow.scale = Vector3.ONE * (1.0 + 1.6 * k)


## Bar quads: a centred background and a fill anchored at its left edge, so
## scaling the fill node's x shrinks it toward the left.
static func _bar_mesh(size: Vector2, left_anchored: bool) -> QuadMesh:
	var key := "%s%s" % [size, left_anchored]
	if not _bar_meshes.has(key):
		var q := QuadMesh.new()
		q.size = size
		if left_anchored:
			q.center_offset = Vector3(size.x * 0.5, 0, 0)
		_bar_meshes[key] = q
	return _bar_meshes[key]


static func _bar_mat(color: Color, priority: int) -> StandardMaterial3D:
	var key := "%s%d" % [color, priority]
	if not _bar_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.no_depth_test = true
		m.albedo_color = color
		m.render_priority = priority
		m.disable_receive_shadows = true
		_bar_mats[key] = m
	return _bar_mats[key]
