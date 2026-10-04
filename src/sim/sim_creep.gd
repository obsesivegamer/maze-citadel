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
## A Bulky wave's creep (eletd): it costs a boss's lives on a leak.
var bulky := false
## Set on the first leak: the creep loops back to the portal and pays nothing.
var leaked := false
var alive := true
## Path left to the gate in metres; lower means closer (towers target lowest).
var progress := INF

var slow := 0.0
var slow_time := 0.0
var root_time := 0.0
## Poison stacks: x = damage per second after multipliers, y = seconds left.
var poison: Array[Vector2] = []
## The tower behind each poison stack, for damage and kill credit.
var poison_src: Array[SimTower] = []
var shred := 0.0
var shred_time := 0.0
var immune_time := 0.0
## Per-type ability timer: Steam Tank immunity, Priestess heal, Dreadlord summon.
var ability_timer := 0.0
var revived := false
## Twists mode ability (WaveTwists), or &"".
var twist: StringName = &""
var second_wind_used := false
## Seconds until a downed Ghoul stands back up; > 0 means down and untargetable.
var revive_time := 0.0
var aura_armor := 0.0
var aura_haste := 0.0
var dot_accum := 0.0
var dot_timer := 0.0


## Element TD's wave shapes (EletdWaves): the share of its table HP this
## creep has, its bounty and whether it is Bulky.
func reshape(hp_share: float, p_bounty: int, p_bulky: bool) -> void:
	max_hp *= hp_share
	hp = max_hp
	bounty = p_bounty
	bulky = p_bulky


## Lives a leak costs.
func leak_cost() -> int:
	if type == &"guardian":
		return EletdRules.GUARDIAN_LIVES
	if bulky:
		return EletdRules.BULKY_LIVES
	return 2 if boss else 1


func targetable() -> bool:
	return alive and revive_time <= 0.0


func effective_armor() -> float:
	return armor + aura_armor - shred


func effective_speed() -> float:
	if root_time > 0.0 or revive_time > 0.0:
		return 0.0
	return speed * (1.0 - slow) * (1.0 + aura_haste)


## True while the creep holds a poison stack from a tower of type `tower_id`.
func carries(tower_id: StringName) -> bool:
	for t in poison_src:
		if t != null and t.id == tower_id:
			return true
	return false
