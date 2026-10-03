class_name Tutorial
extends Control
## First-run tutorial: teaches the element and armor counters over waves 1–10
## (Counsel.TUTORIAL_WAVES). A welcome card before wave 1 (the game waits
## behind it), then a counsel card for the next wave from the moment the
## previous one starts, with the towers it names glowing on the card bar, and
## a one-time tip the first time a counter hit, a resisted hit or an immune hit
## shows up. Finishing wave 10's counsel, or Skip, turns it off for the next
## launch; Settings → Tutorial turns it back on. Scripted runs never show it.

signal guide_requested

enum Step { OFF, WELCOME, COUNSEL, GRADUATED }

const CARD_WIDTH := 340.0
const CARD_TOP := 60.0
const CARD_RIGHT := 10.0
const WELCOME_WIDTH := 640.0
const WHEEL_PX := 200.0
const DIM := Color(0, 0, 0, 0.45)
const MARK_PERIOD := 0.9
## Command-line flags of scripted runs (bots, captures, benchmarks, probes).
const SCRIPTED_FLAGS: Array[String] = [
	"no-tutorial", "autoplay", "shot", "bench", "first-frame-out", "warp-wave"
]
const TIPS := {
	&"strong":
	"Gold numbers with “!” are counter hits: the tower's element beats the creep's, 200% damage.",
	&"weak":
	"Small grey-blue numbers are resisted hits: the creep's element beats the tower's, 50% damage.",
	&"immune": "IMMUNE: the steam shroud blocks every hit for 1.5 s. Keep the pressure on.",
}

## The welcome card has been seen since launch (survives scene reloads).
static var _welcomed := false

var step := Step.OFF
## Saves "tutorial off" when the player finishes or skips; tests turn it off.
var persist := true

var _game: Game
var _cards := {}
var _welcome := Control.new()
var _card := UiKit.panel()
var _card_caption := UiKit.label("", &"Caption")
var _card_title := UiKit.label("", &"Heading")
var _counsel: CounselView
var _tip := UiKit.rich(UiTheme.SIZE_SMALL, CARD_WIDTH)
var _graduation := UiKit.rich(UiTheme.SIZE_SMALL, CARD_WIDTH)
var _end_button: Button
var _marks := Control.new()
var _marked: Array[StringName] = []
var _tips_shown := {}
var _paused_here := false
var _time := 0.0


## Shows the tutorial unless a scripted-run flag is set; `--tutorial` forces it.
static func wanted() -> bool:
	return wanted_for(Cli.args(), Save.setting("tutorial", true))


static func wanted_for(args: Dictionary, saved: bool) -> bool:
	if args.has("tutorial"):
		return true
	for flag in SCRIPTED_FLAGS:
		if args.has(flag):
			return false
	return saved


## `cards` maps tower ids to their bottom-bar cards, for the glow marks.
## Nothing shows until start().
func setup(game: Game, cards: Dictionary) -> void:
	_game = game
	_cards = cards
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_build_card()
	_build_welcome()
	game.sim_event.connect(_on_sim_event)


## Starts (or restarts) from wherever the match is: the welcome card before
## wave 1 (once per launch, so a map switch or Play again skips it), otherwise
## the counsel for the next wave.
func start() -> void:
	if _game.sim.wave == 0 and not _welcomed:
		_show_welcome()
	else:
		_advance(_game.sim.wave)


## Ends the tutorial now; `remember` keeps it off for the next launch.
func finish(remember := true) -> void:
	_hide_welcome()
	step = Step.OFF
	_card.visible = false
	_mark(_empty())
	if remember and persist:
		Save.set_setting("tutorial", false)


## Settings → Tutorial.
func on_setting(key: String, on: bool) -> void:
	if key != "tutorial":
		return
	if on and step == Step.OFF:
		start()
	elif not on and step != Step.OFF:
		finish(false)


func welcome_visible() -> bool:
	return _welcome.visible


func card_visible() -> bool:
	return _card.visible


## The wave the counsel card is about (0 when none).
func counsel_wave() -> int:
	return _counsel.wave if step == Step.COUNSEL else 0


func marked() -> Array[StringName]:
	return _marked


func tip_text() -> String:
	return _tip.text if _tip.visible else ""


func _build_welcome() -> void:
	_welcome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_welcome.mouse_filter = Control.MOUSE_FILTER_STOP
	_welcome.visible = false
	add_child(_welcome)
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_welcome.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_welcome.add_child(center)
	var panel := UiKit.panel()
	panel.custom_minimum_size.x = WELCOME_WIDTH
	center.add_child(panel)
	var box := UiKit.vbox(12)
	panel.add_child(box)
	var title := UiKit.label("Welcome to the Citadel", &"Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var intro := UiKit.rich(UiTheme.SIZE_BODY, WELCOME_WIDTH - 30.0)
	intro.text = (
		"Wall the plateau with towers to stretch the creeps' road from the red portal to the"
		+ " blue gate. The road can never be sealed.\n[b]Every wave has an element and an armor"
		+ " class[/b], and towers that counter both hit far harder."
	)
	box.add_child(intro)
	var row := UiKit.hbox(18)
	var wheel := ElementWheel.new(WHEEL_PX, false)
	row.add_child(wheel)
	var rules := UiKit.rich(UiTheme.SIZE_BODY, WELCOME_WIDTH - WHEEL_PX - 60.0)
	var good := UiTheme.hex(UiTheme.GOOD)
	rules.text = (
		(
			"[b]Elements.[/b] Each element deals [color=#%s]200%%[/color] to the next one round"
			+ " the wheel and [color=#%s]50%%[/color] back.\n\n[b]Armor.[/b] Pierce beats Light"
			+ " armor and Air, Siege beats Armored, Poison ignores armor.\n\n[b]Read the wave.[/b]"
			+ " The chip at the top shows the next wave: its creeps, element and armor."
		)
		% [good, UiTheme.hex(UiTheme.BAD)]
	)
	row.add_child(rules)
	box.add_child(row)
	var outro := UiKit.rich(UiTheme.SIZE_BODY, WELCOME_WIDTH - 30.0)
	outro.text = (
		(
			"For the first %d waves a counsel card names the next wave's counters and lights up the"
			+ " towers to build. The Field Guide (H) keeps the rules at hand."
		)
		% Counsel.TUTORIAL_WAVES
	)
	box.add_child(outro)
	var buttons := UiKit.hbox(12)
	var begin := UiKit.text_button(_game, "Begin")
	begin.add_theme_font_override("font", UiTheme.heading(700))
	begin.add_theme_font_size_override("font_size", UiTheme.SIZE_LARGE)
	begin.custom_minimum_size = Vector2(180, 38)
	begin.pressed.connect(_begin)
	buttons.add_child(begin)
	var skip := UiKit.text_button(_game, "Skip tutorial")
	skip.custom_minimum_size = Vector2(140, 38)
	skip.pressed.connect(finish)
	buttons.add_child(skip)
	box.add_child(buttons)


func _build_card() -> void:
	_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.offset_right = -CARD_RIGHT
	_card.offset_top = CARD_TOP
	_card.visible = false
	add_child(_card)
	var box := UiKit.vbox(6)
	_card.add_child(box)
	var head := UiKit.hbox(6)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	_card_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_card_caption)
	var hide_button := UiKit.text_button(_game, "Hide", &"Segment")
	hide_button.tooltip_text = "Hide this card until the next wave starts"
	hide_button.pressed.connect(_hide_card)
	head.add_child(hide_button)
	box.add_child(head)
	box.add_child(_card_title)
	_counsel = CounselView.new(_game, CARD_WIDTH, true)
	box.add_child(_counsel)
	_graduation.visible = false
	box.add_child(_graduation)
	_tip.visible = false
	box.add_child(_tip)
	var foot := UiKit.hbox(8)
	foot.alignment = BoxContainer.ALIGNMENT_BEGIN
	var guide := UiKit.text_button(_game, "Field Guide (H)", &"Segment")
	guide.pressed.connect(guide_requested.emit)
	foot.add_child(guide)
	_end_button = UiKit.text_button(_game, "End tutorial", &"Segment")
	_end_button.pressed.connect(finish)
	foot.add_child(_end_button)
	box.add_child(foot)


func _show_welcome() -> void:
	step = Step.WELCOME
	_welcomed = true
	_card.visible = false
	_welcome.visible = true
	if not _game.paused:
		_game.toggle_pause()
		_paused_here = true


func _hide_welcome() -> void:
	if not _welcome.visible:
		return
	_welcome.visible = false
	if _paused_here and _game.paused:
		_game.toggle_pause()
	_paused_here = false


func _begin() -> void:
	_hide_welcome()
	_advance(_game.sim.wave)


## Wave `started` has begun (0: none yet): counsel for the next one, or the
## closing card once the last tutorial wave is under way.
func _advance(started: int) -> void:
	if started >= Counsel.TUTORIAL_WAVES:
		_graduate()
		return
	step = Step.COUNSEL
	var next := started + 1
	_card_caption.text = "COUNSEL · LESSON %d OF %d" % [next, Counsel.TUTORIAL_WAVES]
	_card_title.text = "Wave %d · %s" % [next, Counsel.lesson(next)]
	_counsel.visible = true
	_counsel.show_wave(next, _game.sim.twist_for(next))
	_graduation.visible = false
	_end_button.visible = true
	_card.visible = true
	_card.reset_size()
	_mark(_counsel.picks())


func _graduate() -> void:
	step = Step.GRADUATED
	_card_caption.text = "COUNSEL"
	_card_title.text = "You know the counters"
	_counsel.visible = false
	_tip.visible = false
	_graduation.visible = true
	_graduation.text = (
		"Every wave from here on is read the same way: counter its element and its armor."
		+ " The Field Guide (H) keeps the wheel and the armor chart, and each tower card's"
		+ " tooltip rates that tower against the next wave."
	)
	_end_button.visible = false
	_card.visible = true
	_card.reset_size()
	_mark(_empty())
	if persist:
		Save.set_setting("tutorial", false)


func _hide_card() -> void:
	_card.visible = false
	_mark(_empty())
	if step == Step.GRADUATED:
		step = Step.OFF


func _on_sim_event(e: Dictionary) -> void:
	if step == Step.OFF:
		return
	match e.type:
		&"wave_started":
			if step == Step.GRADUATED:
				_hide_card()
			elif step == Step.COUNSEL:
				_advance(e.wave)
		&"hit":
			if step == Step.COUNSEL and TIPS.has(e.counter):
				_show_tip(e.counter)
		&"victory", &"defeat":
			_card.visible = false
			_mark(_empty())


func _show_tip(kind: StringName) -> void:
	if _tips_shown.has(kind) or not _card.visible:
		return
	_tips_shown[kind] = true
	_tip.text = "[color=#%s][b]Tip:[/b] %s[/color]" % [UiTheme.hex(UiTheme.GOLD_BRIGHT), TIPS[kind]]
	_tip.visible = true
	_card.reset_size()


func _mark(ids: Array[StringName]) -> void:
	_marked = ids
	_marks.queue_redraw()


func _empty() -> Array[StringName]:
	var out: Array[StringName] = []
	return out


func _unhandled_input(event: InputEvent) -> void:
	if _welcome.visible and event.is_action_pressed(&"deselect"):
		_begin()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _marked.is_empty():
		return
	_time += delta
	_marks.queue_redraw()


## A pulsing gold frame and a chevron over each card the counsel names.
func _draw_marks() -> void:
	var pulse := 0.55 + 0.45 * sin(_time * TAU / MARK_PERIOD)
	var color := Color(UiTheme.GOLD_BRIGHT, pulse)
	for id in _marked:
		var card: Control = _cards.get(id)
		if card == null or not card.is_visible_in_tree():
			continue
		var r := card.get_global_rect()
		r.position -= _marks.get_global_rect().position
		_marks.draw_rect(r.grow(2.0), color, false, 2.5, true)
		var tip := Vector2(r.get_center().x, r.position.y - 3.0)
		var pts := PackedVector2Array([tip, tip + Vector2(-8, -9), tip + Vector2(8, -9)])
		_marks.draw_colored_polygon(pts, color)
