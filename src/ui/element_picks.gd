class_name ElementPicks
extends RefCounted
## Words for the element picks under the eletd rules (GDD §5.0): the top
## bar's element tooltips and Pick chip, the pick panel's rows, why a card or
## an upgrade is locked, the Guardian banners, the reminders of picks left
## unspent and of gold past the interest cap, the Field Guide's page and the
## end screen. Free of nodes so the wording is unit-tested
## (tests/unit/test_element_picks.gd, test_ui_notices.gd).

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


## A locked card's reason, e.g. "Needs Aqua: pick an element (E)", or
## "Needs Aqua: press E and take it" while a pick waits; "" if open.
static func locked_reason(sim: GameSim, id: StringName) -> String:
	var why := sim.elements.needs(id)
	if why == "":
		return ""
	var e := SimElements.element_of(id)
	if sim.elements.pending_level(e) > 0:
		return "%s: kill the %s" % [why, guardian_title(e)]
	if sim.elements.can_pick(e):
		return "%s: press %s and take it" % [why, KEY]
	return "%s: pick an element (%s)" % [why, KEY]


## The words a locked card shows in place of its cost while a pick waits
## that would open it, e.g. "Pick Aqua"; "" otherwise.
static func card_hint(sim: GameSim, id: StringName) -> String:
	var e := SimElements.element_of(id)
	if sim.elements.needs(id) == "" or not sim.elements.can_pick(e):
		return ""
	return "Pick " + element_name(e)


static func chip_text(picks: int) -> String:
	return "PICK ×%d" % picks


## What level `to` of element `e` opens, e.g. "Build Frost Spire" or
## "Frost Spire to level 3; two fuse into Epic Frost Wyrm".
static func unlocks(e: StringName, to: int) -> String:
	var names := PackedStringArray()
	for id in towers_of(e):
		names.append(TowerInfo.full_name(id))
	var epics := _epics(e)
	var towers := " and ".join(names)
	if to <= 1:
		return "Build " + towers
	var text := "%s to level %d" % [towers, to]
	if to >= EletdRules.MAX_ELEMENT_LEVEL and not epics.is_empty():
		text += "; two fuse into " + " or ".join(epics)
	return text


## What spending a pick on `choice` does now, in plain words: "Unlocks Frost
## Spire", "Lets your 17 Frost Spires upgrade to level 2", or "Interest: +10
## gold every 15 s once you hold 1,000 gold". A pick that summons adds a line
## on the Guardian that grants it.
static func does(sim: GameSim, choice: StringName) -> String:
	var el := sim.elements
	if choice == SimElements.INTEREST:
		var rate := el.interest_rate() + EletdRules.INTEREST_PICK_RATE
		var cap := el.interest_cap() + EletdRules.INTEREST_PICK_CAP
		var from := maxi(
			interest_full_at(el.interest_rate(), el.interest_cap()), interest_full_at(rate, cap)
		)
		return (
			"Interest: +%d gold every %d s once you hold %s gold"
			% [cap - el.interest_cap(), GameSim.INTEREST_PERIOD, TowerInfo.fmt_gold(from)]
		)
	var to := el.level(choice) + 1
	if to > EletdRules.MAX_ELEMENT_LEVEL:
		return "All its towers to level %d" % EletdRules.MAX_ELEMENT_LEVEL
	var text := ""
	if to == 1:
		var names := PackedStringArray()
		for id in towers_of(choice):
			names.append(TowerInfo.full_name(id))
		text = "Unlocks " + " and ".join(names)
	else:
		text = "Lets %s upgrade to level %d" % [_owned(sim, choice), to]
		var epics := _epics(choice)
		if to == EletdRules.MAX_ELEMENT_LEVEL and not epics.is_empty():
			text += "; two at level %d fuse into %s" % [to, " or ".join(epics)]
	if not el.summons():
		return text
	var gain := element_name(choice) if to == 1 else gained_title(choice, to)
	return text + "\n" + _tint("Summons a Guardian: kill it to gain " + gain, UiTheme.TEXT_DIM)


## The towers of element `e` the player has, as "your 17 Frost Spires" or
## "your 12 Plague Cauldrons and any Shadow Obelisks"; just their names when
## there are none.
static func _owned(sim: GameSim, e: StringName) -> String:
	var counts := {}
	var any := false
	for id in towers_of(e):
		counts[id] = 0
	for t: SimTower in sim.towers.values():
		if counts.has(t.id):
			counts[t.id] += 1
			any = true
	var parts := PackedStringArray()
	for id: StringName in counts:
		var name := TowerInfo.full_name(id)
		var n: int = counts[id]
		if n == 1:
			parts.append("your " + name)
		elif n > 1:
			parts.append("your %d %s" % [n, _plural(name)])
		else:
			parts.append(("any " if any else "") + _plural(name))
	return " and ".join(parts)


## "Frost Spire" → "Frost Spires", "Ancient of Roots" → "Ancients of Roots".
static func _plural(name: String) -> String:
	return name.replace(" of ", "s of ") if name.contains(" of ") else name + "s"


static func _epics(e: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for id in towers_of(e):
		var epic: StringName = TowerDefs.FUSIONS.get(TowerDefs.TOWERS[id].family, &"")
		if epic != &"" and not TowerInfo.full_name(epic) in out:
			out.append(TowerInfo.full_name(epic))
	return out


## The least gold that draws the full payout at interest `rate` and `cap`, as
## GameSim pays it (a share of gold, rounded down, at most the cap): gold
## above it earns no more.
static func interest_full_at(rate: float, cap: int) -> int:
	var g := ceili(cap / rate)
	while g > 0 and mini(floori((g - 1) * rate), cap) >= cap:
		g -= 1
	while mini(floori(g * rate), cap) < cap:
		g += 1
	return g


## The gold past which interest stops growing now, with the Interest picks
## taken.
static func interest_cap_gold(sim: GameSim) -> int:
	return interest_full_at(sim.elements.interest_rate(), sim.elements.interest_cap())


## True while the gold in hand already draws the full interest payout.
static func interest_maxed(sim: GameSim) -> bool:
	return sim.elements.enabled and sim.gold >= interest_cap_gold(sim)


## The nudge for gold past the interest cap, e.g. "Gold above 1,000 earns no
## more interest: build or upgrade"; "" while it all still earns.
static func gold_nudge(sim: GameSim) -> String:
	var at := interest_cap_gold(sim)
	if not sim.elements.enabled or sim.gold <= at:
		return ""
	return "Gold above %s earns no more interest: build or upgrade" % TowerInfo.fmt_gold(at)


## True while a pending pick has something to buy.
static func can_spend(sim: GameSim) -> bool:
	for choice in CHOICES:
		if sim.elements.can_pick(choice):
			return true
	return false


## The wave-start reminder, e.g. "2 element picks unspent: press E"; "" with
## none to spend.
static func unspent_reminder(sim: GameSim) -> String:
	var n := sim.elements.pending_picks()
	if not can_spend(sim):
		return ""
	return "%d element pick%s unspent: press %s" % [n, "" if n == 1 else "s", KEY]


## The cleared banner's lines when a pick is granted: that it waits, and
## what a pick buys.
static func granted_text(sim: GameSim) -> String:
	var n := sim.elements.pending_picks()
	var ready := "Element pick ready" if n == 1 else "%d element picks ready" % n
	var buys := "A pick unlocks an element's towers, lets them upgrade a level, or raises interest"
	return "%s: press %s\n%s" % [ready, KEY, buys]


## The end screen's "Unspent" row, e.g. "3 picks · 3,453 gold": the picks
## left, and the gold when it had passed the interest cap (below it, it was
## still earning); "" when neither.
static func unspent(sim: GameSim) -> String:
	var parts := PackedStringArray()
	var n := sim.elements.pending_picks()
	if n > 0:
		parts.append("%d pick%s" % [n, "" if n == 1 else "s"])
	if sim.gold > interest_cap_gold(sim):
		parts.append("%s gold" % TowerInfo.fmt_gold(sim.gold))
	return TowerInfo.SEP.join(parts)


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
## glyph, from_to, unlocks (what taking it does, does()), towers (icons),
## counters, waves, action, hp (the Guardian's, 0 when none comes), enabled
## and reason (why it can't be taken).
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
		r.unlocks = does(sim, choice)
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
	r.unlocks = does(sim, choice)
	r.towers = towers_of(choice)
	r.counters = counters(choice)
	r.waves = coming_waves(sim, choice)
	if el.summons():
		r.action = "Summon Guardian"
		if not maxed:
			r.hp = (
				EletdRules.guardian_hp(level + 1, maxi(sim.wave, 1), sim.difficulty)
				* MapDefs.hp_mult(sim.grid.map, maxi(sim.wave, 1))
			)
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
