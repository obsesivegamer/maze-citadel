class_name ElementStrip
extends HBoxContainer
## The element levels on the top bar under the eletd rules (GDD §5.0): the six
## element glyphs, each over three pips filled up to its level, with the pip a
## walking Guardian will grant outlined and pulsing. Hovering a glyph names
## its towers and counters. A Pick chip (E) shows while picks wait and
## pulses gently. refresh() runs every frame but redraws only on a change;
## only a pip waiting on a Guardian animates.

signal pick_pressed

const GLYPH_PX := 20.0
const PIP := 2.6
const PIP_GAP := 7.0
const BADGE := Vector2(24, 30)
const PULSE_PERIOD := 0.9
const CHIP_WIDTH := 96.0
const DIM := Color(1, 1, 1, 0.38)

var _game: Game
var _badges := {}
var _chip: Button
var _chip_tween: Tween
var _shown := []
var _time := 0.0


func _init(game: Game) -> void:
	_game = game
	add_theme_constant_override("separation", 3)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in Damage.WHEEL:
		var b := Control.new()
		b.custom_minimum_size = BADGE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.draw.connect(_draw_badge.bind(b, e))
		add_child(b)
		_badges[e] = b
	_chip = UiKit.text_button(game, "", &"Segment")
	_chip.custom_minimum_size = Vector2(CHIP_WIDTH, HudTopBar.BUTTON_PX)
	_chip.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT)
	_chip.tooltip_text = "Spend an element pick (%s)" % ElementPicks.KEY
	_chip.pressed.connect(pick_pressed.emit)
	UiKit.key_badge(_chip, ElementPicks.KEY)
	_chip.visible = false
	add_child(_chip)


func refresh() -> void:
	var el := _game.sim.elements
	var key := [el.pending_picks()]
	for e in Damage.WHEEL:
		key.append_array([el.level(e), el.pending_level(e)])
	if key != _shown:
		_shown = key
		for e in Damage.WHEEL:
			_badges[e].tooltip_text = ElementPicks.element_tip(_game.sim, e)
			_badges[e].queue_redraw()
		_set_chip(el.pending_picks())
	for e in Damage.WHEEL:
		if el.pending_level(e) > 0:
			_badges[e].queue_redraw()


func _process(delta: float) -> void:
	_time += delta


func _set_chip(picks: int) -> void:
	_chip.text = ElementPicks.chip_text(picks)
	if _chip.visible == (picks > 0):
		return
	_chip.visible = picks > 0
	if _chip_tween != null:
		_chip_tween.kill()
		_chip_tween = null
	_chip.modulate.a = 1.0
	if _chip.visible and is_inside_tree():
		_chip_tween = create_tween().set_loops()
		_chip_tween.tween_property(_chip, "modulate:a", 0.6, PULSE_PERIOD)
		_chip_tween.tween_property(_chip, "modulate:a", 1.0, PULSE_PERIOD)


func _draw_badge(b: Control, e: StringName) -> void:
	var el := _game.sim.elements
	var level := el.level(e)
	var pending := el.pending_level(e)
	var glyph := Rect2(Vector2((b.size.x - GLYPH_PX) / 2.0, 1.0), Vector2(GLYPH_PX, GLYPH_PX))
	UiGlyphs.draw(b, UiGlyphs.element(e), glyph, Color.WHITE if level > 0 else DIM)
	var color := UiTheme.element_color(e)
	var y := glyph.end.y + PIP + 3.0
	for i in EletdRules.MAX_ELEMENT_LEVEL:
		var c := Vector2(b.size.x / 2.0 + (i - 1) * PIP_GAP, y)
		if i < level:
			UiGlyphs.diamond(b, c, PIP, color)
		elif i == pending - 1:
			var a := 0.55 + 0.45 * sin(_time * TAU / PULSE_PERIOD)
			var s := PIP + 1.2
			var pts := PackedVector2Array(
				[c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]
			)
			pts.append(pts[0])
			b.draw_polyline(pts, Color(color, a), 1.5, true)
		else:
			UiGlyphs.diamond(b, c, PIP * 0.75, Color(UiTheme.GOLD_DIM, 0.7))
