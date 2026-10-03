extends Node3D
## Entry point: opens straight into the citadel (GDD §1).
##
## User args (after `--`):
##   --scene=spike                              M1 render spike instead of the game
##   --map=citadel|rampart                       board (default: the last pick)
##   --quality=cinematic|balanced|performance   presentation preset
##   --<setting>=<value>                        override one preset setting
##   --autoplay [--strategy=smart] [--speed=3]  the balance bot plays
##   --twists [--seed=<n>]                      Twists mode, optionally a fixed schedule
##   --warp-wave=<n> [--warp-into=<s>]          fast-forward to wave n (+ s seconds)
##   --shot=<path prefix> --views=a,b,c          save one PNG per view, quit
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
		game.sim.twist_seed = int(Cli.get_str("seed", "0"))
		game.set_mode(game.sim.hard, game.sim.infinite, true)
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
	_attach_tools(
		func(view: String) -> void: game.camera.preset(StringName(view), true),
		game.quality_settings,
		func() -> Dictionary: return _context(game)
	)


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
