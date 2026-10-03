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
## Setup is complete and the match can start (immediately for a sync boot).
signal booted

const NONE := Vector2i(-1, -1)
const MAX_STEPS_PER_FRAME := 12
## Share of the loading bar given to the battle rehearsal.
const REHEARSAL_SHARE := 0.35
## Creep views per type built during loading (the rest build as they spawn).
const PREWARM_PER_TYPE := 2

## Map and mode carried across the scene reload that switches map.
static var _carry := {}

var sim: GameSim
var speed := 1
var paused := false
var quality := Quality.Preset.BALANCED
## The preset's values with quality_overrides applied. World, units and FX
## read their density budgets from here, not from the bare preset.
var quality_settings := {}
## Per-setting overrides layered on every preset (the benchmark's
## --<setting>=<value> flags, which price one effect at a time).
var quality_overrides := {}
## Preset to boot with instead of the saved one (benchmarks, --quality), so
## the loading-screen warm-up compiles exactly the shaders that will be used.
var boot_quality: Variant = null
## Tower the builder is placing, or &"" when not building.
var build_choice: StringName = &"archer"
var selected := NONE
## Optional object with step() that plays instead of the player (--autoplay).
var autoplay: Object
## Build over many frames behind a loading screen and rehearse a battle so
## every shader compiles before play. main.gd turns it on for the real game;
## headless tools keep the one-frame setup.
var async_boot := false
var is_booted := false

var world: World
var camera: CameraRig
var path_preview: PathPreview
var units: Units
var fx: Fx
var builder: BuildController
var hud: Hud
var audio: AudioDirector

var _acc := 0.0
var _loading: LoadingScreen


## The map comes from a map switch in progress, else --map, else the last pick.
func _init() -> void:
	var map := StringName(_carry.get("map", Cli.get_str("map", Save.setting("map", ""))))
	if not MapDefs.has(map):
		map = MapDefs.DEFAULT
	sim = GameSim.new(map)
	sim.hard = _carry.get("hard", false)
	sim.infinite = _carry.get("infinite", false)
	sim.twists = _carry.get("twists", false)
	sim.twist_seed = _carry.get("twist_seed", 0)
	_carry = {}
	Coords.map = map


func _ready() -> void:
	InputSetup.register()
	if async_boot:
		_boot_async()
		return
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
	_apply_saved_quality()
	_finish_boot()


## One step per frame so the window keeps answering (no spinning cursor) and
## each frame compiles only the shaders of what was just added; then a hidden
## rehearsal compiles the combat shaders. The camera comes first because
## nothing 3D is drawn, or compiled, without one.
func _boot_async() -> void:
	var screen := LoadingScreen.new()
	add_child(screen)
	await _frames(2)
	camera = _add(CameraRig.new())
	camera.setup(self)
	world = _add(World.new())
	var steps := world.setup_steps(self)
	# Audio before the HUD: its settings panel reads the saved volumes.
	var late: Array = [
		["Marking the path", _boot_part.bind(&"path_preview", PathPreview)],
		["Mustering the units", _boot_part.bind(&"units", Units)],
		["Assembling the horde", _prewarm_units],
		["Readying the effects", _boot_part.bind(&"fx", Fx)],
		["Arming the builder", _boot_part.bind(&"builder", BuildController)],
		["Tuning the war drums", _boot_part.bind(&"audio", AudioDirector)],
		["Raising the banners", _boot_part.bind(&"hud", Hud)],
		["Lighting the scene", _apply_saved_quality],
	]
	steps.append_array(late)
	for i in steps.size():
		screen.set_progress((1.0 - REHEARSAL_SHARE) * i / steps.size(), steps[i][0])
		await _frames(1)
		steps[i][1].call()
		await _frames(1)
	var stage := WarmupStage.new()
	add_child(stage)
	_loading = screen
	await stage.run(self, _on_rehearsal_progress)
	screen.finish()
	_finish_boot()


## Creates, adds and sets up one subsystem, storing it in the named member.
func _boot_part(member: StringName, kind: GDScript) -> void:
	var node: Node = kind.new()
	add_child(node)
	set(member, node)
	node.setup(self)


func _prewarm_units() -> void:
	units.prewarm(PREWARM_PER_TYPE)


func _apply_saved_quality() -> void:
	if boot_quality != null:
		set_quality(boot_quality, false)
	else:
		set_quality(Quality.from_name(Save.setting("quality", "balanced")))


func _on_rehearsal_progress(f: float) -> void:
	_loading.set_progress(1.0 - REHEARSAL_SHARE + REHEARSAL_SHARE * f, "Rehearsing the battle")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _finish_boot() -> void:
	_flush()
	is_booted = true
	booted.emit()


func _add(node: Node) -> Node:
	add_child(node)
	return node


func _process(delta: float) -> void:
	if not is_booted:
		return
	Prof.begin(&"sim")
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
	Prof.end(&"sim")
	Prof.begin(&"units")
	units.sync(clampf(_acc / GameSim.DT, 0.0, 1.0))
	Prof.end(&"units")


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


## `remember` saves the choice as the player's setting; benchmark and
## command-line presets pass false so they don't overwrite it.
func set_quality(preset: Quality.Preset, remember := true) -> void:
	quality = preset
	quality_settings = Quality.apply(
		preset, get_viewport(), world.env, world.sun, quality_overrides
	)
	if remember:
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


## Map can change only before wave 1 spawns, like the mode. The board is
## rebuilt from scratch (towers placed so far are cleared); the mode carries
## over and the pick is remembered for the next launch.
func change_map(id: StringName) -> bool:
	if sim.wave > 0 or id == sim.grid.map or not MapDefs.has(id):
		return false
	Save.set_setting("map", String(id))
	_carry = {
		"map": id,
		"hard": sim.hard,
		"infinite": sim.infinite,
		"twists": sim.twists,
		"twist_seed": sim.twist_seed,
	}
	restart()
	return true


func restart() -> void:
	get_tree().reload_current_scene()
