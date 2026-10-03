class_name HudMapPicker
extends PanelContainer
## Map choice under the gold and lives panel (docs/maps.md): one segment per
## map with its description beneath. Like the mode, the map is picked during
## the opening build phase; the panel goes away when wave 1 spawns. Picking
## another map rebuilds the board through game.change_map.

const GAP := 6.0
const BLURB_WIDTH := 236.0

var _game: Game
var _anchor: Control
var _blurb := UiKit.rich(UiTheme.SIZE_TINY, BLURB_WIDTH)


## `anchor` is the panel this one sits under.
func setup(game: Game, anchor: Control) -> void:
	_game = game
	_anchor = anchor
	UiTheme.add_trim(self)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var col := UiKit.vbox(4)
	add_child(col)
	var row := UiKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(UiKit.label("MAP", &"Caption"))
	var group := ButtonGroup.new()
	for id in MapDefs.ORDER:
		var b := UiKit.text_button(game, MapDefs.MAPS[id].short, &"Segment")
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size.y = HudTopBar.BUTTON_PX
		b.tooltip_text = (
			"%s: %s\nSwitching map clears the board; pick before wave 1."
			% [MapDefs.display_name(id), MapDefs.MAPS[id].blurb]
		)
		b.set_pressed_no_signal(id == game.sim.grid.map)
		b.pressed.connect(_pick.bind(id))
		row.add_child(b)
	col.add_child(row)
	_blurb.text = (
		"[b]%s[/b] · %s"
		% [MapDefs.display_name(game.sim.grid.map), MapDefs.MAPS[game.sim.grid.map].blurb]
	)
	_blurb.add_theme_color_override("default_color", UiTheme.TEXT_DIM)
	col.add_child(_blurb)


func _pick(id: StringName) -> void:
	_game.change_map(id)


func _process(_delta: float) -> void:
	visible = _game.sim.wave == 0 and not _game.is_over()
	if visible:
		position = Vector2(_anchor.position.x, _anchor.position.y + _anchor.size.y + GAP)
