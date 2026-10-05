class_name EletdWaves
extends RefCounted
## Element TD's wave shapes under the &"eletd" rule set (GDD §5.0): longer and
## tighter streams, composite-armor waves and Bulky waves, with the numbers in
## EletdRules. Reached through WaveDefs.spawn_list(w, &"eletd").


## [type, element, HP share, bounty, bulky] per creep in spawn order. The HP
## share scales the creep's table HP. A group of n becomes m = n × WAVE_SIZE
## creeps at n / m of the HP each and its gold dealt out in whole coins, so
## the group's HP and bounty add up to the table's. A Bulky wave keeps the
## first half of each group, each creep with BULKY_HP times the HP and
## BULKY_BOUNTY times the coins it was dealt. Bosses keep their own numbers.
static func spawn_list(wave: int) -> Array:
	var r := WaveDefs.row(wave)
	var composite := WaveDefs.table_wave(wave) in EletdRules.COMPOSITE_WAVES
	var bulky := WaveDefs.bulky(wave, &"eletd")
	var out := []
	for group in r.groups:
		var type: StringName = group[0]
		var element: StringName = group[2] if group.size() > 2 else r.element
		if composite:
			element = &"composite"
		var n: int = group[1]
		var bounty := CreepDefs.creep_bounty(type, wave)
		if CreepDefs.is_boss(type):
			for _i in n:
				out.append([type, element, 1.0, bounty, false])
			continue
		var m := ceili(n * EletdRules.WAVE_SIZE)
		var gold := n * bounty
		var hp := n / float(m)
		var count := m
		var gold_mult := 1
		if bulky:
			count = ceili(m * EletdRules.BULKY_COUNT)
			hp *= EletdRules.BULKY_HP
			gold_mult = EletdRules.BULKY_BOUNTY
		for i in count:
			# Creep i gets the coins between the i-th and the next m-th of the
			# group's gold: shares differ by at most one coin and add up exactly.
			var coins := floori(gold * (i + 1) / float(m)) - floori(gold * i / float(m))
			out.append([type, element, hp, coins * gold_mult, bulky])
	return out
