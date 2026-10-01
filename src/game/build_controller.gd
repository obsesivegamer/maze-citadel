class_name BuildController
extends Node3D
## Mouse and hotkey input for building and selecting (GDD §10). Shows the
## snapped ghost (green = valid, red = refused) and the range ring for the
## ghost, the hovered tower or the selected tower only.

const GHOST_OK := Color(0.3, 1.0, 0.45, 0.45)
const GHOST_BAD := Color(1.0, 0.2, 0.15, 0.5)
const RING_COLOR := Color(1.0, 0.95, 0.6, 0.85)

var hover_tile := Game.NONE
var hover_result := Placement.Result.OUT_OF_BOUNDS

var _game: Game
var _ghost := MeshInstance3D.new()
var _ghost_mat := StandardMaterial3D.new()
var _ring := MeshInstance3D.new()
var _ring_mesh := TorusMesh.new()
## While fusing: the selected tower waits for a second click on its partner.
var _fusing := false
var _refusal_shake := 0.0
## Seconds until the ghost's validity is re-checked (creeps move under it).
var _recheck := 0.0


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
	game.build_choice_changed.connect(func(_id: StringName) -> void: _fusing = false)
	game.sim_event.connect(_on_sim_event)


func is_fusing() -> bool:
	return _fusing


## Arms fusion: the next click on a matching level-3 tower fuses the pair.
func start_fuse() -> void:
	_fusing = _game.selected != Game.NONE


func _on_sim_event(e: Dictionary) -> void:
	if e.type == &"path_changed" or e.type == &"build_refused":
		_recheck = 0.0


func _unhandled_input(event: InputEvent) -> void:
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
		_ghost.position = Coords.tile_to_world(hover_tile, Coords.PLATEAU_TOP + 1.2)
		_ghost.position.x += wobble
	_update_ring(building)


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
	_ring.visible = r > 0.0
	if r > 0.0:
		_ring_mesh.inner_radius = r - 0.08
		_ring_mesh.outer_radius = r + 0.08
		_ring.position = Coords.tile_to_world(tile, Coords.PLATEAU_TOP + 0.1)
