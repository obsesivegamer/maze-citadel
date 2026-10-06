class_name BuildController
extends Node3D
## Mouse and hotkey input for building and selecting (GDD §10). Shows the
## snapped ghost (green = valid, red = refused) and the reach of the ghost, the
## hovered tower or the selected tower only: a square round the tiles it reaches
## under the default Element TD rules, a range ring under classic.

const GHOST_OK := Color(0.3, 1.0, 0.45, 0.45)
const GHOST_BAD := Color(1.0, 0.2, 0.15, 0.5)
const RING_COLOR := Color(1.0, 0.95, 0.6, 0.85)
const PARTNER_COLOR := Color(1.0, 0.8, 0.25, 0.9)
const GHOST_LIFT := 1.2
const MAX_PARTNER_RINGS := 16

var hover_tile := Game.NONE
var hover_result := Placement.Result.OUT_OF_BOUNDS

var _game: Game
var _ghost := MeshInstance3D.new()
var _ghost_mat := StandardMaterial3D.new()
var _ring := MeshInstance3D.new()
var _ring_mesh := TorusMesh.new()
var _reach_square := Node3D.new()
## While fusing: the selected tower waits for a second click on its partner.
var _fusing := false
var _refusal_shake := 0.0
## Seconds until the ghost's validity is re-checked (creeps move under it).
var _recheck := 0.0
var _partner_rings: Array[MeshInstance3D] = []
var _ghost_id: StringName = &""


func setup(game: Game) -> void:
	_game = game
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 2.4, 1.8)
	_ghost.mesh = box
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = GHOST_OK
	_ghost.material_override = _ghost_mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	_ring_mesh.rings = 96
	_ring_mesh.ring_segments = 6
	_ring.mesh = _ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = RING_COLOR
	ring_mat.no_depth_test = true
	_ring.material_override = ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var side := Grid.TILE * 3.0
	for i in 4:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(side + 0.16, 0.12, 0.16) if i < 2 else Vector3(0.16, 0.12, side + 0.16)
		bar.mesh = mesh
		var off := side / 2.0 * (1.0 if i % 2 == 0 else -1.0)
		bar.position = Vector3(0, 0, off) if i < 2 else Vector3(off, 0, 0)
		bar.material_override = ring_mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_reach_square.add_child(bar)
	add_child(_reach_square)
	var partner_mesh := TorusMesh.new()
	partner_mesh.inner_radius = 1.05
	partner_mesh.outer_radius = 1.3
	var partner_mat := ring_mat.duplicate() as StandardMaterial3D
	partner_mat.albedo_color = PARTNER_COLOR
	for i in MAX_PARTNER_RINGS:
		var r := MeshInstance3D.new()
		r.mesh = partner_mesh
		r.material_override = partner_mat
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		_partner_rings.append(r)
	game.build_choice_changed.connect(_on_build_choice)
	_on_build_choice(game.build_choice)
	game.sim_event.connect(_on_sim_event)


func is_fusing() -> bool:
	return _fusing


## Arms fusion: the next click on a matching level-3 tower fuses the pair.
func start_fuse() -> void:
	_fusing = _game.selected != Game.NONE


func cancel_fuse() -> void:
	_fusing = false


## Swaps the translucent box for a real tower model (TowerVisuals.build).
## The ghost's origin floats GHOST_LIFT above the tile, the model's sits on it.
func set_ghost_model(node: Node3D) -> void:
	for c in _ghost.get_children():
		c.queue_free()
	_ghost.mesh = null
	node.position.y = -GHOST_LIFT
	_ghost.add_child(node)
	_apply_ghost_material(node)


func _on_build_choice(id: StringName) -> void:
	_fusing = false
	if id != &"" and id != _ghost_id:
		_ghost_id = id
		set_ghost_model(TowerVisuals.build(id, 1))


func _apply_ghost_material(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = _ghost_mat
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_apply_ghost_material(c)


func _on_sim_event(e: Dictionary) -> void:
	if e.type == &"path_changed" or e.type == &"build_refused":
		_recheck = 0.0


## Nothing until the game has booted: the builder is up frames before the
## loading screen goes, and N or Space there would start or pause the match
## unseen.
func _unhandled_input(event: InputEvent) -> void:
	if not _game.is_booted:
		return
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		_update_hover(mb.position)
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.alt_pressed:
			_left_click(mb.shift_pressed)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_right_click()
			get_viewport().set_input_as_handled()
	else:
		_hotkeys(event)


func _hotkeys(event: InputEvent) -> void:
	for i in TowerDefs.BUILD_ORDER.size():
		if event.is_action_pressed(StringName("build_%d" % i)):
			_game.choose_build(TowerDefs.BUILD_ORDER[i])
			return
	if event.is_action_pressed(&"deselect"):
		_fusing = false
		_game.choose_build(&"")
		_game.select(Game.NONE)
	elif event.is_action_pressed(&"sell"):
		_game.sell_selected()
	elif event.is_action_pressed(&"upgrade"):
		_game.upgrade_selected()
	elif event.is_action_pressed(&"fuse"):
		start_fuse()
	elif event.is_action_pressed(&"pause"):
		_game.toggle_pause()
	elif event.is_action_pressed(&"speed"):
		_game.cycle_speed()
	elif event.is_action_pressed(&"next_wave"):
		_game.call_next_wave()


func _left_click(keep_building: bool) -> void:
	if _fusing:
		_fusing = false
		_game.fuse_selected_with(hover_tile)
		return
	if _game.build_choice != &"":
		var choice := _game.build_choice
		if _game.build_at(hover_tile) == Placement.Result.OK:
			if not keep_building:
				_game.choose_build(&"")
		else:
			_refusal_shake = 0.25
		if keep_building:
			_game.build_choice = choice
		return
	_game.select(hover_tile)


func _right_click() -> void:
	if _fusing:
		_fusing = false
	elif _game.build_choice != &"":
		_game.choose_build(&"")
	elif _game.selected != Game.NONE and hover_tile == _game.selected:
		_game.sell_selected()
	else:
		_game.select(Game.NONE)


func _update_hover(screen_pos: Vector2) -> void:
	var hit: Variant = _game.camera.screen_to_ground(screen_pos)
	var tile := Game.NONE if hit == null else Coords.world_to_tile(hit)
	if tile != hover_tile:
		hover_tile = tile
		_recheck = 0.0


func _process(delta: float) -> void:
	Prof.begin(&"builder")
	_refusal_shake = maxf(_refusal_shake - delta, 0.0)
	var building := _game.build_choice != &"" and Grid.in_bounds(hover_tile)
	_ghost.visible = building
	if building:
		_recheck -= delta
		if _recheck <= 0.0:
			_recheck = 0.1
			hover_result = _game.sim.check_build(hover_tile, _game.build_choice)
		var ok := hover_result == Placement.Result.OK
		_ghost_mat.albedo_color = GHOST_OK if ok else GHOST_BAD
		var wobble := sin(_refusal_shake * 60.0) * _refusal_shake * 0.6
		_ghost.position = Coords.tile_to_world(hover_tile, Coords.PLATEAU_TOP + GHOST_LIFT)
		_ghost.position.x += wobble
	_update_ring(building)
	_update_partner_rings()

## While fusing, a pulsing gold ring marks every valid level-3 partner.
	Prof.end(&"builder")


func _update_partner_rings() -> void:
	var partners: Array[Vector2i] = []
	if _fusing:
		partners = TowerInfo.fuse_partners(_game.sim, _game.selected)
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
	for i in _partner_rings.size():
		var r := _partner_rings[i]
		r.visible = i < partners.size()
		if r.visible:
			r.position = Coords.tile_to_world(partners[i], Coords.PLATEAU_TOP + 0.15)
			r.scale = Vector3.ONE * pulse


func _update_ring(building: bool) -> void:
	var tile := Game.NONE
	var id: StringName = &""
	var level := 1
	if building:
		tile = hover_tile
		id = _game.build_choice
	else:
		var t := _game.sim.tower_at(hover_tile)
		if t == null:
			t = _game.sim.tower_at(_game.selected)
		if t != null:
			tile = t.tile
			id = t.id
			level = t.level
	var r: float = TowerDefs.stat(id, "range", level, 0.0) if id != &"" else 0.0
	var square: bool = r > 0.0 and _game.sim.adjacent_reach() and TowerDefs.TOWERS[id].has("attack")
	_reach_square.visible = square
	if square:
		_reach_square.position = Coords.tile_to_world(tile, Coords.PLATEAU_TOP + 0.1)
		r = 0.0
	_ring.visible = r > 0.0
	if r > 0.0:
		_ring_mesh.inner_radius = r - 0.08
		_ring_mesh.outer_radius = r + 0.08
		_ring.position = Coords.tile_to_world(tile, Coords.PLATEAU_TOP + 0.1)
