class_name FieldGuide
extends UiModal
## The Field Guide (H, or the book on the top bar): the counter rules on one
## page, like the quest log of a Warcraft III tower defense map. The element
## wheel (hover an element for what it beats and which towers carry it), the
## attack vs armor chart, counsel for the next wave and how to read damage
## numbers. Opening it pauses the game; closing resumes if opening paused it.

const PANEL_WIDTH := 920.0
const WHEEL_PX := 250.0
const INFO_WIDTH := 330.0
const CELL_WIDTH := 70.0
const CHART_WIDTH := 500.0
const COUNSEL_WIDTH := 500.0
## Same colours as the floating numbers (Fx.COUNTER_COLORS, poison ticks).
const POISON_COLOR := Color(0.5, 1.0, 0.4)

var _wheel := ElementWheel.new(WHEEL_PX)
var _wheel_info := UiKit.rich(UiTheme.SIZE_SMALL, INFO_WIDTH)
var _next_caption := UiKit.label("", &"Caption")
var _counsel: CounselView


func setup(game: Game) -> void:
	var box := build(game, "Field Guide", PANEL_WIDTH)
	dim_pressed.connect(close_panel)
	var sub := UiKit.label(
		"Every wave has an element and an armor class. Towers that counter both hit far harder.",
		&"Dim",
		UiTheme.SIZE_BODY
	)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var top := UiKit.hbox(24)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(_build_wheel())
	top.add_child(UiKit.divider(WHEEL_PX))
	top.add_child(_build_chart())
	box.add_child(top)
	box.add_child(_rule())
	var bottom := UiKit.hbox(24)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(_build_next())
	bottom.add_child(UiKit.divider(150))
	bottom.add_child(_build_numbers())
	box.add_child(bottom)
	box.add_child(_rule())
	var foot := UiKit.hbox(16)
	foot.add_child(
		UiKit.label(
			"H or Esc closes. Tower card tooltips rate each tower against the next wave.", &"Dim"
		)
	)
	var close := UiKit.text_button(game, "Close")
	close.custom_minimum_size = Vector2(120, 30)
	close.pressed.connect(close_panel)
	foot.add_child(close)
	box.add_child(foot)
	_wheel.focus_changed.connect(_on_wheel_focus)
	_on_wheel_focus(&"")


func _build_wheel() -> Control:
	var col := UiKit.vbox(6)
	col.add_child(UiKit.label("ELEMENT WHEEL", &"Caption"))
	_wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_wheel)
	_wheel_info.custom_minimum_size.y = 54
	col.add_child(_wheel_info)
	return col


## Attack types down, armor classes across, each cell the damage share.
func _build_chart() -> Control:
	var col := UiKit.vbox(6)
	col.add_child(UiKit.label("ATTACK VS ARMOR", &"Caption"))
	var grid := GridContainer.new()
	grid.columns = 1 + TowerInfo.CLASS_NAMES.size()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(UiKit.label(""))
	for c in TowerInfo.CLASS_NAMES:
		var head := UiKit.vbox(0)
		head.custom_minimum_size.x = CELL_WIDTH
		var icon := UiIcon.new(UiGlyphs.armor(c), 20.0)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		head.add_child(icon)
		var name := UiKit.label(TowerInfo.CLASS_NAMES[c], &"", UiTheme.SIZE_SMALL)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.add_theme_color_override("font_color", UiTheme.CLASS_COLORS[c])
		head.add_child(name)
		grid.add_child(head)
	for a in Damage.ATTACK_VS_CLASS:
		grid.add_child(_attack_head(a))
		for c in TowerInfo.CLASS_NAMES:
			grid.add_child(_cell(Damage.class_mult(a, c)))
	col.add_child(grid)
	var notes := UiKit.rich(UiTheme.SIZE_SMALL, CHART_WIDTH)
	var footman: int = CreepDefs.CREEPS[&"footman"].armor
	var tank: int = CreepDefs.CREEPS[&"steam_tank"].armor
	notes.text = (
		(
			"[color=#%s]Armor points cut damage on top: %d armor (Shield Footman) by %d%%,"
			+ " %d (Steam Tank) by %d%%. Poison ignores them; the Runesmith shreds them."
			+ " Only towers with the wing icon hit Air.[/color]"
		)
		% [
			UiTheme.hex(UiTheme.TEXT_DIM),
			footman,
			roundi((1.0 - Damage.armor_factor(footman)) * 100.0),
			tank,
			roundi((1.0 - Damage.armor_factor(tank)) * 100.0),
		]
	)
	col.add_child(notes)
	return col


func _attack_head(a: StringName) -> Control:
	var row := UiKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(UiIcon.new(UiGlyphs.attack(a), 20.0))
	var names := UiKit.vbox(-2)
	var title := UiKit.label(TowerInfo.ATTACK_NAMES[a], &"", UiTheme.SIZE_BODY)
	title.add_theme_font_override("font", UiTheme.bold())
	title.add_theme_color_override("font_color", UiTheme.ATTACK_COLORS[a])
	names.add_child(title)
	names.add_child(UiKit.label(", ".join(towers_with(&"attack", a)), &"Dim", UiTheme.SIZE_TINY))
	row.add_child(names)
	return row


func _cell(m: float) -> Control:
	var l := UiKit.label("—" if m == 0.0 else "%d%%" % roundi(m * 100.0), &"", UiTheme.SIZE_BODY)
	l.add_theme_font_override("font", UiTheme.bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = CELL_WIDTH
	var color := UiTheme.TEXT_DIM
	if m > 1.0:
		color = UiTheme.GOOD
	elif m < 1.0:
		color = UiTheme.BAD
	l.add_theme_color_override("font_color", color)
	if m == 0.0:
		l.tooltip_text = "Can't hit"
		l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _build_next() -> Control:
	var col := UiKit.vbox(6)
	col.add_child(_next_caption)
	_counsel = CounselView.new(_game, COUNSEL_WIDTH)
	_counsel.picked.connect(func(_id: StringName) -> void: close_panel())
	col.add_child(_counsel)
	return col


## A sample of each floating damage number and what it means.
func _build_numbers() -> Control:
	var col := UiKit.vbox(6)
	col.add_child(UiKit.label("DAMAGE NUMBERS", &"Caption"))
	var rows := [
		["88!", Fx.COUNTER_COLORS[&"strong"], "Counter hit: the element wheel's 200%"],
		["22", Fx.COUNTER_COLORS[&"weak"], "Resisted: the creep's element beats it"],
		["45", Fx.COUNTER_COLORS[&"neutral"], "Neutral"],
		["12", POISON_COLOR, "Poison tick, ignores armor"],
		["IMMUNE", Fx.COUNTER_COLORS[&"immune"], "Steam shroud: no damage"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in rows:
		var n := UiKit.label(r[0], &"", UiTheme.SIZE_LARGE if r[0] == "88!" else UiTheme.SIZE_BODY)
		n.add_theme_font_override("font", UiTheme.bold())
		n.add_theme_color_override("font_color", r[1])
		n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		n.add_theme_constant_override("outline_size", 4)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.custom_minimum_size.x = 64
		grid.add_child(n)
		grid.add_child(UiKit.label(r[2], &"Dim"))
	col.add_child(grid)
	return col


func _rule() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(PANEL_WIDTH - 40.0, 2)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(
		func() -> void:
			c.draw_line(Vector2(0, 1), Vector2(c.size.x, 1), Color(UiTheme.GOLD_DIM, 0.7))
	)
	return c


## Short names of the towers whose `key` stat is `value`, buildable first.
static func towers_with(key: String, value: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for id in TowerDefs.BUILD_ORDER + TowerDefs.EPICS:
		if TowerDefs.TOWERS[id].get(key, &"") == value:
			out.append(TowerInfo.short_name(id))
	return out


func _on_wheel_focus(e: StringName) -> void:
	if e == &"":
		_wheel_info.text = (
			(
				"[color=#%s]Hover an element to see what it beats and which towers carry it."
				+ " The next-wave chip at the top shows each wave's element.[/color]"
			)
			% UiTheme.hex(UiTheme.TEXT_DIM)
		)
		return
	var c := UiTheme.hex(UiTheme.element_color(e))
	_wheel_info.text = (
		"[color=#%s][b]%s[/b][/color] towers: %s.\n200%% vs %s creeps, 50%% vs %s creeps."
		% [
			c,
			TowerInfo.ELEMENT_NAMES[e],
			", ".join(towers_with(&"element", e)),
			TowerInfo.ELEMENT_NAMES[TowerInfo.strong_against(e)],
			TowerInfo.ELEMENT_NAMES[TowerInfo.weak_against(e)],
		]
	)


func open() -> void:
	var sim := _game.sim
	var next := sim.wave + 1
	var has_next := next <= sim.last_wave() and not _game.is_over()
	_next_caption.text = ("NEXT WAVE · WAVE %d" % next) if has_next else "NO WAVES LEFT"
	_counsel.show_wave(next if has_next else 0, sim.twist_for(next) if has_next else &"")
	open_modal()


func close_panel() -> void:
	_wheel.focus = &""
	close_modal()


func toggle() -> void:
	if visible:
		close_panel()
	else:
		open()
