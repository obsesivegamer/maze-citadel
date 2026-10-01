extends Node3D
## Entry point. Until the citadel exists (M3) this boots the M1 render spike.
##
## User args (after `--`):
##   --quality=cinematic|balanced|performance   presentation preset
##   --<setting>=<value>                        override one preset setting, e.g.
##                                              --ssil=false --render_scale=0.6 --upscaler=fsr2
##   --shot=<path prefix> --views=a,b,c          save one PNG per view, quit
##   --bench=<seconds> --bench-out=<json>        measure frame pacing, quit

const RenderSpike := preload("res://src/spike/render_spike.gd")


func _ready() -> void:
	var world := RenderSpike.new()
	add_child(world)
	var preset := Quality.from_name(Cli.get_str("quality", "balanced"))
	Quality.apply(preset, get_viewport(), world.env, world.sun, _quality_overrides(preset))

	if Cli.has("shot"):
		var shot := Shot.new()
		shot.prefix = Cli.get_str("shot")
		shot.views = Cli.get_str("views", "overview").split(",")
		shot.set_view = world.set_view
		add_child(shot)
	elif Cli.has("bench"):
		world.set_view(Cli.get_str("view", "overview"))
		var bench := Bench.new()
		bench.duration = Cli.get_float("bench", 20.0)
		bench.out_path = Cli.get_str("bench-out")
		bench.label = "%s %s" % [Quality.NAMES[preset], Cli.get_str("upscaler", "")]
		add_child(bench)


## Any preset key given on the command line overrides that key, cast to the
## preset's own type. Used by the benchmark to price each effect separately.
func _quality_overrides(preset: Quality.Preset) -> Dictionary:
	var out := {}
	var defaults := Quality.settings(preset)
	for key in defaults:
		if Cli.has(key):
			out[key] = type_convert(Cli.get_str(key), typeof(defaults[key]))
			if defaults[key] is bool:
				out[key] = Cli.get_str(key) in ["true", "1", "on"]
	return out
