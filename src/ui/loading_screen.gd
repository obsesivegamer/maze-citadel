class_name LoadingScreen
extends CanvasLayer
## Shown while the citadel is built and every shader is compiled (behind it,
## the warm-up stage rehearses a battle). Keeps the window responsive with a
## progress bar instead of macOS's spinning cursor, then fades out.

const LAYER := 128
const BAR_SIZE := Vector2(520, 10)
const TIP_SECONDS := 4.5
const FADE := 0.6
const TIPS := [
	"The path can never be sealed: there is always a way from the portal to the gate.",
	(
		"Light → Dark → Aqua → Flame → Verdant → Stone → Light:"
		+ " each element deals double damage to the next."
	),
	"Cannons and other siege towers can't hit Harpies. Keep some archers or frost spires.",
	"A leaked creep loops back to the portal and costs a life on every pass.",
	"Poison ignores armor and halves a Priestess's healing.",
	"Two level-3 Elven or Horde towers fuse into an Epic: select one and press G.",
	"Shift-click keeps placing the same tower; right-click cancels or sells.",
]
## Shown as well under the Element TD rules, which play differently.
const ELETD_TIPS := [
	"A tower reaches only the eight tiles around it: build the maze along the road.",
	"Most towers need their element. Press E to spend an element pick.",
	"Every element pick after the first summons a Guardian. Kill it to learn the element.",
]

var _root := ColorRect.new()
var _title := Label.new()
var _status := Label.new()
var _tip := Label.new()
var _bar := Control.new()
var _progress := 0.0
var _shown := 0.0
var _tips: Array = TIPS
var _tip_index := 0
var _tip_timer := TIP_SECONDS


func _init(rules: StringName = &"classic") -> void:
	if rules == &"eletd":
		_tips = TIPS + ELETD_TIPS
	layer = LAYER
	_root.color = Color(0.045, 0.04, 0.035)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	add_child(_root)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_root.add_child(box)
	_title.text = "MAZE CITADEL"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", UiTheme.heading())
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT)
	box.add_child(_title)
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	box.add_child(_status)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size.x = 640
	_tip.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	box.add_child(_tip)
	_tip_index = randi() % _tips.size()
	_tip.text = _tips[_tip_index]


func set_progress(fraction: float, status: String) -> void:
	_progress = clampf(fraction, 0.0, 1.0)
	_status.text = status


## Fades out and frees itself.
func finish() -> void:
	_progress = 1.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE)
	tween.tween_callback(queue_free)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_shown = move_toward(_shown, _progress, delta * 1.5)
	_bar.queue_redraw()
	_tip_timer -= delta
	if _tip_timer <= 0.0:
		_tip_timer = TIP_SECONDS
		_tip_index = (_tip_index + 1) % _tips.size()
		_tip.text = _tips[_tip_index]


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(r, Color(0, 0, 0, 0.6))
	_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * _shown, r.size.y)), UiTheme.GOLD)
	_bar.draw_rect(r, UiTheme.GOLD_DIM, false, 1.5)
