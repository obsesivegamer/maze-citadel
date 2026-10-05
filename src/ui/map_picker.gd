class_name HudMapPicker
extends PanelContainer
## Map and rules choice under the gold and lives panel (docs/maps.md, GDD
## §5.0): one segment per map with its description beneath, and the Element TD
## | Classic switch. Like the mode, both are picked during the opening build
## phase; the panel goes away when wave 1 spawns. Picking another map or rule
## set rebuilds the board through game.change_map or game.change_rules. The
## rules sit here rather than beside the difficulty chips because under
## Element TD the top bar has no room left for them at 1600 px wide.

const GAP := 6.0
const BLURB_WIDTH := 236.0
## Both rows' captions take this width, so their segments line up.
const CAPTION_WIDTH := 44.0
const RULES_TIPS := {
	&"eletd":
	(
		"Element TD rules: towers reach the tiles around them, element picks, Guardians,"
		+ " four difficulties"
	),
	&"classic":
	(
		"Classic rules: the game as it was in 0.3, with long tower ranges and every tower"
		+ " from the start"
	),
}

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
	var maps := {}
	for id in MapDefs.ORDER:
		var offered := MapDefs.offered(id, game.sim.rules)
		maps[id] = [
			MapDefs.MAPS[id].short,
			(
				"%s: %s\n%s"
				% [
					MapDefs.display_name(id),
					MapDefs.MAPS[id].blurb,
					(
						"Switching map clears the board; pick before wave 1."
						if offered
						else "Played under the Element TD rules only."
					),
				]
			),
			offered,
		]
	col.add_child(_row("MAP", maps, game.sim.grid.map, game.change_map))
	var rules := {}
	var map := game.sim.grid.map
	for id: StringName in RULES_TIPS:
		var tip: String = RULES_TIPS[id]
		if not MapDefs.offered(map, id):
			tip += (
				"\nThe %s is Element TD only: this plays the %s."
				% [MapDefs.display_name(map), MapDefs.display_name(MapDefs.DEFAULT)]
			)
		rules[id] = [TowerInfo.rules_name(id), tip, true]
	col.add_child(_row("RULES", rules, game.sim.rules, game.change_rules))
	_blurb.text = (
		"[b]%s[/b] · %s"
		% [MapDefs.display_name(game.sim.grid.map), MapDefs.MAPS[game.sim.grid.map].blurb]
	)
	_blurb.add_theme_color_override("default_color", UiTheme.TEXT_DIM)
	col.add_child(_blurb)


## A caption and one segment per choice ({id: [label, tooltip, offered]});
## pressing one calls `change` with its id. A choice not offered is greyed out
## and its tooltip says why.
func _row(caption: String, choices: Dictionary, current: StringName, change: Callable) -> Control:
	var row := UiKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var label := UiKit.label(caption, &"Caption")
	label.custom_minimum_size.x = CAPTION_WIDTH
	row.add_child(label)
	var group := ButtonGroup.new()
	for id: StringName in choices:
		var b := UiKit.text_button(_game, choices[id][0], &"Segment")
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size.y = HudTopBar.BUTTON_PX
		b.tooltip_text = choices[id][1]
		b.set_pressed_no_signal(id == current)
		b.disabled = not choices[id][2]
		b.pressed.connect(change.bind(id))
		row.add_child(b)
	return row


func _process(_delta: float) -> void:
	visible = _game.sim.wave == 0 and not _game.is_over()
	if visible:
		position = Vector2(_anchor.position.x, _anchor.position.y + _anchor.size.y + GAP)
