class_name UiKit
extends RefCounted
## Widget factories so every HUD label, button and panel looks and sounds the
## same. Buttons play the UI hover/click sounds through game.audio.

const KEY_BADGE_SIZE := 10


static func label(text := "", variation: StringName = &"", font_size := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func rich(font_size := UiTheme.SIZE_SMALL, width := 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	if width > 0.0:
		r.custom_minimum_size.x = width
	return r


static func hbox(separation := 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	b.alignment = BoxContainer.ALIGNMENT_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func vbox(separation := 4) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## A stone panel; `trim` adds the inner hairline and corner studs.
static func panel(variation: StringName = &"", trim := true) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	if trim:
		UiTheme.add_trim(p)
	return p


## A thin vertical gold divider for rows of controls.
static func divider(height := 26.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(2, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(
		func() -> void:
			c.draw_line(Vector2(1, 2), Vector2(1, c.size.y - 2), Color(UiTheme.GOLD_DIM, 0.8), 1.0)
	)
	return c


static func text_button(game: Game, text: String, variation: StringName = &"") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	wire(game, b)
	return b


## A square button showing one glyph; `toggle` makes it stay pressed.
static func icon_button(
	game: Game, glyph: StringName, tip: String, px := 30.0, toggle := false
) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"IconButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.toggle_mode = toggle
	b.tooltip_text = tip
	var icon := UiIcon.new(glyph, px - 10.0)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 5
	icon.offset_top = 5
	icon.offset_right = -5
	icon.offset_bottom = -5
	icon.name = "Icon"
	b.add_child(icon)
	wire(game, b)
	return b


static func button_icon(b: Button) -> UiIcon:
	return b.get_node("Icon") as UiIcon


## Hover and click sounds (GDD §13 UI bus).
static func wire(game: Game, b: BaseButton) -> void:
	b.mouse_entered.connect(
		func() -> void:
			if not b.disabled and game.audio != null:
				game.audio.play_ui(&"ui_hover")
	)
	b.pressed.connect(
		func() -> void:
			if game.audio != null:
				game.audio.play_ui(&"ui_click")
	)


## A tiny hotkey letter drawn in a control's top-right corner.
static func key_badge(c: Control, key: String) -> void:
	c.draw.connect(
		func() -> void:
			c.draw_string(
				UiTheme.bold(),
				Vector2(c.size.x - 13.0, 11.0),
				key,
				HORIZONTAL_ALIGNMENT_CENTER,
				10.0,
				KEY_BADGE_SIZE,
				Color(UiTheme.GOLD, 0.85)
			)
	)


## Brief pop and colour flash on a counter (lives lost, interest paid).
static func pulse(c: Control, color: Color, scale := 1.25) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * scale
	c.modulate = color
	var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.45)
	tw.tween_property(c, "modulate", Color.WHITE, 0.7)
