class_name InterestLock
extends RefCounted
## Element TD's price for a leak, under the eletd rules only: interest stops
## until the field is clear again, so leaking costs more than lives. The timer
## holds where it was rather than starting over, so a lock delays the next
## payout by exactly how long it lasted.


static func on_leak(sim: GameSim) -> void:
	if sim.rules != &"eletd" or sim.interest_locked:
		return
	sim.interest_locked = true
	sim.events.append({"type": &"interest_locked"})


## Called whenever the field is empty, between waves too: a Guardian can be
## summoned, leak and die before the next wave starts.
static func on_field_clear(sim: GameSim) -> void:
	if not sim.interest_locked:
		return
	sim.interest_locked = false
	sim.events.append({"type": &"interest_unlocked"})
