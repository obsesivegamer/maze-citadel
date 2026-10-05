extends "res://tests/test_case.gd"
## The rules a new player trips over under eletd, said where they bite:
## flying and composite waves. Nothing of it shows under classic. Expected
## wording is written out, not read back.

const FLYING := (
	"ignores your maze and flies straight from portal to gate;"
	+ " only wing-icon towers beside the flight line hit it"
)


func test_every_flying_wave_says_where_flyers_go() -> void:
	var flyers: Array[int] = []
	for w in range(1, WaveDefs.count() + 1):
		if TowerInfo.flying(w, &"eletd"):
			flyers.append(w)
		check(not TowerInfo.flying(w, &"classic"), "classic wave %d keeps its banner" % w)
	check_eq(flyers, [5, 11, 13, 15, 17, 19, 20, 26, 31, 34, 36, 39], "every Harpy wave")
	check_eq(TowerInfo.flying_text(), FLYING)
	var chip := WaveIcons.new()
	chip.show_wave(5, &"", &"eletd")
	check(_labels(chip).has("Flying"), "the wave chip tags wave 5 Flying")
	chip.show_wave(31, &"", &"eletd")
	check(_labels(chip).has("Flying"), "and wave 31, not only the first")
	chip.show_wave(4, &"", &"eletd")
	check(not _labels(chip).has("Flying"), "no tag without flyers")
	chip.show_wave(5, &"", &"classic")
	check(not _labels(chip).has("Flying"), "classic's chip is as before")
	chip.free()
	var note := Counsel.creep_note(&"harpy")
	check(note.contains("fly straight from the portal to the gate"), note)


func test_composite_waves_say_elements_dont_matter() -> void:
	var waves: Array[int] = []
	for w in range(1, WaveDefs.count() + 1):
		if TowerInfo.composite_wave(w, &"eletd"):
			waves.append(w)
		check(not TowerInfo.composite_wave(w, &"classic"), "classic wave %d" % w)
	check_eq(waves, [14, 27, 34])
	check_eq(
		TowerInfo.composite_text(),
		(
			"elements don't matter this wave: Archers and Cannons hit at full strength,"
			+ " element towers 90%"
		)
	)


func _labels(node: Node) -> Array[String]:
	var out: Array[String] = []
	for c in node.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	return out
