class_name HudNotices
extends RefCounted
## When the line above the cards (Hud._say) teaches a rule under eletd: the
## first leak of a game, and at a wave start too little air cover for its
## flyers (AirCover) and, every few waves, the picks left unspent and gold
## past the interest cap. One per Hud, so per game.
## Free of nodes so the decisions are unit-tested
## (tests/unit/test_ui_notices.gd).

const LEAK := (
	"Leaked creeps cost lives and walk the maze again until killed.\n"
	+ "Interest stops until the board is clear."
)
## Waves between two reminders of picks left unspent, unless another pick
## has come since, and between two nudges about gold past the interest cap.
const NUDGE_WAVES := 3

var _leak_told := false
## The wave of the last reminder of unspent picks and how many waited then,
## 0 while none waits.
var _picks_nudged := 0
var _picks_told := 0
## The wave of the last gold nudge, 0 before the first.
var _gold_nudged := 0


## The line sim event `e` puts above the cards, or "". A Guardian's leak has
## its own line (ElementPicks.guardian_leaked).
func line_for(sim: GameSim, e: Dictionary) -> String:
	match e.type:
		&"leaked":
			if _leak_told or e.get("creep", &"") == &"guardian":
				return ""
			_leak_told = true
			return LEAK
		&"wave_started":
			var lines := PackedStringArray()
			if TowerInfo.flying(e.wave, sim.rules):
				var air := AirCover.warning(AirCover.estimate(sim, e.wave))
				if air != "":
					lines.append(air)
			var picks := ElementPicks.unspent_reminder(sim)
			var waiting := sim.elements.pending_picks() if picks != "" else 0
			if waiting > _picks_told or (waiting > 0 and e.wave - _picks_nudged >= NUDGE_WAVES):
				_picks_nudged = e.wave
				lines.append(picks)
			_picks_told = waiting
			var gold := ElementPicks.gold_nudge(sim)
			if gold != "" and (_gold_nudged == 0 or e.wave - _gold_nudged >= NUDGE_WAVES):
				_gold_nudged = e.wave
				lines.append(gold)
			return "\n".join(lines)
	return ""
