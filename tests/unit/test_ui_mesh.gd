extends "res://tests/test_case.gd"

const AA_WIDTHS := [[0.8, 0.4], [2.0, 1.0], [3.75, 2.5], [6.0, 5.375], [0.0, 0.0]]


func _well_formed(m: UiMesh, label: String) -> void:
	check_eq(m.colors.size(), m.points.size(), label + " colours per vertex")
	check_eq(m.indices.size() % 3, 0, label + " whole triangles")
	for i in m.indices:
		if i < 0 or i >= m.points.size():
			failures.append("%s index %d out of range" % [label, i])
			return


func test_polygon_uses_the_engine_triangulation() -> void:
	var m := UiMesh.new()
	var square := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	m.draw_colored_polygon(square, Color.RED)
	check_eq(m.indices, Geometry2D.triangulate_polygon(square))
	check_eq(m.source_calls, 1)
	check(m.colors.count(Color.RED) == 4, "one colour per vertex")


func test_untriangulable_polygon_is_skipped() -> void:
	var m := UiMesh.new()
	m.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.ONE]), Color.RED)
	check(m.is_empty())
	check_eq(m.source_calls, 0)


func test_antialiasing_width_matches_the_engine() -> void:
	for pair in AA_WIDTHS:
		check_near(UiMesh.compensated_width(pair[0]), pair[1], 1e-5, "width %s" % pair[0])


func test_open_aa_polyline_has_feathered_caps() -> void:
	var m := UiMesh.new()
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])
	m.draw_polyline(pts, Color.WHITE, 2.0, true)
	# Middle strip 2n + 4, side strips 2n + 5 each (engine layout).
	check_eq(m.points.size(), 10 + 11 + 11)
	check_eq(m.indices.size(), (8 + 9 + 9) * 3)
	check_eq(m.source_calls, 3)
	check_eq(m.colors[0].a, 0.0, "begin cap fades out")
	check_eq(m.colors[2].a, 1.0, "body is opaque")
	check_near(m.points[2].y - m.points[3].y, -1.0, 1e-5, "half of the compensated width each side")
	_well_formed(m, "polyline")


func test_closed_ring_has_no_caps() -> void:
	var m := UiMesh.new()
	m.draw_arc(Vector2(20, 20), 10.0, 0.0, TAU, 40, Color.WHITE, 3.0, true)
	check_eq(m.points.size(), 80 * 3)
	check_eq(m.source_calls, 3)
	_well_formed(m, "ring")


func test_plain_polyline_is_one_strip() -> void:
	var m := UiMesh.new()
	m.draw_polyline(PackedVector2Array([Vector2.ZERO, Vector2(5, 0)]), Color.WHITE, 1.0)
	check_eq(m.points.size(), 4)
	check_eq(m.source_calls, 1)


func test_aa_circle_is_a_fan_and_a_feather() -> void:
	var m := UiMesh.new()
	m.draw_circle(Vector2(10, 10), 5.0, Color.WHITE, true, -1.0, true)
	check_eq(m.points.size(), 66 + 130)
	check_eq(m.indices.size(), 64 * 3 + 128 * 3)
	check_eq(m.source_calls, 2)
	check_near(
		m.points[0].x, 10.0 + 5.0 - UiMesh.FEATHER * 0.25, 1e-4, "fan shrinks for the feather"
	)
	check_near(m.points[66 + 1].x, 10.0 + 5.0 + UiMesh.FEATHER * 0.75, 1e-4, "feather rim")
	_well_formed(m, "circle")


func test_aa_line_is_nine_quads_and_batches() -> void:
	var m := UiMesh.new()
	m.draw_line(Vector2.ZERO, Vector2(10, 0), Color.WHITE, 2.0, true)
	check_eq(m.points.size(), 9 * 4)
	check_eq(m.indices.size(), 9 * 6)
	check_eq(m.source_calls, 0)


func test_rect_outline_is_a_closed_polyline() -> void:
	var m := UiMesh.new()
	m.draw_rect(Rect2(0, 0, 20, 10), Color.WHITE, false, 1.0, true)
	check_eq(m.points.size(), 10 * 3)
	check_eq(m.source_calls, 3)


func test_a_coin_is_one_call_instead_of_fourteen() -> void:
	var m := UiMesh.new()
	UiGlyphs.coin(m, Rect2(0, 0, 22, 22), Color.WHITE)
	check_eq(m.source_calls, 14)
	_well_formed(m, "coin")


func test_every_glyph_draws_into_a_mesh() -> void:
	var ids: Array[StringName] = []
	ids.append_array(UiGlyphs.SYMBOLS)
	ids.append_array(UiGlyphs.ELEMENT_IDS)
	ids.append_array(UiGlyphs.CLASS_IDS)
	ids.append_array(UiGlyphs.ATTACK_IDS)
	ids.append_array(UiUnitGlyphs.TOWERS)
	ids.append_array(UiUnitGlyphs.CREEPS)
	for id in ids:
		for px in [13.0, 44.0]:
			var m := UiMesh.new()
			UiGlyphs.draw(m, id, Rect2(Vector2(3, 5), Vector2(px, px)), Color(1, 1, 1, 0.42))
			check(not m.is_empty(), "%s draws something at %d px" % [id, px])
			_well_formed(m, String(id))


func test_flush_submits_and_starts_over() -> void:
	var ci := Node2D.new()
	var m := UiMesh.new()
	UiGlyphs.diamond(m, Vector2(5, 5), 3.0, Color.WHITE)
	m.flush(ci)
	check(m.is_empty())
	check(m.points.is_empty() and m.colors.is_empty())
	ci.free()


func test_hud_shapes_build() -> void:
	var builds := {
		"pointer": TowerPlaque._build_pointer,
		"pips": TowerPlaque._build_pips.bind(Vector2(31.5, 30), false, 2),
		"epic pips": TowerPlaque._build_pips.bind(Vector2(31.5, 30), true, 1),
		"band": WaveBanner._build_band.bind(Vector2(WaveBanner.WIDTH, WaveBanner.HEIGHT)),
	}
	for label in builds:
		var m := UiMesh.new()
		builds[label].call(m)
		check(not m.is_empty(), label + " draws")
		_well_formed(m, label)
	for id in [&"archer", &"frost_wyrm", &"bard"]:
		var card := TowerCard.new(id)
		card.size = TowerCard.SIZE
		var meshes := card._meshes(TowerCard.DIM, 30.0)
		check(not meshes[0].is_empty() and not meshes[2].is_empty(), "%s card shapes" % id)
		check(meshes[1].is_empty() != TowerDefs.TOWERS[id].get("air", false), "%s air badge" % id)
		check(card._meshes(TowerCard.DIM, 30.0)[0] == meshes[0], "%s reuses its meshes" % id)
		card.free()


func test_cache_returns_the_same_mesh_per_key() -> void:
	var calls := [0]
	var build := func(m: UiMesh) -> void:
		calls[0] += 1
		UiGlyphs.diamond(m, Vector2(4, 4), 3.0, Color.WHITE)
	var a := UiMesh.cached([&"test_cache", 1], build)
	var b := UiMesh.cached([&"test_cache", 1], build)
	var c := UiMesh.cached([&"test_cache", 2], build)
	check(a == b, "same key, same mesh")
	check(a != c, "new key, new mesh")
	check_eq(calls[0], 2, "built once per key")
