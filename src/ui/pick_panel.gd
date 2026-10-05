class_name PickPanel
extends UiModal
## The element picks under the eletd rules (E, or the Pick chip on the top
## bar): a row per element and one for Interest, each with the level it would
## reach, what taking it does in plain words (the towers it opens or lets
## upgrade, the Guardian to kill, the gold Interest adds), its counters, how
## it fares on the coming waves and a button that takes it (Take, or Summon
## Guardian with the Guardian's HP). A row that can't be taken says why. The
## game keeps running behind it unless it was paused already. Keys 1–7 take a
## row, Enter the highlighted one (under the mouse, else the first open one);
## E or Esc closes. The wording comes from ElementPicks.

const PANEL_WIDTH := 1100.0
const GLYPH_PX := 30.0
const TOWER_PX := 22.0
const NAME_WIDTH := 112.0
const UNLOCK_WIDTH := 340.0
const COUNTER_WIDTH := 290.0
const ACTION_WIDTH := 168.0
## A row that can't be taken.
const ROW_DIM := Color(1, 1, 1, 0.5)

var _header := UiKit.label("", &"Dim", UiTheme.SIZE_BODY)
var _rows: Array[Dictionary] = []
var _focus := 0


func setup(game: Game) -> void:
	pauses = false
	var box := build_frame(game, "Element Picks", PANEL_WIDTH, 6)
	dim_pressed.connect(close_modal)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_header)
	for i in ElementPicks.CHOICES.size():
		box.add_child(_build_row(i))
	var foot := UiKit.hbox(16)
	foot.add_child(
		UiKit.label(
			(
				"1–7 or Enter take a row. %s or Esc closes; the battle goes on behind."
				% ElementPicks.KEY
			),
			&"Dim"
		)
	)
	var close := UiKit.text_button(game, "Close")
	close.custom_minimum_size = Vector2(120, 30)
	close.pressed.connect(close_modal)
	foot.add_child(close)
	box.add_child(foot)
	game.sim_event.connect(_on_sim_event)


## The row for keys 1–7 (build_0 to build_6), or -1.
static func key_row(event: InputEvent) -> int:
	for i in ElementPicks.CHOICES.size():
		if event.is_action_pressed(StringName("build_%d" % i)):
			return i
	return -1


func open() -> void:
	refresh()
	_focus = 0
	for i in _rows.size():
		if not _rows[i].button.disabled:
			_focus = i
			break
	_show_focus()
	open_modal()


func toggle() -> void:
	if visible:
		close_modal()
	else:
		open()


## Keys while the panel is up, and E to open it while a pick waits. True when
## the key was the panel's.
func handle_key(event: InputEvent) -> bool:
	if not visible:
		if event.is_action_pressed(&"element_picks") and _game.sim.elements.pending_picks() > 0:
			open()
			return true
		return false
	if event.is_action_pressed(&"element_picks") or event.is_action_pressed(&"deselect"):
		close_modal()
		return true
	var key := event as InputEventKey
	var enter := key != null and key.pressed and not key.echo
	enter = enter and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER)
	var i := _focus if enter else key_row(event)
	if i >= 0:
		take(i)
		return true
	# The other build keys would pick a tower behind the panel.
	for b in InputSetup.BUILD_KEYS.size():
		if event.is_action_pressed(StringName("build_%d" % b)):
			return true
	return false


## Spends a pick on row `i`; closes once no pick is left.
func take(i: int) -> void:
	if not _game.pick_element(ElementPicks.CHOICES[i]):
		if _game.audio != null:
			_game.audio.play_ui(&"invalid_thunk")
		return
	if _game.sim.elements.pending_picks() <= 0:
		close_modal()
	else:
		refresh()


func refresh() -> void:
	var sim := _game.sim
	_header.text = ElementPicks.header(sim)
	for i in _rows.size():
		var w: Dictionary = _rows[i]
		var r := ElementPicks.row(sim, ElementPicks.CHOICES[i])
		w.from_to.text = r.from_to
		w.unlocks.text = r.unlocks
		w.counters.text = r.counters
		w.waves.text = r.waves
		w.waves.visible = r.waves != ""
		w.button.text = r.action
		w.button.disabled = not r.enabled
		var hp := "Guardian: %s HP" % TowerInfo.fmt_big(r.hp) if r.hp > 0.0 else ""
		w.note.text = r.reason if r.reason != "" else hp
		w.note.add_theme_color_override(
			"font_color", UiTheme.BAD if r.reason != "" else UiTheme.TEXT_DIM
		)
		w.note.visible = w.note.text != ""
		w.body.modulate = Color.WHITE if r.enabled else ROW_DIM


func _build_row(i: int) -> Control:
	var choice := ElementPicks.CHOICES[i]
	var r := ElementPicks.row(_game.sim, choice)
	var panel := UiKit.panel(&"Chip", false)
	panel.mouse_entered.connect(_set_focus.bind(i))
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)
	var body := UiKit.hbox(12)
	body.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(body)
	var key := UiKit.label(str(i + 1), &"Caption", UiTheme.SIZE_BODY)
	key.custom_minimum_size.x = 12
	body.add_child(key)
	body.add_child(UiIcon.new(r.glyph, GLYPH_PX))
	var names := UiKit.vbox(-2)
	names.custom_minimum_size.x = NAME_WIDTH
	var title := UiKit.label(r.name, &"Heading")
	var color := (
		UiTheme.GOLD_BRIGHT if choice == SimElements.INTEREST else UiTheme.element_color(choice)
	)
	title.add_theme_color_override("font_color", color)
	names.add_child(title)
	var from_to := UiKit.label("", &"Dim")
	names.add_child(from_to)
	body.add_child(names)
	var unlock_col := UiKit.hbox(4)
	unlock_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	unlock_col.custom_minimum_size.x = UNLOCK_WIDTH
	for id in r.towers:
		unlock_col.add_child(UiIcon.new(id, TOWER_PX))
	var unlocks := UiKit.rich(UiTheme.SIZE_SMALL)
	unlocks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_col.add_child(unlocks)
	body.add_child(unlock_col)
	var counter_col := UiKit.vbox(0)
	counter_col.custom_minimum_size.x = COUNTER_WIDTH
	var counters := UiKit.rich(UiTheme.SIZE_SMALL, COUNTER_WIDTH)
	counter_col.add_child(counters)
	var waves := UiKit.rich(UiTheme.SIZE_TINY, COUNTER_WIDTH)
	counter_col.add_child(waves)
	body.add_child(counter_col)
	var action := UiKit.vbox(1)
	action.custom_minimum_size.x = ACTION_WIDTH
	var button := UiKit.text_button(_game, "")
	button.custom_minimum_size = Vector2(ACTION_WIDTH, 28)
	button.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
	button.pressed.connect(take.bind(i))
	action.add_child(button)
	var note := UiKit.label("", &"", UiTheme.SIZE_TINY)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_child(note)
	row.add_child(action)
	(
		_rows
		. append(
			{
				"panel": panel,
				"body": body,
				"from_to": from_to,
				"unlocks": unlocks,
				"counters": counters,
				"waves": waves,
				"button": button,
				"note": note,
			}
		)
	)
	return panel


func _set_focus(i: int) -> void:
	_focus = i
	_show_focus()


## The highlighted row (Enter takes it) gets a bright border.
func _show_focus() -> void:
	for i in _rows.size():
		var border := UiTheme.GOLD_BRIGHT if i == _focus else UiTheme.GOLD_DIM
		_rows[i].panel.add_theme_stylebox_override("panel", UiTheme.chip_box(border))


func _on_sim_event(e: Dictionary) -> void:
	if not visible:
		return
	match e.type:
		&"victory", &"defeat":
			close_modal()
		&"pick_granted", &"pick_spent", &"element_gained", &"guardian_spawned", &"wave_started":
			refresh()
