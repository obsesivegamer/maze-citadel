class_name HudNotices
extends RefCounted
## When the line above the cards (Hud._say) teaches a rule under eletd: the
## first leak of a game, and at each wave start the picks left unspent and,
## every few waves, gold past the interest cap. One per Hud, so per game.
## Free of nodes so the decisions are unit-tested
## (tests/unit/test_ui_notices.gd).

const LEAK := (
	"Leaked creeps cost lives and walk the maze again until killed.\n"
	+ "Interest stops until the board is clear."
)
## Waves between two nudges about gold past the interest cap.
const GOLD_NUDGE_WAVES := 3

var _leak_told := false
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
			var picks := ElementPicks.unspent_reminder(sim)
			if picks != "":
				lines.append(picks)
			var gold := ElementPicks.gold_nudge(sim)
			if gold != "" and (_gold_nudged == 0 or e.wave - _gold_nudged >= GOLD_NUDGE_WAVES):
				_gold_nudged = e.wave
				lines.append(gold)
			return "\n".join(lines)
	return ""
