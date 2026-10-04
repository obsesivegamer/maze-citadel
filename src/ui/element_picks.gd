class_name ElementPicks
extends RefCounted
## Words for the element picks under the eletd rules (GDD §5.0): the top
## bar's element tooltips and Pick chip, the pick panel's rows, why a card or
## an upgrade is locked, the Guardian banners, the Field Guide's page and the
## end screen. Free of nodes so the wording is unit-tested
## (tests/unit/test_element_picks.gd).

## The key that opens the pick panel while a pick waits.
const KEY := "E"
## How many waves ahead a row rates an element against.
const WAVES_AHEAD := 10
## Rows of the pick panel, in key order: the wheel, then Interest.
const CHOICES: Array[StringName] = [
	&"light", &"dark", &"aqua", &"flame", &"verdant", &"stone", &"interest"
]


static func element_name(e: StringName) -> String:
	return TowerInfo.ELEMENT_NAMES[e]


## The buildable towers that need element `e`, in card order.
static func towers_of(e: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in TowerDefs.BUILD_ORDER:
		if SimElements.element_of(id) == e:
			out.append(id)
	return out


## A locked card's reason, e.g. "Needs Aqua: pick an element (E)"; "" if open.
static func locked_reason(sim: GameSim, id: StringName) -> String:
	var why := sim.elements.needs(id)
	return "" if why == "" else "%s: pick an element (%s)" % [why, KEY]


static func chip_text(picks: int) -> String:
	return "PICK ×%d" % picks


## What level `to` of element `e` opens, e.g. "Build Frost Spire" or
## "Frost Spire to level 3; two fuse into Epic Frost Wyrm".
static func unlocks(e: StringName, to: int) -> String:
	var names := PackedStringArray()
	var epics := PackedStringArray()
	for id in towers_of(e):
		names.append(TowerInfo.full_name(id))
		var epic: StringName = TowerDefs.FUSIONS.get(TowerDefs.TOWERS[id].family, &"")
		if epic != &"" and not TowerInfo.full_name(epic) in epics:
			epics.append(TowerInfo.full_name(epic))
	var towers := " and ".join(names)
	if to <= 1:
		return "Build " + towers
	var text := "%s to level %d" % [towers, to]
	if to >= EletdRules.MAX_ELEMENT_LEVEL and not epics.is_empty():
		text += "; two fuse into " + " or ".join(epics)
	return text


## "Strong vs Flame · Weak vs Dark", coloured.
static func counters(e: StringName) -> String:
	return (
		TowerInfo
		. SEP
		. join(
			PackedStringArray(
				[
					_tint("Strong vs " + element_name(TowerInfo.strong_against(e)), UiTheme.GOOD),
					_tint("Weak vs " + element_name(TowerInfo.weak_against(e)), UiTheme.BAD),
				]
			)
		)
	)


## How element `e` fares on the coming waves' elements, e.g. "Waves 6–15:
## 200% on 9, 13 · 50% on 6"; "" when no wave is left.
static func coming_waves(sim: GameSim, e: StringName) -> String:
	var from := sim.wave + 1
	var to := mini(sim.wave + WAVES_AHEAD, sim.last_wave())
	if from > to:
		return ""
	var strong := PackedStringArray()
	var weak := PackedStringArray()
	for w in range(from, to + 1):
		for we in WaveDefs.elements(w, sim.rules):
			var m := Damage.element_mult(e, we)
			if m >= Damage.STRONG and not str(w) in strong:
				strong.append(str(w))
			elif m <= Damage.WEAK and not str(w) in weak:
				weak.append(str(w))
	var parts := PackedStringArray()
	if not strong.is_empty():
		parts.append("%s on %s" % [Counsel.pct(Damage.STRONG), ", ".join(strong)])
	if not weak.is_empty():
		parts.append("%s on %s" % [Counsel.pct(Damage.WEAK), ", ".join(weak)])
	if parts.is_empty():
		parts.append("no counter either way")
	var span := ("Wave %d" % from) if from == to else ("Waves %d–%d" % [from, to])
	return "%s: %s" % [span, TowerInfo.SEP.join(parts)]


## One row of the pick panel for `choice` (an element or Interest): name,
## glyph, from_to, unlocks, towers (icons), counters, waves, action, hp (the
## Guardian's, 0 when none comes), enabled and reason (why it can't be taken).
static func row(sim: GameSim, choice: StringName) -> Dictionary:
	var el := sim.elements
	var r := {
		"name": "",
		"glyph": &"",
		"from_to": "",
		"unlocks": "",
		"towers": [] as Array[StringName],
		"counters": "",
		"waves": "",
		"action": "Take",
		"hp": 0.0,
		"enabled": el.can_pick(choice),
		"reason": reason(sim, choice),
	}
	if choice == SimElements.INTEREST:
		var n := el.interest_picks
		r.name = "Interest"
		r.glyph = &"interest"
		r.unlocks = (
			"+%d%% interest, +%d cap"
			% [roundi(EletdRules.INTEREST_PICK_RATE * 100), EletdRules.INTEREST_PICK_CAP]
		)
		r.from_to = _pct_step(el.interest_rate(), n < EletdRules.INTEREST_PICKS)
		r.counters = (
			"Paid every %d s, up to %d gold now" % [GameSim.INTEREST_PERIOD, el.interest_cap()]
		)
		return r
	var level := el.level(choice)
	var maxed := level >= EletdRules.MAX_ELEMENT_LEVEL
	r.name = element_name(choice)
	r.glyph = UiGlyphs.element(choice)
	r.from_to = "Level %d" % level if maxed else "Level %d → %d" % [level, level + 1]
	r.unlocks = "All its towers to level 3" if maxed else unlocks(choice, level + 1)
	r.towers = towers_of(choice)
	r.counters = counters(choice)
	r.waves = coming_waves(sim, choice)
	if el.summons():
		r.action = "Summon Guardian"
		if not maxed:
			r.hp = EletdRules.guardian_hp(level + 1, maxi(sim.wave, 1), sim.difficulty)
	return r


## Why `choice` can't be taken now, or "".
static func reason(sim: GameSim, choice: StringName) -> String:
	var el := sim.elements
	if choice == SimElements.INTEREST:
		if el.interest_picks >= EletdRules.INTEREST_PICKS:
			return "Taken %d times" % EletdRules.INTEREST_PICKS
	elif el.level(choice) >= EletdRules.MAX_ELEMENT_LEVEL:
		return "Level %d reached" % EletdRules.MAX_ELEMENT_LEVEL
	elif el.pending_level(choice) > 0:
		return "Its Guardian is walking"
	if el.pending_picks() <= 0:
		return "No pick to spend"
	return ""


## The line under the panel's title.
static func header(sim: GameSim) -> String:
	var n := sim.elements.pending_picks()
	var head := "%d pick%s to spend." % [n, "" if n == 1 else "s"]
	if n <= 0:
		head = "No pick to spend."
		var next := next_pick_wave(sim)
		if next > 0:
			head = "No pick to spend: the next comes when wave %d is cleared." % next
	if not sim.elements.summons():
		return head + " Your first element is free; each later one summons a Guardian."
	return head + " An element now summons its Guardian: kill it to learn the level."


## The wave whose clearing grants the next pick, or 0 when none is left.
static func next_pick_wave(sim: GameSim) -> int:
	for w in EletdRules.PICK_WAVES:
		if w > sim.wave or (w == sim.wave and sim.phase == GameSim.Phase.WAVE):
			return w
	return 0


## The top bar's tooltip for element `e`.
static func element_tip(sim: GameSim, e: StringName) -> String:
	var el := sim.elements
	var names := PackedStringArray()
	for id in towers_of(e):
		names.append(TowerInfo.full_name(id))
	var lines := PackedStringArray(
		[
			"%s · level %d of %d" % [element_name(e), el.level(e), EletdRules.MAX_ELEMENT_LEVEL],
			"Towers: " + ", ".join(names),
			(
				"Strong vs %s (%s), weak vs %s (%s)"
				% [
					element_name(TowerInfo.strong_against(e)),
					Counsel.pct(Damage.STRONG, false),
					element_name(TowerInfo.weak_against(e)),
					Counsel.pct(Damage.WEAK, false),
				]
			),
		]
	)
	if el.pending_level(e) > 0:
		lines.append("Its Guardian walks: kill it to learn level %d" % el.pending_level(e))
	elif el.level(e) == 0:
		lines.append("Pick it to build its towers (%s)" % KEY)
	return "\n".join(lines)


static func guardian_title(e: StringName) -> String:
	return "%s Guardian" % element_name(e)


static func guardian_detail(e: StringName, level: int) -> String:
	return "Kill it to learn %s level %d" % [element_name(e), level]


static func gained_title(e: StringName, level: int) -> String:
	return "%s level %d" % [element_name(e), level]


static func guardian_leaked(e: StringName, cost: int) -> String:
	return "The %s got through: %d lives lost. It walks again." % [guardian_title(e), cost]


## The elements a game reached, e.g. "Dark 3 · Flame 1"; "None" without any.
static func reached(sim: GameSim) -> String:
	var parts := PackedStringArray()
	for e in Damage.WHEEL:
		if sim.elements.level(e) > 0:
			parts.append("%s %d" % [element_name(e), sim.elements.level(e)])
	return TowerInfo.SEP.join(parts) if not parts.is_empty() else "None"


## The Field Guide's "Elements and picks" page.
static func guide_text() -> String:
	var waves := PackedStringArray()
	for w in EletdRules.PICK_WAVES:
		waves.append(str(w))
	return (
		(
			"Every tower but the Archer, the Cannon and the Bard needs its element: level 1 to"
			+ " build it, levels 2 and 3 to upgrade it. You get %d picks, one at the start and"
			+ " one as each of waves %s is cleared, against %d element levels, so no game has"
			+ " everything.\n\nSpend a pick on a level of an element, or on Interest (+%d%%"
			+ " interest and +%d cap, up to %d times). Your first element is free. Every later"
			+ " one summons a Guardian of that element at the portal: kill it to learn the"
			+ " level. A Guardian that leaks costs %d lives and walks again.\n\nThe Archer and"
			+ " the Cannon deal composite damage: 100%% against every element. Press %s, or"
			+ " the Pick chip by the element levels at the top left, to spend a pick."
		)
		% [
			EletdRules.PICK_WAVES.size() + 1,
			", ".join(waves),
			Damage.WHEEL.size() * EletdRules.MAX_ELEMENT_LEVEL,
			roundi(EletdRules.INTEREST_PICK_RATE * 100),
			EletdRules.INTEREST_PICK_CAP,
			EletdRules.INTEREST_PICKS,
			EletdRules.GUARDIAN_LIVES,
			KEY,
		]
	)


static func _pct_step(rate: float, more: bool) -> String:
	var now := roundi(rate * 100)
	if not more:
		return "%d%%" % now
	return "%d%% → %d%%" % [now, roundi((rate + EletdRules.INTEREST_PICK_RATE) * 100)]


static func _tint(text: String, c: Color) -> String:
	return "[color=#%s]%s[/color]" % [UiTheme.hex(c), text]
