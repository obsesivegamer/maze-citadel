class_name Damage
extends RefCounted
## Damage model (GDD §6): base × attack-vs-class × element wheel × armor × aura.

const ATTACK_VS_CLASS := {
	&"pierce": {&"light": 1.5, &"armored": 0.5, &"air": 1.75, &"boss": 0.7},
	&"siege": {&"light": 1.0, &"armored": 1.75, &"air": 0.0, &"boss": 1.0},
	&"magic": {&"light": 1.0, &"armored": 1.25, &"air": 1.0, &"boss": 0.75},
	&"poison": {&"light": 1.0, &"armored": 1.0, &"air": 1.0, &"boss": 1.0},
	&"rune": {&"light": 1.0, &"armored": 1.0, &"air": 1.0, &"boss": 1.0},
}
## Each element deals 200% to the next one and 50% to the previous one.
const WHEEL: Array[StringName] = [&"light", &"dark", &"aqua", &"flame", &"verdant", &"stone"]
const STRONG := 2.0
const WEAK := 0.5


static func class_mult(attack: StringName, armor_class: StringName) -> float:
	return ATTACK_VS_CLASS[attack].get(armor_class, 1.0)


## Composite armor (eletd waves) sits off the wheel: every element on it
## deals EletdRules.COMPOSITE_DAMAGE.
static func element_mult(attacker: StringName, defender: StringName) -> float:
	if defender == &"composite":
		return EletdRules.COMPOSITE_DAMAGE if attacker in WHEEL else 1.0
	var i := WHEEL.find(attacker)
	var j := WHEEL.find(defender)
	if i == -1 or j == -1:
		return 1.0
	if (i + 1) % WHEEL.size() == j:
		return STRONG
	if (j + 1) % WHEEL.size() == i:
		return WEAK
	return 1.0


## Warcraft III armor curve; negative armor (after shred) amplifies damage.
static func armor_factor(armor: float) -> float:
	if armor >= 0.0:
		return 1.0 - 0.06 * armor / (1.0 + 0.06 * armor)
	return 2.0 - pow(0.94, -armor)


static func counter(attacker: StringName, defender: StringName) -> StringName:
	var m := element_mult(attacker, defender)
	if m >= STRONG:
		return &"strong"
	if m <= WEAK:
		return &"weak"
	return &"neutral"


static func amount(
	base: float,
	attack: StringName,
	element: StringName,
	creep: SimCreep,
	aura: float,
	armor: float,
) -> float:
	var a := base * class_mult(attack, creep.armor_class) * element_mult(element, creep.element)
	if attack != &"poison":
		a *= armor_factor(armor)
	return a * (1.0 + aura)
