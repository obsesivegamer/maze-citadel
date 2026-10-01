class_name SimCreep
extends RefCounted
## One creep's simulation state. Presentation interpolates prev_pos → pos.

var id := 0
var type: StringName
var wave := 1
var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var heading := Vector2(0, 1)
var hp := 1.0
var max_hp := 1.0
var speed := 3.0
var armor := 0.0
var armor_class: StringName
var element: StringName
var flying := false
var boss := false
var bounty := 0
## Set on the first leak: the creep loops back to the portal and pays nothing.
var leaked := false
var alive := true
