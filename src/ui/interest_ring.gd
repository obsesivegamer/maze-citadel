class_name InterestRing
extends Control
## Countdown ring to the next interest payout (GDD §4): a gold arc that fills
## over the 15 s period around a coin. Redraws only when the arc visibly moves;
## the track and coin are built once and go out as one draw call each.
## Locked (eletd, after a leak), the arc dims and a lock replaces the coin.

const STEPS := 90.0
const TRACK_WIDTH := 3.5
const ARC_WIDTH := 3.0

var locked := false:
	set(value):
		if value != locked:
			locked = value
			queue_redraw()

var _progress := -1.0
var _track := UiMesh.new()
var _coin := UiMesh.new()
var _lock := UiMesh.new()
var _built_for := Vector2.ZERO


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
	if _built_for != size:
		_built_for = size
		_track = UiMesh.new()
		_track.draw_arc(c, rad, 0.0, TAU, 48, Color(0, 0, 0, 0.55), TRACK_WIDTH, true)
		_coin = UiMesh.new()
		var coin := rad * 0.62
		UiGlyphs.coin(_coin, Rect2(c - Vector2(coin, coin), Vector2(coin, coin) * 2.0), Color.WHITE)
		_lock = UiMesh.new()
		var lock := rad * 0.7
		UiGlyphs.draw(_lock, &"lock", Rect2(c - Vector2(lock, lock), Vector2(lock, lock) * 2.0))
	_track.submit(self)
	if _progress > 0.0:
		var end := -PI / 2.0 + TAU * _progress
		var arc := UiTheme.GOLD_DIM if locked else UiTheme.GOLD_BRIGHT
		draw_arc(c, rad, -PI / 2.0, end, 48, arc, ARC_WIDTH, true)
	(_lock if locked else _coin).submit(self)
