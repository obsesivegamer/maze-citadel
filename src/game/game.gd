class_name Game
extends Node3D
## Runs one match: owns the GameSim, steps it at a fixed rate scaled by game
## speed, and broadcasts sim events. Subsystems (world, camera, units, fx,
## build input, HUD, audio) live in their own folders, receive `self` in
## setup(), and talk back only through the public API below.

signal sim_event(e: Dictionary)
signal build_choice_changed(id: StringName)
signal selection_changed(tile: Vector2i)
signal speed_changed(speed: int)
signal pause_changed(paused: bool)
signal quality_changed(preset: Quality.Preset)

const NONE := Vector2i(-1, -1)
const MAX_STEPS_PER_FRAME := 12

var sim := GameSim.new()
var speed := 1
var paused := false
var quality := Quality.Preset.BALANCED
## Tower the builder is placing, or &"" when not building.
var build_choice: StringName = &"archer"
var selected := NONE
## Optional object with step() that plays instead of the player (--autoplay).
var autoplay: Object

var world: World
var camera: CameraRig
var path_preview: PathPreview
var units: Units
var fx: Fx
var builder: BuildController
var hud: Hud
var audio: AudioDirector

var _acc := 0.0


func _ready() -> void:
	InputSetup.register()
	world = _add(World.new())
	camera = _add(CameraRig.new())
	path_preview = _add(PathPreview.new())
	units = _add(Units.new())
	fx = _add(Fx.new())
	builder = _add(BuildController.new())
	hud = _add(Hud.new())
	audio = _add(AudioDirector.new())
	for s in [world, camera, path_preview, units, fx, builder, hud, audio]:
		s.setup(self)
	set_quality(Quality.from_name(Save.setting("quality", "balanced")))
	_flush()


func _add(node: Node) -> Node:
	add_child(node)
	return node


func _process(delta: float) -> void:
	if not paused and not is_over():
		_acc += delta * speed
		var steps := 0
		while _acc >= GameSim.DT and steps < MAX_STEPS_PER_FRAME:
			if autoplay != null:
				autoplay.step()
			else:
				sim.step()
			_acc -= GameSim.DT
			steps += 1
			_flush()
		if steps == MAX_STEPS_PER_FRAME:
			_acc = 0.0
	units.sync(clampf(_acc / GameSim.DT, 0.0, 1.0))


func _flush() -> void:
	for e in sim.drain_events():
		if e.type == &"defeat" or e.type == &"victory":
			Save.record(Save.sim_key(sim), sim.wave, sim.score())
		sim_event.emit(e)


## Plays instantly (no rendering) until `wave` has started plus `into`
## seconds, so captures and benchmarks can start mid-battle. Capped at an hour
## of game time in case the player (or bot) can't get that far.
func warp_to_wave(wave: int, into := 0.0) -> void:
	var limit := 3600.0
	var extra := -1.0
	while not is_over() and sim.time < limit:
		if autoplay != null:
			autoplay.step()
		else:
			sim.step()
		_flush()
		if extra < 0.0 and sim.wave >= wave:
			extra = sim.time + into
		if extra >= 0.0 and sim.time >= extra:
			break


func is_over() -> bool:
	return sim.phase == GameSim.Phase.DEFEAT or sim.phase == GameSim.Phase.VICTORY


## Interpolation factor between the last two sim steps, for smooth motion.
func alpha() -> float:
	return clampf(_acc / GameSim.DT, 0.0, 1.0)


# --- Player actions ---------------------------------------------------------


func choose_build(id: StringName) -> void:
	build_choice = id
	if id != &"":
		select(NONE)
	build_choice_changed.emit(id)


func build_at(tile: Vector2i) -> Placement.Result:
	var r := sim.build(tile, build_choice)
	_flush()
	return r


func select(tile: Vector2i) -> void:
	selected = tile if sim.tower_at(tile) != null else NONE
	if selected != NONE and build_choice != &"":
		build_choice = &""
		build_choice_changed.emit(build_choice)
	selection_changed.emit(selected)


func sell_selected() -> void:
	if selected == NONE:
		return
	sim.sell(selected)
	select(NONE)
	_flush()


func upgrade_selected() -> bool:
	var ok := selected != NONE and sim.upgrade(selected)
	_flush()
	selection_changed.emit(selected)
	return ok


func fuse_selected_with(other: Vector2i) -> bool:
	var ok := selected != NONE and sim.fuse(selected, other)
	_flush()
	selection_changed.emit(selected)
	return ok


func call_next_wave() -> void:
	sim.start_next_wave()
	_flush()


func cycle_speed() -> void:
	speed = speed % 3 + 1
	speed_changed.emit(speed)


func toggle_pause() -> void:
	paused = not paused
	pause_changed.emit(paused)


func set_quality(preset: Quality.Preset) -> void:
	quality = preset
	Quality.apply(preset, get_viewport(), world.env, world.sun)
	Save.set_setting("quality", Quality.NAMES[preset])
	quality_changed.emit(preset)


## Mode can change only before wave 1 spawns (GDD §5). Turning Twists on
## deals a fresh schedule unless a seed was already given (--seed).
func set_mode(hard: bool, infinite: bool, twists := false) -> bool:
	if sim.wave > 0:
		return false
	sim.hard = hard
	sim.infinite = infinite
	if twists and not sim.twists and sim.twist_seed == 0:
		sim.twist_seed = randi() | 1
	sim.twists = twists
	return true


func restart() -> void:
	get_tree().reload_current_scene()
