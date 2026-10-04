class_name TowerTooltip
extends PanelContainer
## Hover card for a tower card: name, family, blurb, stats per level, range,
## counters ("Strong vs Dark · Weak vs Stone · Bonus vs Air/Light") and how it
## fares against the next wave. Rebuilt only when a different card is hovered.

const WIDTH := 330.0
const ICON_PX := 34.0
const COLUMN_WIDTH := 58.0
const COUNTER_COLORS := {
	&"strong": UiTheme.GOOD,
	&"weak": UiTheme.BAD,
	&"even": UiTheme.TEXT,
	&"bonus": UiTheme.GOLD_BRIGHT,
	&"poor": Color(0.95, 0.65, 0.4),
	&"note": UiTheme.TEXT_DIM,
}

var shown: StringName = &""

var _icon := UiIcon.new(&"", ICON_PX)
var _title := UiKit.label("", &"Heading")
var _subtitle := UiKit.label("", &"Dim")
var _blurb := UiKit.label("", &"", UiTheme.SIZE_SMALL)
var _grid := GridContainer.new()
var _counters := UiKit.rich(UiTheme.SIZE_SMALL, WIDTH)
var _vs_next := UiKit.rich(UiTheme.SIZE_SMALL, WIDTH)
var _footer := UiKit.label("", &"Dim")


func _init() -> void:
	theme_type_variation = &"TipPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.add_trim(self)
	var box := UiKit.vbox(6)
	add_child(box)
	var head := UiKit.hbox(10)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.add_child(_icon)
	var names := UiKit.vbox(0)
	names.add_child(_title)
	names.add_child(_subtitle)
	head.add_child(names)
	box.add_child(head)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size.x = WIDTH
	box.add_child(_blurb)
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_grid)
	box.add_child(_counters)
	box.add_child(_vs_next)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.custom_minimum_size.x = WIDTH
	box.add_child(_footer)


func show_for(id: StringName, sim: GameSim) -> void:
	_footer_for(id, sim)
	_vs_next_for(id, sim)
	if id == shown:
		return
	shown = id
	_icon.glyph = id
	_title.text = TowerInfo.full_name(id)
	_subtitle.text = TowerInfo.subtitle(id)
	_blurb.text = TowerInfo.blurb(id)
	_fill_grid(id)
	var parts := PackedStringArray()
	for p in TowerInfo.counter_parts(id):
		parts.append("[color=#%s]%s[/color]" % [UiTheme.hex(COUNTER_COLORS[p[0]]), p[1]])
	_counters.text = TowerInfo.SEP.join(parts)
	reset_size()


func _fill_grid(id: StringName) -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var epic := TowerInfo.is_epic(id)
	_grid.columns = 2 if epic else 1 + TowerDefs.MAX_LEVEL
	if not epic:
		_grid.add_child(UiKit.label(""))
		for level in TowerDefs.MAX_LEVEL:
			var h := UiKit.label("L%d" % (level + 1), &"Caption")
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.custom_minimum_size.x = COLUMN_WIDTH
			_grid.add_child(h)
	for row in TowerInfo.stat_rows(id):
		var head := UiKit.label(row[0], &"Dim")
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(head)
		for v in row[1]:
			var cell := UiKit.label(v, &"", UiTheme.SIZE_SMALL)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cell.custom_minimum_size.x = COLUMN_WIDTH
			_grid.add_child(cell)


## Counter multipliers on the next wave's creeps, e.g. "Next wave 3: 350% vs
## Shield Footman"; hidden for the Bard and after the last wave.
func _vs_next_for(id: StringName, sim: GameSim) -> void:
	var next := sim.wave + 1
	var text := ""
	if next <= sim.last_wave() and TowerDefs.TOWERS[id].has("attack"):
		text = (
			"[color=#%s]Next wave %d:[/color] %s"
			% [UiTheme.hex(UiTheme.GOLD), next, Counsel.tower_vs_wave(id, next, sim.rules)]
		)
	if text != _vs_next.text:
		_vs_next.text = text
		_vs_next.visible = text != ""
		reset_size()


## The changing last line: why a card is dim, or how to fuse an Epic.
func _footer_for(id: StringName, sim: GameSim) -> void:
	var text := ""
	if TowerInfo.is_epic(id):
		text = TowerInfo.epic_requirement(id)
		if TowerInfo.can_fuse(sim, id):
			text = "Fusion ready — click to pick the first tower, then its partner."
	elif sim.elements.needs(id) != "":
		text = ElementPicks.locked_reason(sim, id)
	elif sim.gold < TowerInfo.card_cost(id):
		text = "Need %d more gold." % (TowerInfo.card_cost(id) - sim.gold)
	else:
		text = "Press %s or click to build. Shift-click keeps building." % TowerDefs.hotkey(id)
	if text != _footer.text:
		_footer.text = text
		reset_size()
