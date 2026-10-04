extends SceneTree
## Headless GPU-cost proxy for the wave-24 battle: triangles (MultiMesh
## instances included), shadow-casting and alpha-tested triangles, surfaces,
## particles and lights per subsystem. Headless can't time the GPU, so use this
## to check an optimisation moves the needle before spending screen time.
## Accepts the same `--pf-*` flags as the game:
##   godot --headless --path . --script res://tests/perf/census.gd -- --pf-x=1

var game: Game


func _initialize() -> void:
	# The Citadel Plateau under classic rules, as docs/perf.md measured them,
	# unless --map or --rules says otherwise; never the player's last pick.
	Game._carry = {
		"map": Cli.get_str("map", MapDefs.DEFAULT), "rules": Cli.get_str("rules", "classic")
	}
	game = Game.new()
	root.add_child(game)
	process_frame.connect(_go, CONNECT_ONE_SHOT)


func _go() -> void:
	game.autoplay = AutoplayBot.new(game.sim, &"smart")
	game.warp_to_wave(24, 18.0)
	for i in 3:
		game._process(1.0 / 60.0)
	var total := {}
	for g in ["world", "units", "fx", "path_preview", "builder"]:
		var r := _measure(game.get(g))
		for k in r:
			total[k] = total.get(k, 0) + r[k]
		_print(g, r)
	_print("TOTAL", total)
	print("flags: ", PerfFlags.active())
	quit()


func _measure(node: Node) -> Dictionary:
	var r := {
		"tris": 0,
		"shadow": 0,
		"cutout": 0,
		"blended": 0,
		"surfaces": 0,
		"particles": 0,
		"lights": 0
	}
	for n in node.find_children("*", "", true, false):
		if n is GPUParticles3D:
			var p := n as GPUParticles3D
			if p.is_visible_in_tree() and (p.emitting or not p.one_shot):
				r.particles += int(p.amount * p.amount_ratio)
			continue
		if n is Light3D:
			r.lights += 1 if (n as Light3D).is_visible_in_tree() else 0
			continue
		if not n is GeometryInstance3D or not (n as Node3D).is_visible_in_tree():
			continue
		var gi := n as GeometryInstance3D
		var mesh: Mesh = null
		var count := 1
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			count = (
				mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			)
		if mesh == null:
			continue
		var t := _triangles(mesh) * count
		r.tris += t
		r.surfaces += mesh.get_surface_count()
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			r.shadow += t
		var kind := _material_kind(gi, mesh)
		if kind == 1:
			r.cutout += t
		elif kind == 2:
			r.blended += t
	return r


static func _triangles(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		t += (
			(idx as PackedInt32Array).size() / 3
			if idx != null
			else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		)
	return t


## 0 opaque, 1 alpha-tested (discard / scissor), 2 alpha-blended.
static func _material_kind(gi: GeometryInstance3D, mesh: Mesh) -> int:
	var mats: Array[Material] = []
	if gi.material_override:
		mats.append(gi.material_override)
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		if gi is MeshInstance3D and (gi as MeshInstance3D).get_surface_override_material(s):
			m = (gi as MeshInstance3D).get_surface_override_material(s)
		if m:
			mats.append(m)
	var kind := 0
	for m in mats:
		if m is BaseMaterial3D:
			var b := m as BaseMaterial3D
			if (
				b.transparency
				in [
					BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,
					BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
				]
			):
				kind = maxi(kind, 1)
			elif b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				kind = 2
		elif m is ShaderMaterial and (m as ShaderMaterial).shader:
			var code := (m as ShaderMaterial).shader.code
			if "ALPHA_SCISSOR" in code or "discard" in code:
				kind = maxi(kind, 1)
			elif "blend_add" in code or "blend_mix" in code:
				kind = 2
	return kind


static func _print(label: String, r: Dictionary) -> void:
	print(
		(
			"%-12s tris %9d · shadow %9d · cutout %9d · blended %7d · surfaces %5d · %s"
			% [
				label,
				r.tris,
				r.shadow,
				r.cutout,
				r.blended,
				r.surfaces,
				"particles %5d · lights %d" % [r.particles, r.lights],
			]
		)
	)
