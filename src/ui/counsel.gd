class_name Counsel
extends RefCounted
## Counter advice for one wave (GDD §6): which element and which attack types
## hit it hardest, what its creeps bring, and which towers to build. Feeds the
## tutorial's counsel card, the Field Guide's next-wave panel and the "next
## wave" line in tower tooltips. Lines are BBCode for RichTextLabel; free of
## nodes so the wording is unit-tested (tests/unit/test_counsel.gd).

## The tutorial walks the player through waves 1 to 10: one new mechanic per
## wave, then the first boss (GDD §9).
const TUTORIAL_WAVES := 10
## One short lesson title per tutorial wave.
const LESSONS: Array[String] = [
	"Read the wave",
	"Elements stack with armor",
	"Armor and Siege",
	"Healers and Poison",
	"Air",
	"Creeps that rise again",
	"Heavy armor",
	"Mixed speeds",
	"Armor and healing",
	"The first boss",
]
## A tower is named as a pick only when it beats full damage on the wave.
const PICK_MIN := 1.0
const CLASS_LABELS := {
	&"light": "Light armor", &"armored": "Armored", &"air": "Air", &"boss": "Boss armor"
}
## What a creep type changes about the counter, said when it first appears.
const CREEP_NOTES := {
	&"wolf_rider": "Wolf Riders are fast and frail: a long maze gives your towers more shots.",
	&"footman": "Shield Footmen carry 4 armor. Siege smashes it; Pierce glances off.",
	&"priestess": "Priestesses heal the creeps around them. Poison halves that healing.",
	&"harpy": "Harpies fly straight over the maze. Only towers with the wing icon hit them.",
	&"ghoul": "Ghouls rise once at a third of their HP, so each one has to fall twice.",
	&"steam_tank":
	(
		"Steam Tanks carry 10 armor and turn IMMUNE for 1.5 s every 6 s."
		+ " Poison ignores armor and the Runesmith shreds it."
	),
	&"ogre":
	(
		"Bosses cost 2 lives if they leak. The Ogre gives nearby escorts +3 armor"
		+ " and a little speed."
	),
	&"dreadlord": "The Dreadlord summons three Felhounds every 10 s. Bosses cost 2 lives.",
}


## The element that deals double damage to `element`: the one pointing at it.
static func counter_element(element: StringName) -> StringName:
	return TowerInfo.weak_against(element)


## The element that deals half damage to `element`: the one it points at.
static func resisted_element(element: StringName) -> StringName:
	return TowerInfo.strong_against(element)


## Counter multiplier of tower `id` on one creep: attack type vs armor class
## times the element wheel, before armor points and auras. 0 when it can't hit.
static func multiplier(
	id: StringName, armor_class: StringName, element: StringName, flying := false
) -> float:
	var def: Dictionary = TowerDefs.TOWERS[id]
	if not def.has("attack") or (flying and not def.get("air", false)):
		return 0.0
	return Damage.class_mult(def.attack, armor_class) * Damage.element_mult(def.element, element)


## One entry per creep type and element, in spawn order: type, element,
## armor_class, flying, count and share (the group's part of the wave's HP).
static func groups(wave: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var total := 0.0
	for entry in WaveDefs.spawn_list(wave):
		var g := {}
		for o in out:
			if o.type == entry[0] and o.element == entry[1]:
				g = o
		if g.is_empty():
			var def: Dictionary = CreepDefs.CREEPS[entry[0]]
			g = {
				"type": entry[0],
				"element": entry[1],
				"armor_class": def["class"],
				"flying": def.get("flying", false),
				"count": 0,
				"hp": 0.0,
			}
			out.append(g)
		var hp := CreepDefs.max_hp(entry[0], wave)
		g.count += 1
		g.hp += hp
		total += hp
	for g in out:
		g["share"] = g.hp / total
	return out


## Tower `id`'s multiplier on wave `wave`, averaged over the wave's HP.
static func wave_multiplier(id: StringName, wave: int) -> float:
	var m := 0.0
	for g in groups(wave):
		m += g.share * multiplier(id, g.armor_class, g.element, g.flying)
	return m


## Buildable towers to answer `wave` with, as {id, mult, vs}: the hardest
## hitter on each of its groups, biggest share of HP first, then runners-up on
## the biggest group while they beat full damage. `mult` is the pick's
## multiplier on its group and `vs` that group's creep (see _pick). Cheaper
## first on a tie.
static func picks(wave: int, count := 2) -> Array[Dictionary]:
	var by_share := groups(wave)
	by_share.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.share > b.share)
	var out: Array[Dictionary] = []
	var taken: Array[StringName] = []
	for g in by_share:
		var id: StringName = _ranked(g)[0]
		if out.size() < count and not id in taken:
			taken.append(id)
			out.append(_pick(id, g, by_share))
	for id in _ranked(by_share[0]):
		var m := multiplier(id, by_share[0].armor_class, by_share[0].element, by_share[0].flying)
		if out.size() < count and not id in taken and m > PICK_MIN:
			taken.append(id)
			out.append(_pick(id, by_share[0], by_share))
	return out


static func best_towers(wave: int, count := 2) -> Array[StringName]:
	var out: Array[StringName] = []
	for p in picks(wave, count):
		out.append(p.id)
	return out


static func _pick(id: StringName, g: Dictionary, all: Array[Dictionary]) -> Dictionary:
	var m := multiplier(id, g.armor_class, g.element, g.flying)
	# Named when the tower fares differently on the rest of the wave, or when
	# it is the answer to the fliers in a mixed wave.
	var named := false
	for o in all:
		named = named or not is_equal_approx(m, multiplier(id, o.armor_class, o.element, o.flying))
		named = named or (g.flying and not o.flying)
	var vs: String = CreepDefs.CREEPS[g.type].name if named else ""
	return {"id": id, "mult": m, "vs": vs}


## Attacking buildable towers by multiplier on group `g`, highest first and
## cheaper first on a tie.
static func _ranked(g: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var by_id := {}
	for id in TowerDefs.BUILD_ORDER:
		if TowerDefs.TOWERS[id].has("attack"):
			out.append(id)
			by_id[id] = multiplier(id, g.armor_class, g.element, g.flying)
	out.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			if not is_equal_approx(by_id[a], by_id[b]):
				return by_id[a] > by_id[b]
			return TowerDefs.build_cost(a) < TowerDefs.build_cost(b)
	)
	return out


## One line per element in the wave, e.g. "Verdant creeps: Flame towers deal
## 200%, Stone towers only 50%."
static func element_lines(wave: int) -> Array[String]:
	var out: Array[String] = []
	for e in WaveDefs.elements(wave):
		(
			out
			. append(
				(
					"%s creeps: %s towers deal %s, %s towers only %s."
					% [
						_element(e),
						_element(counter_element(e)),
						_pct(Damage.STRONG),
						_element(resisted_element(e)),
						_pct(Damage.WEAK),
					]
				)
			)
		)
	return out


## One line per armor class in the wave, from the attack table, e.g.
## "Armored: Siege deals 175%, Magic 125%. Pierce only 50%."
static func armor_lines(wave: int) -> Array[String]:
	var out: Array[String] = []
	for c in TowerInfo.wave_classes(wave):
		out.append(armor_line(c))
	return out


static func armor_line(armor_class: StringName) -> String:
	var bonus := PackedStringArray()
	for a in attacks_by_mult(armor_class, true):
		bonus.append("%s %s" % [TowerInfo.ATTACK_NAMES[a], _pct(Damage.class_mult(a, armor_class))])
	var poor := PackedStringArray()
	for a in attacks_by_mult(armor_class, false):
		poor.append("%s %s" % [TowerInfo.ATTACK_NAMES[a], _pct(Damage.class_mult(a, armor_class))])
	var blind := PackedStringArray()
	for a in Damage.ATTACK_VS_CLASS:
		if Damage.class_mult(a, armor_class) == 0.0:
			blind.append(TowerInfo.ATTACK_NAMES[a])
	if armor_class == &"air":
		blind.append("ground-only towers")
	var parts := PackedStringArray()
	if not bonus.is_empty():
		parts.append(_join_list(bonus, " deals "))
	if not poor.is_empty():
		parts.append(_join_list(poor, " only "))
	if not blind.is_empty():
		parts.append(" and ".join(blind) + " can't hit it")
	if bonus.is_empty():
		parts.append("everything else deals 100%")
	return "[b]%s[/b]: %s." % [CLASS_LABELS[armor_class], ". ".join(_capitalize(parts))]


## Attack types that deal more (or, with `better` false, less but some)
## damage to `armor_class` than full, strongest effect first.
static func attacks_by_mult(armor_class: StringName, better: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	for a: StringName in Damage.ATTACK_VS_CLASS:
		var m := Damage.class_mult(a, armor_class)
		if (better and m > 1.0) or (not better and m < 1.0 and m > 0.0):
			out.append(a)
	out.sort_custom(
		func(x: StringName, y: StringName) -> bool:
			var mx := Damage.class_mult(x, armor_class)
			var my := Damage.class_mult(y, armor_class)
			return mx > my if better else mx < my
	)
	return out


## Notes for the wave's creep types. `first_only` keeps only the types making
## their first appearance on this wave (the tutorial's pacing).
static func creep_notes(wave: int, first_only := false) -> Array[String]:
	var out: Array[String] = []
	for g in TowerInfo.wave_groups(wave):
		var type: StringName = g[0]
		if CREEP_NOTES.has(type) and (not first_only or first_wave_of(type) == wave):
			out.append(CREEP_NOTES[type])
	return out


## The first wave a creep type spawns on (0 if never, e.g. summons).
static func first_wave_of(type: StringName) -> int:
	for w in range(1, WaveDefs.count() + 1):
		for entry in WaveDefs.spawn_list(w):
			if entry[0] == type:
				return w
	return 0


static func lesson(wave: int) -> String:
	return LESSONS[wave - 1] if wave >= 1 and wave <= LESSONS.size() else ""


## How tower `id` fares against each group of `wave`, e.g. "350% vs Shield
## Footman" or "can't hit Harpy"; empty for towers that don't attack.
static func tower_vs_wave(id: StringName, wave: int) -> String:
	if not TowerDefs.TOWERS[id].has("attack"):
		return ""
	var parts := PackedStringArray()
	for g in groups(wave):
		var m := multiplier(id, g.armor_class, g.element, g.flying)
		var name: String = CreepDefs.CREEPS[g.type].name
		if g.element != WaveDefs.row(wave).element:
			name = "%s %s" % [TowerInfo.ELEMENT_NAMES[g.element], name]
		var text := ("can't hit %s" % name) if m == 0.0 else ("%s vs %s" % [_pct(m), name])
		parts.append(_tint(text, m))
	return TowerInfo.SEP.join(parts)


## The top bar's one-line counter for the next-wave chip tooltip, e.g.
## "Counter: Cannon Tower 350%, Demolisher 350%".
static func summary(wave: int) -> String:
	var parts := PackedStringArray()
	for p in picks(wave):
		var vs: String = (" vs " + p.vs) if p.vs != "" else ""
		parts.append("%s %s%s" % [TowerInfo.full_name(p.id), _pct(p.mult, false), vs])
	return "Counter: " + ", ".join(parts)


## "350%"; coloured green above 100% and red below unless `color` is false.
static func pct(m: float, color := true) -> String:
	return _pct(m, color)


## Drops BBCode tags, for plain-text tooltips and tests.
static func plain(text: String) -> String:
	var re := RegEx.create_from_string("\\[[^\\]]*\\]")
	return re.sub(text, "", true)


static func _pct(m: float, color := true) -> String:
	var text := "%d%%" % roundi(m * 100.0)
	return _tint(text, m) if color else text


static func _tint(text: String, m: float) -> String:
	if is_equal_approx(m, 1.0):
		return text
	return "[color=#%s]%s[/color]" % [UiTheme.hex(UiTheme.GOOD if m > 1.0 else UiTheme.BAD), text]


static func _element(e: StringName) -> String:
	return (
		"[color=#%s][b]%s[/b][/color]"
		% [UiTheme.hex(UiTheme.element_color(e)), TowerInfo.ELEMENT_NAMES[e]]
	)


## ["Siege 175%", "Magic 125%"] with " deals " → "Siege deals 175%, Magic 125%".
static func _join_list(items: PackedStringArray, verb: String) -> String:
	var first := items[0].split(" ", false, 1)
	var out := PackedStringArray([first[0] + verb + first[1]])
	for i in range(1, items.size()):
		out.append(items[i])
	return ", ".join(out)


static func _capitalize(parts: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for p in parts:
		out.append(p.substr(0, 1).to_upper() + p.substr(1))
	return out
