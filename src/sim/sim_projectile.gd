class_name SimProjectile
extends RefCounted
## In-flight attack. homing: follows a creep · shell: flies to a ground point
## and splashes · bolt: travels a straight line, piercing several creeps.

var kind: StringName
var tower: SimTower
var level := 1
var aura := 0.0
var shot := 0
var start := Vector2.ZERO
var pos := Vector2.ZERO
var target_id := 0
var target_point := Vector2.ZERO
var direction := Vector2.ZERO
var speed := 0.0
var flight_time := 0.0
var time_left := 0.0
var travelled := 0.0
var max_distance := 0.0
var hit_ids: Array[int] = []
var alive := true
