extends Node3D
## Entry point: opens straight into the citadel (GDD §1).
##
## User args (after `--`):
##   --scene=spike                              M1 render spike instead of the game
##   --map=citadel|rampart|causeway              board (default: the last pick;
##                                              causeway needs eletd rules)
##   --quality=cinematic|balanced|performance   presentation preset
##   --<setting>=<value>                        override one preset setting
##   --autoplay [--strategy=smart] [--speed=3]  the balance bot plays
##   --twists [--seed=<n>]                      Twists mode, optionally a fixed schedule
##   --rules=eletd|classic                      rule set (default: the last pick, else eletd)
##   --difficulty=easy|normal|hard|very_hard    difficulty; classic offers normal and hard
##   --picks=aqua,dark,dark,interest            eletd: element levels set at the start, no Guardians
##   --tutorial / --no-tutorial                 force the first-run tutorial on / off
##   --warp-wave=<n> [--warp-into=<s>]          fast-forward to wave n (+ s seconds)
##   --select=<x,y|tower id>                    select a tower (the first of that kind)
##   --open=pick|guide|elements|settings        open the pick panel (eletd), the Field Guide,
##                                              its Elements and picks page (eletd) or Settings
##   --shot=<path prefix> --views=a,b,c          save one PNG per view, quit
##     [--shot-frames=<n>] [--shot-freeze]       n consecutive frames per view, game time stopped
##   --bench=<seconds> --bench-out=<json>        measure frame pacing, quit
##   --pacing                                    bench with vsync on; count missed frames
##   --bench-any-focus                           bench without keyboard focus (always-on-top window)
##   --first-frame-out=<json>                    launch time and wave-1 hitches, quit
##   --sync-boot / --async-boot                  force one-frame setup / the loading screen

const RenderSpike := preload("res://src/spike/render_spike.gd")


func _ready() -> void:
	if Cli.get_str("scene") == "spike":
		_boot_spike()
		return
	var game := Game.new()
	var windowed := DisplayServer.get_name() != "headless"
	game.async_boot = (windowed or Cli.has("async-boot")) and not Cli.has("sync-boot")
	if Cli.has("first-frame-out"):
		var probe := FirstFrame.new()
		probe.out_path = Cli.get_str("first-frame-out")
		probe.game = game
		add_child(probe)
	if Cli.has("quality"):
		var preset := Quality.from_name(Cli.get_str("quality"))
		game.quality_overrides = _overrides(preset)
		game.boot_quality = preset
	add_child(game)
	if not game.is_booted:
		await game.booted
	if Cli.has("autoplay"):
		game.autoplay = AutoplayBot.new(game.sim, StringName(Cli.get_str("strategy", "smart")))
		game.choose_build(&"")
	if Cli.has("twists"):
		if Cli.has("seed"):
			game.sim.twist_seed = int(Cli.get_str("seed"))
		game.set_mode(game.sim.difficulty, game.sim.infinite, true, false)
	if Cli.has("speed"):
		game.speed = int(Cli.get_str("speed"))
	# Diagnostic: hide whole subsystems to price them (--pf-hide=world,hud,...).
	# world/<part> hides one world builder, e.g. world/_nature.
	for part in PerfFlags.get_str("hide", "").split(",", false):
		var path := part.split("/")
		var node: Variant = game.get(path[0])
		if path.size() > 1 and node != null:
			node = node.get(path[1])
		if node is Node3D or node is CanvasLayer:
			node.visible = false
	if Cli.has("warp-wave"):
		game.warp_to_wave(int(Cli.get_str("warp-wave")), Cli.get_float("warp-into", 0.0))
	if Cli.has("select"):
		game.select(_tile_to_select(game, Cli.get_str("select")))
	if Cli.has("open"):
		game.hud.open_panel(Cli.get_str("open"))
	_attach_tools(
		func(view: String) -> void: game.camera.preset(StringName(view), true),
		game.quality_settings,
		func() -> Dictionary: return _context(game)
	)


## Windows and Linux windows have no fullscreen button like macOS's title
## bar: F11 or Alt+Enter toggles fullscreen there.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if OS.has_feature("macos") or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_MAXIMIZED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		get_viewport().set_input_as_handled()


func _boot_spike() -> void:
	var world := RenderSpike.new()
	add_child(world)
	var preset := Quality.from_name(Cli.get_str("quality", "balanced"))
	var settings := Quality.apply(preset, get_viewport(), world.env, world.sun, _overrides(preset))
	_attach_tools(world.set_view, settings)


func _attach_tools(set_view: Callable, settings: Dictionary, context := Callable()) -> void:
	if Cli.has("shot"):
		var shot := Shot.new()
		shot.prefix = Cli.get_str("shot")
		shot.views = Cli.get_str("views", "full").split(",")
		shot.settle_frames = int(Cli.get_str("settle", "90"))
		shot.frames = int(Cli.get_str("shot-frames", "1"))
		shot.freeze = Cli.has("shot-freeze")
		shot.set_view = set_view
		add_child(shot)
	elif Cli.has("bench"):
		var bench := Bench.new()
		bench.duration = Cli.get_float("bench", 20.0)
		bench.out_path = Cli.get_str("bench-out")
		bench.label = Cli.get_str("quality", "balanced")
		bench.pacing = Cli.has("pacing")
		bench.any_focus = Cli.has("bench-any-focus")
		bench.context = context
		bench.settings = settings
		add_child(bench)


## --select=x,y is that tile; --select=<tower id> the first tower of that kind.
static func _tile_to_select(game: Game, what: String) -> Vector2i:
	var xy := what.split(",")
	if xy.size() == 2:
		return Vector2i(int(xy[0]), int(xy[1]))
	for t: SimTower in game.sim.towers.values():
		if t.id == StringName(what):
			return t.tile
	return Game.NONE


static func _context(game: Game) -> Dictionary:
	return {
		"wave": game.sim.wave,
		"sim_t": snappedf(game.sim.time, 0.01),
		"phase": game.sim.phase,
		"creeps": game.sim.creeps.size(),
		"towers": game.sim.towers.size(),
	}


## Any preset key given on the command line overrides that key, cast to the
## preset's own type. Used by the benchmark to price each effect separately.
func _overrides(preset: Quality.Preset) -> Dictionary:
	var out := {}
	var defaults := Quality.settings(preset)
	for key in defaults:
		if Cli.has(key):
			out[key] = type_convert(Cli.get_str(key), typeof(defaults[key]))
			if defaults[key] is bool:
				out[key] = Cli.get_str(key) in ["true", "1", "on"]
	return out
