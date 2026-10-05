class_name SimZone
extends RefCounted
## Lingering ground effect: a burning crater or a shadow cloud.

var kind: StringName
var tower: SimTower
## The tower's id when it made the zone, which burns as that tower did even
## after a fusion; dps already holds its damage at its level then.
var id: StringName
var pos := Vector2.ZERO
var radius := 2.0
var dps := 0.0
var time_left := 0.0
var aura := 0.0


## A crater or cloud (`kind`) from tower `t` as a tower of `id` at `level`:
## its radius, dps and time are that tower's `<kind>_radius`, `_dps` and
## `_time`, the dps scaled by `power` (SimElements.power).
static func of(kind: StringName, t: SimTower, id: StringName, level: int, power: float) -> SimZone:
	var z := SimZone.new()
	z.kind = kind
	z.tower = t
	z.id = id
	z.radius = TowerDefs.stat(id, kind + "_radius", level)
	z.dps = TowerDefs.stat(id, kind + "_dps", level) * power
	z.time_left = TowerDefs.stat(id, kind + "_time", level)
	return z
