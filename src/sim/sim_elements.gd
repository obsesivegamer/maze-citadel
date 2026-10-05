class_name SimElements
extends RefCounted
## Element TD's element picks and Guardians, under the eletd rules only
## (GDD §5.0). Each element has a level from 0 to 3, and a tower of an element
## can be built, or upgraded to level n, only with that element at 1, or at n.
## Levels come from picks: one at the start and one as each of
## EletdRules.PICK_WAVES is cleared, spent whenever the player likes on an
## element level or on Interest. The first element pick is granted at once;
## each later one summons a Guardian of that element, and the level comes
## only when it dies. Under classic rules nothing here is ever locked.

const INTEREST := &"interest"

## True under the eletd rules (GameSim.rules sets it).
var enabled := false
var interest_picks := 0
## Picks handed out so far, and spent so far.
var granted := 1
var spent := 0
var _levels := {}
## Element → the level its living Guardian grants on death.
var _guarding := {}
var _element_picked := false


func _init() -> void:
	for e in Damage.WHEEL:
		_levels[e] = 0


# --- Queries ----------------------------------------------------------------


func level(element: StringName) -> int:
	return _levels.get(element, 0)


## The level a living Guardian of `element` will grant, or 0 when none walks.
func pending_level(element: StringName) -> int:
	return _guarding.get(element, 0)


func pending_picks() -> int:
	return granted - spent if enabled else 0


## True once the free first element pick is spent: every later one summons.
func summons() -> bool:
	return _element_picked


## How much of `choice` the player has or has coming: an element's level
## counting its Guardian, or the Interest picks taken.
func taken(choice: StringName) -> int:
	if choice == INTEREST:
		return interest_picks
	return maxi(level(choice), pending_level(choice))


func can_pick(choice: StringName) -> bool:
	if pending_picks() <= 0:
		return false
	if choice == INTEREST:
		return interest_picks < EletdRules.INTEREST_PICKS
	if not is_choice(choice) or _guarding.has(choice):
		return false
	return level(choice) < EletdRules.MAX_ELEMENT_LEVEL


## The element a tower of `id` needs, or &"": the starters, the Bard and Epics
## (which need only their two level-3 parents) need none.
static func element_of(id: StringName) -> StringName:
	if id in EletdRules.COMPOSITE_TOWERS or id in TowerDefs.EPICS:
		return &""
	return TowerDefs.TOWERS[id].get("element", &"")


## Why a tower of `id` can't be built (level 1) or upgraded to `tower_level`,
## as the player reads it ("Needs Aqua", "Needs Aqua level 2"); "" if it can.
func needs(id: StringName, tower_level := 1) -> String:
	var e := element_of(id)
	if not enabled or e == &"" or level(e) >= tower_level:
		return ""
	var name := String(e).capitalize()
	return "Needs %s" % name if tower_level == 1 else "Needs %s level %d" % [name, tower_level]


## The towers that can be built now.
func unlocked_towers() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(TowerDefs.BUILD_ORDER.filter(func(id: StringName) -> bool: return needs(id) == ""))
	return out


## The element a tower of `id` attacks with: composite for the starters.
func attack_element(id: StringName) -> StringName:
	if enabled and id in EletdRules.COMPOSITE_TOWERS:
		return &"composite"
	return TowerDefs.TOWERS[id].get("element", &"")


## How hard a tower of `id` at `tower_level` hits under these rules, as a
## share of its table damage (EletdRules.tower_power); 1 under classic.
func power(id: StringName, tower_level: int) -> float:
	return EletdRules.tower_power(id, tower_level) if enabled else 1.0


## A direct hit's damage on creep `c` from a tower of `id` at `tower_level`
## (GameSim.hit): for a shot, the tower as it was when it fired.
func hit_amount(base: float, id: StringName, tower_level: int, c: SimCreep, aura: float) -> float:
	var a := base * power(id, tower_level)
	var attack: StringName = TowerDefs.stat(id, "attack", tower_level)
	return Damage.amount(a, attack, attack_element(id), c, aura, c.effective_armor())


func interest_rate() -> float:
	return GameSim.INTEREST_RATE + interest_picks * EletdRules.INTEREST_PICK_RATE


func interest_cap() -> int:
	return GameSim.INTEREST_CAP + interest_picks * EletdRules.INTEREST_PICK_CAP


# --- Picks ------------------------------------------------------------------


## Spends a pending pick on an element level or on Interest.
func pick(sim: GameSim, choice: StringName) -> bool:
	var over := sim.phase == GameSim.Phase.DEFEAT or sim.phase == GameSim.Phase.VICTORY
	if over or not can_pick(choice):
		return false
	spent += 1
	sim.events.append({"type": &"pick_spent", "choice": choice, "picks": pending_picks()})
	if choice == INTEREST:
		interest_picks += 1
	elif not _element_picked:
		_element_picked = true
		_gain(sim, choice, level(choice) + 1)
	else:
		_summon(sim, choice, level(choice) + 1)
	return true


## Levels and Interest set up before the game (--picks), for tests,
## screenshots and experiments: granted at once, with no Guardians, on top of
## the game's own picks.
func apply_picks(choices: Array[StringName]) -> void:
	for choice in choices:
		if choice == INTEREST:
			interest_picks = mini(interest_picks + 1, EletdRules.INTEREST_PICKS)
		elif _levels.has(choice):
			_levels[choice] = mini(level(choice) + 1, EletdRules.MAX_ELEMENT_LEVEL)


## The picks in a comma-separated list such as "aqua,dark,interest".
static func parse_picks(text: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for part in text.split(",", false):
		out.append(StringName(part.strip_edges()))
	return out


static func is_choice(choice: StringName) -> bool:
	return choice == INTEREST or choice in Damage.WHEEL


# --- Sim hooks --------------------------------------------------------------


## False, with an upgrade_refused event the player can read, while the next
## level of `t` needs a higher element level.
func may_upgrade(sim: GameSim, t: SimTower) -> bool:
	var why := needs(t.id, t.level + 1)
	if why != "":
		sim.events.append({"type": &"upgrade_refused", "tile": t.tile, "needs": why})
	return why == ""


## A pick for every wave in EletdRules.PICK_WAVES up to the one just cleared
## (waves called early are cleared together).
func on_wave_cleared(sim: GameSim) -> void:
	if not enabled:
		return
	var due := 1 + EletdRules.PICK_WAVES.filter(func(w: int) -> bool: return w <= sim.wave).size()
	while granted < due:
		granted += 1
		sim.events.append({"type": &"pick_granted", "wave": sim.wave, "picks": pending_picks()})


func on_died(sim: GameSim, c: SimCreep) -> void:
	if c.type == &"guardian" and _guarding.has(c.element):
		_gain(sim, c.element, _guarding[c.element])
		_guarding.erase(c.element)


func _gain(sim: GameSim, element: StringName, to: int) -> void:
	_levels[element] = to
	sim.events.append({"type": &"element_gained", "element": element, "level": to})


## A boss of `element` enters at the portal now, whatever the phase; the
## level comes when it dies, and a leak sends it round again.
func _summon(sim: GameSim, element: StringName, to: int) -> void:
	_guarding[element] = to
	var w := maxi(sim.wave, 1)
	var c := sim.spawn_creep(&"guardian", element, w, sim.grid.spawn_point)
	c.max_hp = EletdRules.guardian_hp(to, w, sim.difficulty) * MapDefs.hp_mult(sim.grid.map, w)
	c.hp = c.max_hp
	c.bounty = 0
	sim.events.append({"type": &"guardian_spawned", "id": c.id, "element": element, "level": to})
