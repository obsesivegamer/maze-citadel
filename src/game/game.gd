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

## The rule set a player gets unless they pick another (GameSim.RULES). A bare
## GameSim keeps classic, so tests and tools that build one are unchanged.
const DEFAULT_RULES: StringName = &"eletd"

## The mode a player gets unless they pick another, and the settings keys
## set_mode saves it under for the next launch.
const DEFAULT_MODE := {"difficulty": "normal", "infinite": false, "twists": false}

## Map, rules and mode carried across the scene reload that switches map or
## rules, or plays again.
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
## This match's record (docs/playtests.md); null until boot, and for the
## warm-up stage, which never boots.
var play_log: PlayLog

var world: World
var camera: CameraRig
var path_preview: PathPreview
var units: Units
var fx: Fx
var builder: BuildController
var hud: Hud
var audio: AudioDirector

var _acc := 0.0
var _cli_picks: Array[String] = []
var _loading: LoadingScreen


## The map comes from a map switch in progress, else --map, else the last
## pick; the rules the same way (choose_rules), and the mode too
## (choose_mode). A map the rules don't offer (MapDefs.offered) gives way to
## the default one, and a difficulty they don't offer to Normal. Twists
## without a seed deal a fresh schedule.
func _init() -> void:
	var rules := choose_rules(_carry.get("rules"), Cli.get_str("rules"), Save.setting("rules", ""))
	var map := StringName(_carry.get("map", Cli.get_str("map", Save.setting("map", ""))))
	if MapDefs.has(map) and not MapDefs.offered(map, rules) and Cli.get_str("map") == map:
		push_warning("--map=%s is not offered under %s rules; playing the default" % [map, rules])
	if not MapDefs.has(map) or not MapDefs.offered(map, rules):
		map = MapDefs.DEFAULT
	sim = GameSim.new(map)
	var saved := {}
	for key: String in DEFAULT_MODE:
		saved[key] = Save.setting(key, DEFAULT_MODE[key])
	var scripted := DisplayServer.get_name() == "headless"
	for flag in Tutorial.SCRIPTED_FLAGS:
		scripted = scripted or Cli.has(flag)
	var mode := choose_mode(_carry, Cli.args(), saved, scripted)
	sim.infinite = mode.infinite
	sim.twists = mode.twists
	sim.twist_seed = mode.twist_seed
	if sim.twists and sim.twist_seed == 0:
		sim.twist_seed = randi() | 1
	sim.rules = rules
	var level: StringName = mode.difficulty
	sim.difficulty = offered_difficulty(level, sim.rules)
	var flagged := Cli.get_str("difficulty") == level and not _carry.has("difficulty")
	if sim.difficulty != level and flagged:
		push_warning(
			"--difficulty=%s is not offered under %s rules; playing normal" % [level, sim.rules]
		)
	_apply_cli_picks()
	_carry = {}


## A rules switch in progress, else --rules=, else the player's last choice,
## else DEFAULT_RULES. A value that names no rule set is passed over.
static func choose_rules(carried: Variant, flag: String, saved: String) -> StringName:
	for r: Variant in [carried, flag, saved]:
		if r != null and StringName(r) in GameSim.RULES:
			return StringName(r)
	return DEFAULT_RULES


## Difficulty, Infinite, Twists and the Twists seed for the next match. A
## carry (a map or rules switch, Play again, a tool setting a match up) gives
## all of it, else the player's last choice (`saved`, which set_mode keeps);
## --difficulty beats all but a carried difficulty. A `scripted` run
## (headless, or a flag in Tutorial.SCRIPTED_FLAGS) passes the saved mode
## over, so bots, benchmarks and captures play what their flags say.
static func choose_mode(
	carry: Dictionary, args: Dictionary, saved: Dictionary, scripted := false
) -> Dictionary:
	var mode := DEFAULT_MODE.duplicate()
	mode["twist_seed"] = 0
	if carry.is_empty() and not scripted:
		for key: String in DEFAULT_MODE:
			mode[key] = saved.get(key, mode[key])
	if args.has("difficulty"):
		mode.difficulty = args.difficulty
	for key: String in mode:
		mode[key] = carry.get(key, mode[key])
	mode.difficulty = StringName(mode.difficulty)
	return mode


## `level` if rule set `rules` offers it, else Normal: Easy and Very Hard
## carried into classic, which has neither, fall back to it.
static func offered_difficulty(level: StringName, rules: StringName) -> StringName:
	return level if level in EletdRules.difficulties(rules) else &"normal"


## --picks=aqua,dark,interest: element levels and Interest set up at the
## start, with no Guardians (SimElements.apply_picks).
func _apply_cli_picks() -> void:
	if not Cli.has("picks"):
		return
	var picks := SimElements.parse_picks(Cli.get_str("picks"))
	var bad := picks.filter(func(p: StringName) -> bool: return not SimElements.is_choice(p))
	if sim.rules != &"eletd" or not bad.is_empty():
		push_warning("--picks needs --rules=eletd and elements or interest; ignored")
		return
	sim.elements.apply_picks(picks)
	_cli_picks.assign(picks.map(func(p: StringName) -> String: return String(p)))


## The presentation's statics follow this match. They are set here, not in
## _init, because the warm-up stage is a Game too: it is built after a map or
## rules switch has spent its carry, and must not overwrite them.
func _ready() -> void:
	TowerInfo.adjacent_reach = sim.adjacent_reach()
	TowerInfo.composite = sim.elements.enabled
	Coords.map = sim.grid.map
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
	var screen := LoadingScreen.new(sim.rules)
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
	play_log = PlayLog.new()
	play_log.picks = _cli_picks
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
	var events := sim.drain_events()
	var keep := false
	if _recording():
		play_log.observe(sim, events)
	for e in events:
		if e.type == &"defeat" or e.type == &"victory":
			Save.record(Save.sim_key(sim), sim.wave, sim.score())
		keep = keep or e.type in PlayLog.SAVE_ON
		sim_event.emit(e)
	if keep:
		save_play_log()


## A bot's game is not recorded: it acts on the sim directly, and the balance
## tool already measures it.
func _recording() -> bool:
	return play_log != null and autoplay == null


## Writes the match's record so far, unless the player turned the files off
## (Settings); returns the file's path, or "".
func save_play_log() -> String:
	if not _recording() or not Save.setting(PlayLog.SETTING, true):
		return ""
	return play_log.save(sim)


## A game left early (quit, Play again, a map or rules switch) keeps its
## record up to that moment.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_play_log()


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


## A tower whose element isn't picked yet (eletd) can't be chosen: the same
## build_refused the sim sends for a refused tile, so the thunk plays and the
## HUD says why.
func choose_build(id: StringName) -> void:
	if id != &"" and sim.elements.needs(id) != "":
		var reason := Placement.Result.LOCKED
		sim_event.emit({"type": &"build_refused", "tile": NONE, "reason": reason, "id": id})
		return
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


## Spends a pending element pick (eletd) on an element level or Interest.
func pick_element(choice: StringName) -> bool:
	var ok := sim.elements.pick(sim, choice)
	_flush()
	return ok


func call_next_wave() -> void:
	var before := sim.wave
	sim.start_next_wave()
	if sim.wave > before and _recording():
		play_log.called_wave(sim)
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
## deals a fresh schedule unless a seed was already given (--seed). The mode
## is remembered for the next launch unless `remember` is false (--twists).
func set_mode(difficulty: StringName, infinite: bool, twists := false, remember := true) -> bool:
	if sim.wave > 0 or not difficulty in EletdRules.difficulties(sim.rules):
		return false
	sim.difficulty = difficulty
	sim.infinite = infinite
	if twists and not sim.twists and sim.twist_seed == 0:
		sim.twist_seed = randi() | 1
	sim.twists = twists
	if remember:
		Save.set_setting("difficulty", String(difficulty))
		Save.set_setting("infinite", infinite)
		Save.set_setting("twists", twists)
	return true


## Map can change only before wave 1 spawns, like the mode. The board is
## rebuilt from scratch (towers placed so far are cleared); the mode carries
## over and the pick is remembered for the next launch. A map the current
## rules don't offer is refused.
func change_map(id: StringName) -> bool:
	if sim.wave > 0 or id == sim.grid.map or not MapDefs.has(id):
		return false
	if not MapDefs.offered(id, sim.rules):
		return false
	Save.set_setting("map", String(id))
	_carry = _carry_with({"map": id})
	restart()
	return true


## Rules change the way the map does: only before wave 1, by rebuilding the
## board, and remembered for the next launch. The modes carry over, and so do
## the map and the difficulty where the new rules offer them (else the
## default map and Normal). A map given way is forgotten too, so Play again
## and the next launch stay on the map the board shows.
func change_rules(rules: StringName) -> bool:
	if sim.wave > 0 or rules == sim.rules or not rules in GameSim.RULES:
		return false
	Save.set_setting("rules", String(rules))
	if not MapDefs.offered(sim.grid.map, rules):
		Save.set_setting("map", String(MapDefs.DEFAULT))
	_carry = _carry_with({"rules": rules})
	restart()
	return true


## A new match on the same map, under the same rules and mode (the end
## screen's Play again). Twists deal a fresh schedule, as on a new launch.
func play_again() -> void:
	_carry = _carry_with({"twist_seed": 0})
	restart()


## A new match from the board setup (the pause menu's New game setup and the
## end screen's Change setup). Until the setup screen exists it plays again.
func change_setup() -> void:
	play_again()


## Quit to desktop (the pause menu and the end screen), keeping the record.
func quit() -> void:
	save_play_log()
	_quit_tree()


func _quit_tree() -> void:
	get_tree().quit()


## This match's map, rules and mode with `changes`, for the next _init.
func _carry_with(changes: Dictionary) -> Dictionary:
	var carry := {
		"map": sim.grid.map,
		"difficulty": sim.difficulty,
		"infinite": sim.infinite,
		"twists": sim.twists,
		"twist_seed": sim.twist_seed,
		"rules": sim.rules,
	}
	carry.merge(changes, true)
	return carry


func restart() -> void:
	get_tree().reload_current_scene()
