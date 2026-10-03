extends "res://tests/test_case.gd"


func _look(lite: bool) -> Dictionary:
	var was := UiTheme.lite
	UiTheme.lite = lite
	var t := Theme.new()
	UiTheme._labels(t)
	var panel := Control.new()
	UiTheme.add_trim(panel)
	var out := {
		"label_shadow": t.get_color("font_shadow_color", "Label"),
		"rich_shadow": t.get_color("font_shadow_color", "RichTextLabel"),
		"panel_shadow": UiTheme.panel_box().shadow_size,
		"trim": panel.draw.get_connections().size(),
	}
	panel.free()
	UiTheme.lite = was
	return out


func test_shipped_look_keeps_shadows_and_trim() -> void:
	check(not UiTheme.lite, "lite is off without --pf-hud-lite")
	var look := _look(false)
	check_eq(look.label_shadow, UiTheme.SHADOW, "label shadow")
	check_eq(look.rich_shadow, UiTheme.SHADOW, "rich text shadow")
	check_eq(look.panel_shadow, UiTheme.SHADOW_SIZE, "panel shadow")
	check_eq(look.trim, 1, "trim drawn")


func test_lite_drops_shadows_and_trim() -> void:
	var look := _look(true)
	check_eq(look.label_shadow.a, 0.0, "label shadow")
	check_eq(look.rich_shadow.a, 0.0, "rich text shadow")
	check_eq(look.panel_shadow, 0, "panel shadow")
	check_eq(look.trim, 0, "no trim")


func test_transparent_icon_button_box_draws_nothing() -> void:
	var flat := UiTheme.theme().get_stylebox("normal", &"IconButton") as StyleBoxFlat
	check(not flat.draw_center, "no centre")
	check_eq(flat.bg_color.a, 0.0, "was transparent anyway")
	check(flat.border_width_left == 0 and flat.shadow_size == 0, "nothing else to draw")
