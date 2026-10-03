extends "res://tests/test_case.gd"


func test_transparent_icon_button_box_draws_nothing() -> void:
	var flat := UiTheme.theme().get_stylebox("normal", &"IconButton") as StyleBoxFlat
	check(not flat.draw_center, "no centre")
	check_eq(flat.bg_color.a, 0.0, "was transparent anyway")
	check(flat.border_width_left == 0 and flat.shadow_size == 0, "nothing else to draw")
