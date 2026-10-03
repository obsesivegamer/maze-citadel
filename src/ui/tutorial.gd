class_name Tutorial
extends Control
## First-run tutorial: teaches the element and armor counters over waves 1–10
## (Counsel.TUTORIAL_WAVES). A welcome card before wave 1 (the game waits
## behind it), then a counsel card for the next wave from the moment the
## previous one starts, with the towers it names glowing on the card bar, and
## a one-time tip the first time a counter hit, a resisted hit or an immune hit
## shows up. Playing through to wave 10, or Skip, turns it off for the next
## launch; Settings → Tutorial turns it back on. Scripted and headless runs
## never show it. The HUD routes keys to it while the welcome is up.

signal guide_requested

enum Step { OFF, WELCOME, COUNSEL, GRADUATED }

const CARD_WIDTH := 340.0
const CARD_TOP := 60.0
const CARD_RIGHT := 10.0
const WELCOME_WIDTH := 700.0
const WHEEL_PX := 200.0
const MARK_PERIOD := 1.1
const MARK_COLOR := Color(0.55, 0.92, 0.45)
## Command-line flags of scripted runs (bots, captures, benchmarks, probes).
const SCRIPTED_FLAGS: Array[String] = [
	"no-tutorial", "autoplay", "shot", "bench", "first-frame-out", "warp-wave"
]
## One-time tips on the first hit of each kind; {keys} come from the tables (tip()).
const TIPS := {
	&"strong":
	"Gold numbers with “!” are counter hits: the tower's element beats the creep's, {strong} damage.",
	&"weak":
	"Small grey-blue numbers are resisted hits: the creep's element beats the tower's, {weak} damage.",
	&"immune":
	"IMMUNE: the steam shroud blocks every hit for {immune_time} s. Keep the pressure on.",
}

## The welcome card has been seen since launch (survives scene reloads).
static var _welcomed := false

var step := Step.OFF
## Saves "tutorial off" when the player finishes or skips; tests turn it off.
var persist := true

var _game: Game
var _cards := {}
var _welcome := UiModal.new()
var _card := UiKit.panel()
var _card_caption := UiKit.label("", &"Caption")
var _card_title := UiKit.label("", &"Heading")
var _counsel: CounselView
var _tip := UiKit.rich(UiTheme.SIZE_SMALL, CARD_WIDTH)
var _graduation := UiKit.rich(UiTheme.SIZE_SMALL, CARD_WIDTH)
var _end_button: Button
var _hide_button: Button
var _marks := Control.new()
var _marked: Array[StringName] = []
var _tips_shown := {}
var _time := 0.0


## Shows the tutorial unless the run is headless (tools and probes) or a
## scripted-run flag is set; `--tutorial` forces it.
static func wanted() -> bool:
	var headless := DisplayServer.get_name() == "headless"
	return wanted_for(Cli.args(), Save.setting("tutorial", true), headless)


static func wanted_for(args: Dictionary, saved: bool, headless := false) -> bool:
	if args.has("tutorial"):
		return true
	if headless:
		return false
	for flag in SCRIPTED_FLAGS:
		if args.has(flag):
			return false
	return saved


static func tip(kind: StringName) -> String:
	return (
		TIPS[kind]
		. format(
			{
				"strong": Counsel.pct(Damage.STRONG, false),
				"weak": Counsel.pct(Damage.WEAK, false),
				"immune_time": Counsel.num(GameSim.TANK_IMMUNE_TIME),
			}
		)
	)


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
	_welcome.close_modal()
	step = Step.OFF
	_card.visible = false
	_mark(_empty())
	if remember and persist:
		Save.set_setting("tutorial", false)


## Settings → Tutorial. Turning it on goes straight to the counsel card: the
## welcome would open under the settings panel.
func on_setting(key: String, on: bool) -> void:
	if key != "tutorial":
		return
	if on and step == Step.OFF:
		_advance(_game.sim.wave)
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
	add_child(_welcome)
	var box := _welcome.build_frame(_game, "Welcome to the Citadel", WELCOME_WIDTH, 12)
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
	var rules := UiKit.rich(UiTheme.SIZE_BODY, WELCOME_WIDTH - wheel.custom_minimum_size.x - 50.0)
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
	var go := UiKit.text_button(_game, "Begin")
	go.add_theme_font_override("font", UiTheme.heading(700))
	go.add_theme_font_size_override("font_size", UiTheme.SIZE_LARGE)
	go.custom_minimum_size = Vector2(180, 38)
	go.pressed.connect(begin)
	buttons.add_child(go)
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
	_hide_button = UiKit.text_button(_game, "Hide", &"Segment")
	_hide_button.tooltip_text = "Hide this card until the next wave starts"
	_hide_button.pressed.connect(_hide_card)
	head.add_child(_hide_button)
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
	_welcome.open_modal()


## Closes the welcome card and shows the first counsel.
func begin() -> void:
	_welcome.close_modal()
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
	_hide_button.text = "Hide"
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
	_hide_button.text = "Done"
	_card.visible = true
	_card.reset_size()
	_mark(_empty())


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
				# Played through to the end: off for the next launch. Turning it on
				# from Settings after wave 10 only shows the closing card.
				if step == Step.GRADUATED and persist:
					Save.set_setting("tutorial", false)
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
	_tip.text = "[color=#%s][b]Tip:[/b] %s[/color]" % [UiTheme.hex(UiTheme.GOLD_BRIGHT), tip(kind)]
	_tip.visible = true
	_card.reset_size()


func _mark(ids: Array[StringName]) -> void:
	_marked = ids
	_marks.queue_redraw()


func _empty() -> Array[StringName]:
	var out: Array[StringName] = []
	return out


## The marks pulse by fading the whole overlay, so they redraw only when the
## set of cards changes.
func _process(delta: float) -> void:
	if _marked.is_empty():
		return
	_time += delta
	_marks.modulate.a = 0.6 + 0.4 * sin(_time * TAU / MARK_PERIOD)


## A green glowing frame round each card the counsel names (gold is taken by
## the chosen card, blue by Epics ready to fuse).
func _draw_marks() -> void:
	for id in _marked:
		var card: Control = _cards.get(id)
		if card == null or not card.is_visible_in_tree():
			continue
		var r := card.get_global_rect()
		r.position -= _marks.get_global_rect().position
		# Rings fading outward make the glow without covering the card.
		for i in 4:
			var a := 1.0 - i * 0.28
			_marks.draw_rect(r.grow(2.0 + i * 2.5), Color(MARK_COLOR, a), false, 2.5, true)
