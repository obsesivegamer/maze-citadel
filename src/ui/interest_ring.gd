class_name InterestRing
extends Control
## Countdown ring to the next interest payout (GDD §4): a gold arc that fills
## over the 15 s period around a coin. Redraws only when the arc visibly moves.

const STEPS := 90.0
const TRACK_WIDTH := 3.5
const ARC_WIDTH := 3.0

var _progress := -1.0


func _init(px := 28.0) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `p` is the elapsed fraction of the period, 0..1.
func set_progress(p: float) -> void:
	var q := roundf(clampf(p, 0.0, 1.0) * STEPS) / STEPS
	if q != _progress:
		_progress = q
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var rad := minf(size.x, size.y) / 2.0 - 2.0
	draw_arc(c, rad, 0.0, TAU, 48, Color(0, 0, 0, 0.55), TRACK_WIDTH, true)
	if _progress > 0.0:
		var end := -PI / 2.0 + TAU * _progress
		draw_arc(c, rad, -PI / 2.0, end, 48, UiTheme.GOLD_BRIGHT, ARC_WIDTH, true)
	var coin := rad * 0.62
	UiGlyphs.coin(self, Rect2(c - Vector2(coin, coin), Vector2(coin, coin) * 2.0), Color.WHITE)
