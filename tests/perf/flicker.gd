extends SceneTree
## Flicker metric for consecutive frames of one camera view, captured with
## `--shot=<prefix> --views=full --shot-frames=40 [--shot-freeze]` (see
## src/main.gd). For each region it reports, per 10,000 pixels:
##   change  pixels whose colour moves more than --threshold (0-255, any
##           channel) from one frame to the next
##   pop     pixels that differ from the mean of the frames before and after
##           by more than the threshold: on/off flashing, not smooth motion
## The default regions fit the "full" view: lowland foliage beyond the walls
## on both sides (river and HUD left out) and, as a control, the open board.
## With --shot-freeze nothing in the scene moves, so any change is the
## renderer's (temporal upscaler jitter, dithering).
##   godot --headless --path . --script res://tests/perf/flicker.gd -- \
##     --frames=<prefix>-full [--threshold=24] [--heat=<png>]

const REGIONS := {
	"lowland_w": Rect2(0.00, 0.15, 0.12, 0.71),
	"lowland_e": Rect2(0.84, 0.10, 0.16, 0.76),
	"board": Rect2(0.38, 0.25, 0.09, 0.45),
}


func _initialize() -> void:
	var prefix := Cli.get_str("frames")
	var threshold := int(Cli.get_str("threshold", "24"))
	var paths := _frames(prefix)
	if paths.size() < 3:
		push_error("flicker: need 3+ frames named %s-NNN.png" % prefix)
		quit(1)
		return
	var size := Image.load_from_file(paths[0]).get_size()
	var rects := {}
	for name: String in REGIONS:
		var r: Rect2 = REGIONS[name]
		rects[name] = Rect2i(Vector2i(r.position * Vector2(size)), Vector2i(r.size * Vector2(size)))
	var change := {}
	var pop := {}
	for name: String in rects:
		change[name] = 0
		pop[name] = 0
	var heat := PackedInt32Array()
	heat.resize(size.x * size.y)
	var frames: Array[PackedByteArray] = []
	for i in paths.size():
		frames.append(_rgb(paths[i]))
		if frames.size() > 3:
			frames.pop_front()
		var n := frames.size()
		for name: String in rects:
			var rect: Rect2i = rects[name]
			if n >= 2:
				change[name] += _count(frames[n - 2], frames[n - 1], rect, size.x, threshold, heat)
			if n == 3:
				pop[name] += _count_pop(frames[0], frames[1], frames[2], rect, size.x, threshold)
	var pairs := paths.size() - 1
	var triples := paths.size() - 2
	var report := {"frames": paths.size(), "threshold": threshold, "size": [size.x, size.y]}
	for name: String in rects:
		var area: int = (rects[name] as Rect2i).get_area()
		report[name] = {
			"change": snappedf(1e4 * change[name] / (pairs * area), 0.01),
			"pop": snappedf(1e4 * pop[name] / (triples * area), 0.01),
		}
	print(JSON.stringify(report))
	if Cli.has("heat"):
		_save_heat(heat, size, pairs, Cli.get_str("heat"))
	quit()


func _frames(prefix: String) -> PackedStringArray:
	var dir := prefix.get_base_dir()
	var stem := prefix.get_file() + "-"
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if (
			f.begins_with(stem)
			and f.ends_with(".png")
			and f.trim_prefix(stem).get_basename().is_valid_int()
		):
			out.append(dir.path_join(f))
	out.sort()
	return out


func _rgb(path: String) -> PackedByteArray:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGB8)
	return img.get_data()


func _count(
	a: PackedByteArray, b: PackedByteArray, rect: Rect2i, width: int, t: int, heat: PackedInt32Array
) -> int:
	var hits := 0
	for y in range(rect.position.y, rect.end.y):
		var px := y * width + rect.position.x
		var i := px * 3
		for x in rect.size.x:
			if (
				absi(a[i] - b[i]) > t
				or absi(a[i + 1] - b[i + 1]) > t
				or absi(a[i + 2] - b[i + 2]) > t
			):
				hits += 1
				heat[px] += 1
			i += 3
			px += 1
	return hits


func _count_pop(
	a: PackedByteArray, b: PackedByteArray, c: PackedByteArray, rect: Rect2i, width: int, t: int
) -> int:
	var hits := 0
	var t2 := t * 2 + 1
	for y in range(rect.position.y, rect.end.y):
		var i := (y * width + rect.position.x) * 3
		for x in rect.size.x:
			if (
				absi(2 * b[i] - a[i] - c[i]) > t2
				or absi(2 * b[i + 1] - a[i + 1] - c[i + 1]) > t2
				or absi(2 * b[i + 2] - a[i + 2] - c[i + 2]) > t2
			):
				hits += 1
			i += 3
	return hits


## Greyscale map of how often each pixel changed (regions only), brightened 3x.
func _save_heat(heat: PackedInt32Array, size: Vector2i, pairs: int, path: String) -> void:
	var bytes := PackedByteArray()
	bytes.resize(heat.size())
	for i in heat.size():
		bytes[i] = mini(255, heat[i] * 765 / pairs)
	Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, bytes).save_png(path)
