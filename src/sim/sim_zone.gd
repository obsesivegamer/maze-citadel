class_name SimZone
extends RefCounted
## Lingering ground effect: a burning crater or a shadow cloud.

var kind: StringName
var tower: SimTower
var pos := Vector2.ZERO
var radius := 2.0
var dps := 0.0
var time_left := 0.0
var aura := 0.0
