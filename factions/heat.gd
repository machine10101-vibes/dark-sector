class_name HeatWords
extends RefCounted


static func word(value: float) -> String:
	if value <= 0.5:
		return "clean"
	if value < 40.0:
		return "noted"
	return "wanted"


static func lines(sim, defs: Dictionary) -> Array:
	var out: Array = []
	for faction_id in defs.factions.keys():
		var faction: Dictionary = defs.factions[faction_id]
		var heat := float(sim.heat.get(faction_id, 0.0))
		var memory: Array = sim.memory.get(faction_id, [])
		out.append({
			"name": faction.name,
			"kind": faction.kind,
			"temper": faction.temper,
			"blurb": faction.blurb,
			"heat": heat,
			"word": word(heat),
			"memory": memory,
		})
	return out
