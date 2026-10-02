extends Node3D
## Entry point: opens straight into the citadel (GDD §1).
##
## User args (after `--`):
##   --scene=spike                              M1 render spike instead of the game
##   --quality=cinematic|balanced|performance   presentation preset
##   --<setting>=<value>                        override one preset setting
##   --autoplay [--strategy=smart] [--speed=3]  the balance bot plays
##   --twists [--seed=<n>]                      Twists mode, optionally a fixed schedule
##   --warp-wave=<n> [--warp-into=<s>]          fast-forward to wave n (+ s seconds)
##   --shot=<path prefix> --views=a,b,c          save one PNG per view, quit
##   --bench=<seconds> --bench-out=<json>        measure frame pacing, quit

const RenderSpike := preload("res://src/spike/render_spike.gd")


func _ready() -> void:
	if Cli.get_str("scene") == "spike":
		_boot_spike()
		return
	var game := Game.new()
	add_child(game)
	if Cli.has("quality"):
		var preset := Quality.from_name(Cli.get_str("quality"))
		game.quality_overrides = _overrides(preset)
		game.set_quality(preset)
	if Cli.has("autoplay"):
		game.autoplay = AutoplayBot.new(game.sim, StringName(Cli.get_str("strategy", "smart")))
		game.choose_build(&"")
	if Cli.has("twists"):
		game.sim.twist_seed = int(Cli.get_str("seed", "0"))
		game.set_mode(game.sim.hard, game.sim.infinite, true)
	if Cli.has("speed"):
		game.speed = int(Cli.get_str("speed"))
	if Cli.has("warp-wave"):
		game.warp_to_wave(int(Cli.get_str("warp-wave")), Cli.get_float("warp-into", 0.0))
	_attach_tools(
		func(view: String) -> void: game.camera.preset(StringName(view), true),
		game.quality_settings
	)


func _boot_spike() -> void:
	var world := RenderSpike.new()
	add_child(world)
	var preset := Quality.from_name(Cli.get_str("quality", "balanced"))
	var settings := Quality.apply(preset, get_viewport(), world.env, world.sun, _overrides(preset))
	_attach_tools(world.set_view, settings)


func _attach_tools(set_view: Callable, settings: Dictionary) -> void:
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
		bench.settings = settings
		add_child(bench)


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
