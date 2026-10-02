extends "res://tests/test_case.gd"
## No-placeholder audit (PLAN M7): every creep and every tower level the sim
## can produce has its own model, and every animation a spec names exists.
## CreepModels.spec() quietly falls back to the Grunt, so a missing entry
## would otherwise ship as an orc.


func test_every_creep_type_has_its_own_model_and_animations() -> void:
	for type in CreepDefs.CREEPS:
		check(CreepModels.SPECS.has(type), "%s has a creep spec" % type)
		var s := CreepModels.spec(type)
		var rig := CreepModels.build(type)
		check(rig.root != null and not rig.meshes.is_empty(), "%s builds meshes" % type)
		check(rig.ap != null, "%s has an AnimationPlayer" % type)
		if rig.ap != null:
			for key in ["loop", "death", "hit"]:
				if s.has(key):
					var anim: StringName = s[key]
					check(_has_anim(rig.ap, anim), "%s: %s animation '%s'" % [type, key, anim])
		if rig.root != null:
			rig.root.free()


func test_every_tower_level_builds_a_model() -> void:
	for id in TowerDefs.BUILD_ORDER:
		for level in range(1, TowerDefs.MAX_LEVEL + 1):
			_check_tower(id, level)
	for id in TowerDefs.EPICS:
		_check_tower(id, 1)


func _check_tower(id: StringName, level: int) -> void:
	var node := TowerVisuals.build(id, level)
	check(node != null, "%s L%d builds" % [id, level])
	if node == null:
		return
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	meshes.append_array(node.find_children("*", "MultiMeshInstance3D", true, false))
	check(not meshes.is_empty(), "%s L%d has geometry" % [id, level])
	node.free()


static func _has_anim(ap: AnimationPlayer, anim: StringName) -> bool:
	if ap.has_animation(anim):
		return true
	for lib in ap.get_animation_library_list():
		if ap.get_animation_library(lib).has_animation(anim):
			return true
	return false
