class_name TowerInfo
extends RefCounted
## Words and numbers for tower cards, tooltips, the plaque, wave chips and the
## end screen. Free of nodes so the wording is unit-tested
## (tests/unit/test_ui_text.gd).

const ELEMENT_NAMES := {
	&"light": "Light",
	&"dark": "Dark",
	&"aqua": "Aqua",
	&"flame": "Flame",
	&"verdant": "Verdant",
	&"stone": "Stone",
}
const CLASS_NAMES := {&"light": "Light", &"armored": "Armored", &"air": "Air", &"boss": "Boss"}
const ATTACK_NAMES := {
	&"pierce": "Pierce", &"siege": "Siege", &"magic": "Magic", &"poison": "Poison", &"rune": "Rune"
}
const FAMILY_NAMES := {
	&"alliance": "Alliance",
	&"horde": "Horde",
	&"elven": "Elven",
	&"forsaken": "Forsaken",
	&"support": "Support",
}
## One-line card names; tooltips and the plaque use the full name.
const SHORT_NAMES := {
	&"archer": "Archer",
	&"cannon": "Cannon",
	&"frost": "Frost Spire",
	&"plague": "Plague",
	&"bard": "Bard",
	&"runesmith": "Runesmith",
	&"ballista": "Ballista",
	&"demolisher": "Demolisher",
	&"roots": "Roots",
	&"shadow": "Obelisk",
	&"frost_wyrm": "Frost Wyrm",
	&"doom_cannon": "Doom Cannon",
	&"sunfire_ballista": "Sunfire",
	&"plague_necropolis": "Necropolis",
}
const BLURBS := {
	&"archer": "Cheap maze filler. Level 3 fires two arrows.",
	&"cannon": "Arcing shells that splash every ground creep near the blast.",
	&"frost": "Slows its target. L2 slows in a splash; L3 adds a frost ring every 3rd shot.",
	&"plague": "Poison stacks up to 5, ignores armor and halves healing.",
	&"bard": "Aura: towers in range deal more damage. The strongest aura wins.",
	&"runesmith": "Each hit shreds 2 armor (up to 10) for 6 s.",
	&"ballista": "Heavy bolts pierce several creeps in a line.",
	&"demolisher": "Huge splash and a burning crater. Can't hit closer than 4 m.",
	&"roots": "A nova around the tower slows and briefly roots ground creeps.",
	&"shadow": "Drops poison clouds that ignore armor; up to 3 at once.",
	&"frost_wyrm": "Breath cone slows 50%; every 5th breath freezes for 1 s.",
	&"doom_cannon": "Massive splash and a molten crater.",
	&"sunfire_ballista": "A 40 m lance that hits every creep in its line.",
	&"plague_necropolis":
	"Plagues creeps that aren't infected yet. Infected creeps spread it when they fall.",
}
## Tooltip/plaque stat rows: [key, label, short label, format].
const STAT_ROWS := [
	["damage", "Damage", "Dmg", "num"],
	["poison_dps", "Poison", "Poison", "dps"],
	["cloud_dps", "Cloud", "Cloud", "dps"],
	["crater_dps", "Crater", "Crater", "dps"],
	["cooldown", "Attack every", "Rate", "s"],
	["range", "Range", "Range", "m"],
	["splash", "Splash", "Splash", "m"],
	["multishot", "Arrows", "Arrows", "x"],
	["pierce", "Pierces", "Pierce", "x"],
	["lance_length", "Lance length", "Lance", "m"],
	["contagion_radius", "Spreads within", "Spread", "m"],
	["slow", "Slow", "Slow", "pct"],
	["root", "Root", "Root", "s"],
	["shred", "Armor shred", "Shred", "num"],
	["aura_damage", "Aura damage", "Aura", "pct+"],
	["aura_haste", "Aura speed", "Haste", "pct+"],
]
const SEP := " · "

## True under rules where towers reach only the tiles around them
## (GameSim.adjacent_reach): attackers then show a reach, not a range in metres.
static var adjacent_reach := false


static func full_name(id: StringName) -> String:
	return TowerDefs.TOWERS[id].name


static func short_name(id: StringName) -> String:
	return SHORT_NAMES.get(id, full_name(id))


static func blurb(id: StringName) -> String:
	var text: String = BLURBS.get(id, "")
	if not adjacent_reach:
		return text
	return text.replace(" Can't hit closer than 4 m.", "").replace(" Level 3 fires two arrows.", "")


## A stat as these rules play it: under eletd an Archer fires one arrow.
static func _stat(id: StringName, key: String, level: int) -> float:
	var v: float = TowerDefs.stat(id, key, level)
	if adjacent_reach and id == &"archer" and key == "multishot":
		return minf(v, EletdRules.ARCHER_MULTISHOT)
	return v


## Whether this tower's range stat is replaced by the adjacent-tiles reach.
static func _reach_only(id: StringName) -> bool:
	return adjacent_reach and TowerDefs.TOWERS[id].has("attack")


static func is_epic(id: StringName) -> bool:
	return id in TowerDefs.EPICS


## Gold to put this card's tower on the board (build cost or fuse cost).
static func card_cost(id: StringName) -> int:
	var def: Dictionary = TowerDefs.TOWERS[id]
	return def.get("fuse_cost", 0) if is_epic(id) else def.cost[0]


static func subtitle(id: StringName) -> String:
	var def: Dictionary = TowerDefs.TOWERS[id]
	var parts := PackedStringArray([FAMILY_NAMES[def.family]])
	if def.has("attack"):
		parts.append(ATTACK_NAMES[def.attack])
		parts.append(ELEMENT_NAMES[def.element])
	else:
		parts.append("Aura")
	return SEP.join(parts)


static func strong_against(element: StringName) -> StringName:
	var i := Damage.WHEEL.find(element)
	return Damage.WHEEL[(i + 1) % Damage.WHEEL.size()]


static func weak_against(element: StringName) -> StringName:
	var i := Damage.WHEEL.find(element)
	return Damage.WHEEL[(i + Damage.WHEEL.size() - 1) % Damage.WHEEL.size()]


## Armor classes an attack does more than (or less than) full damage to,
## strongest first.
static func classes_by_mult(attack: StringName, better: bool) -> Array[StringName]:
	var table: Dictionary = Damage.ATTACK_VS_CLASS[attack]
	var out: Array[StringName] = []
	for c in table:
		var m: float = table[c]
		if (better and m > 1.0) or (not better and m < 1.0 and m > 0.0):
			out.append(c)
	out.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return table[a] > table[b] if better else table[a] < table[b]
	)
	return out


## [kind, text] pairs. Kinds: strong, weak, bonus, poor, note.
static func counter_parts(id: StringName) -> Array:
	var def: Dictionary = TowerDefs.TOWERS[id]
	if not def.has("attack"):
		var r: float = TowerDefs.stat(id, "range", 1)
		return [[&"note", "Buffs towers within %s m" % fmt_num(r)], [&"note", "Doesn't attack"]]
	var out := []
	out.append([&"strong", "Strong vs " + ELEMENT_NAMES[strong_against(def.element)]])
	out.append([&"weak", "Weak vs " + ELEMENT_NAMES[weak_against(def.element)]])
	var bonus := _class_names(classes_by_mult(def.attack, true))
	if bonus != "":
		out.append([&"bonus", "Bonus vs " + bonus])
	var poor := _class_names(classes_by_mult(def.attack, false))
	if poor != "":
		out.append([&"poor", "Poor vs " + poor])
	if def.attack == &"poison":
		out.append([&"note", "Ignores armor"])
	if def.has("shred"):
		out.append([&"note", "Shreds armor"])
	out.append([&"note", "Hits air" if def.get("air", false) else "Ground only"])
	return out


## The headline counter line, e.g. "Strong vs Dark · Weak vs Stone · Bonus vs Air/Light".
static func counters(id: StringName) -> String:
	var parts := PackedStringArray()
	for p in counter_parts(id):
		if p[0] in [&"strong", &"weak", &"bonus"] or not TowerDefs.TOWERS[id].has("attack"):
			parts.append(p[1])
	return SEP.join(parts)


static func _class_names(classes: Array[StringName]) -> String:
	var names := PackedStringArray()
	for c in classes:
		names.append(CLASS_NAMES[c])
	return "/".join(names)


## Rows of [label, values] with one value per level (one for Epics); rows
## that are zero at every level are left out.
static func stat_rows(id: StringName) -> Array:
	var def: Dictionary = TowerDefs.TOWERS[id]
	var levels := 1 if is_epic(id) else TowerDefs.MAX_LEVEL
	var rows := []
	var costs := PackedStringArray()
	if is_epic(id):
		costs.append("Fuse +%d" % def.fuse_cost)
	else:
		for i in levels:
			costs.append(("%d" if i == 0 else "+%d") % def.cost[i])
	rows.append(["Cost", costs])
	for row in STAT_ROWS:
		if not def.has(row[0]):
			continue
		if row[0] == "range" and _reach_only(id):
			var tiles := PackedStringArray()
			tiles.resize(levels)
			tiles.fill("1 tile")
			rows.append(["Reach", tiles])
			continue
		var values := PackedStringArray()
		var any := false
		for level in range(1, levels + 1):
			var v := _stat(id, row[0], level)
			any = any or v != 0.0
			values.append(fmt_value(v, row[3]))
		if any:
			rows.append([row[1], values])
	return rows


## What the next level changes, e.g. "Dmg 9 → 15 · Range 9 → 9.5 m".
static func next_level_preview(id: StringName, level: int) -> String:
	if is_epic(id) or level >= TowerDefs.MAX_LEVEL:
		return "Max level"
	var parts := PackedStringArray()
	for row in STAT_ROWS:
		if row[0] == "range" and _reach_only(id):
			continue
		var a := _stat(id, row[0], level)
		var b := _stat(id, row[0], level + 1)
		if a != b:
			parts.append("%s %s → %s" % [row[2], fmt_value(a, row[3]), fmt_value(b, row[3])])
	return SEP.join(parts) if not parts.is_empty() else "Stronger effect"


static func fmt_value(v: float, fmt: String) -> String:
	if v == 0.0:
		return "—"
	match fmt:
		"dps":
			return fmt_num(v) + "/s"
		"s":
			return fmt_num(v) + " s"
		"m":
			return fmt_num(v) + " m"
		"x":
			return "×%d" % roundi(v)
		"pct":
			return "%d%%" % roundi(v * 100.0)
		"pct+":
			return "+%d%%" % roundi(v * 100.0)
	return fmt_num(v)


## 9 → "9", 9.5 → "9.5", 0.55 → "0.55".
static func fmt_num(v: float) -> String:
	if absf(v - roundf(v)) < 0.001:
		return str(roundi(v))
	var s := "%.2f" % v
	return s.rstrip("0").rstrip(".")


## Large counters (damage dealt): 950, 12.3k, 1.2M.
static func fmt_big(v: float) -> String:
	if v >= 1_000_000.0:
		return "%.1fM" % (v / 1_000_000.0)
	if v >= 10_000.0:
		return "%.1fk" % (v / 1000.0)
	return str(roundi(v))


static func fmt_time(seconds: float) -> String:
	var s := maxi(int(seconds), 0)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


static func sell_value(t: SimTower) -> int:
	return floori(t.invested * GameSim.SELL_REFUND)


static func mode_name(hard: bool, infinite: bool, twists := false) -> String:
	return (
		("Hard" if hard else "Normal")
		+ (SEP + "Twists" if twists else "")
		+ (SEP + "Infinite" if infinite else "")
	)


static func epic_requirement(epic: StringName) -> String:
	var def: Dictionary = TowerDefs.TOWERS[epic]
	var members := PackedStringArray()
	for id in TowerDefs.BUILD_ORDER:
		if TowerDefs.TOWERS[id].family == def.family:
			members.append(full_name(id))
	return (
		"Fuse two level-3 %s towers (%s) + %d gold"
		% [FAMILY_NAMES[def.family], " or ".join(members), def.fuse_cost]
	)


# --- Fusion -------------------------------------------------------------------


## Level-3 towers on the board that can fuse into `epic`.
static func fusion_candidates(sim: GameSim, epic: StringName) -> Array[Vector2i]:
	var family: StringName = TowerDefs.TOWERS[epic].family
	var out: Array[Vector2i] = []
	for t: SimTower in sim.towers.values():
		if not t.is_epic() and t.level >= TowerDefs.MAX_LEVEL and t.family() == family:
			out.append(t.tile)
	return out


static func can_fuse(sim: GameSim, epic: StringName) -> bool:
	return (
		fusion_candidates(sim, epic).size() >= 2
		and sim.gold >= int(TowerDefs.TOWERS[epic].fuse_cost)
	)


## Towers the tower on `tile` could fuse with right now (gold aside).
static func fuse_partners(sim: GameSim, tile: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: SimTower in sim.towers.values():
		if sim.fusion_result(tile, t.tile) != &"":
			out.append(t.tile)
	return out


# --- Waves --------------------------------------------------------------------


## [creep type, count] in spawn order, one entry per type.
static func wave_groups(wave: int) -> Array:
	var order: Array[StringName] = []
	var counts := {}
	for entry in WaveDefs.spawn_list(wave):
		if not counts.has(entry[0]):
			order.append(entry[0])
			counts[entry[0]] = 0
		counts[entry[0]] += 1
	var out := []
	for type in order:
		out.append([type, counts[type]])
	return out


static func wave_classes(wave: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for g in wave_groups(wave):
		var c: StringName = CreepDefs.CREEPS[g[0]].class
		if not c in out:
			out.append(c)
	return out


## "10 Grunts, 3 Priestesses" style summary for tooltips.
static func wave_summary(wave: int) -> String:
	var parts := PackedStringArray()
	for g in wave_groups(wave):
		parts.append("%d %s" % [g[1], CreepDefs.CREEPS[g[0]].name])
	return ", ".join(parts)


## Context-sensitive [key, action] hints for the strip above the cards.
static func hints(state: StringName) -> Array:
	match state:
		&"build":
			return [
				["Click", "Place"], ["Shift+Click", "Keep placing"], ["Right-click/Esc", "Cancel"]
			]
		&"select":
			return [
				["U", "Upgrade"],
				["X", "Sell"],
				["G", "Fuse"],
				["Right-click", "Sell"],
				["Esc", "Deselect"],
			]
		&"fuse":
			return [["Click", "Glowing level-3 partner"], ["Esc/Right-click", "Cancel fuse"]]
	return [
		["1–0", "Build"],
		["N", "Next wave"],
		["Space", "Pause"],
		["F", "Speed"],
		["R/C", "Camera"],
		["B", "Boss"],
		["H", "Field Guide"],
	]
