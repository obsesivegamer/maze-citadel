class_name SimTower
extends RefCounted
## A built tower. Stats come from TowerDefs at the tower's current level.

var id: StringName
var tile := Vector2i.ZERO
var pos := Vector2.ZERO
var level := 1
var invested := 0
var cooldown := 0.0
var shots := 0
## Best Bard aura covering this tower: bonus damage and attack speed.
var aura := 0.0
var haste := 0.0
var aim := Vector2(0, 1)
var kills := 0
var damage_dealt := 0.0
var clouds := 0


func stat(key: String, fallback: Variant = 0) -> Variant:
	return TowerDefs.stat(id, key, level, fallback)


func family() -> StringName:
	return TowerDefs.TOWERS[id].family


func is_epic() -> bool:
	return id in TowerDefs.EPICS


func max_level() -> int:
	return 1 if is_epic() else TowerDefs.MAX_LEVEL
