extends "res://tests/test_case.gd"
## The loading screen's tips are shown under both rule sets, so each must be
## true under both.


## Every family has an Epic, under either rule set.
func test_the_fusion_tip_names_every_family_that_fuses() -> void:
	var fusing := LoadingScreen.TIPS.filter(func(t: String) -> bool: return "fuse" in t)
	check_eq(fusing.size(), 1, "one fusion tip")
	for family: StringName in TowerDefs.FUSIONS:
		check(TowerInfo.FAMILY_NAMES[family] in fusing[0], "names %s" % family)
