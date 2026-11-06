class_name HeatWords
extends RefCounted


static func word(value: float) -> String:
	if value <= 0.5:
		return "clean"
	if value < 40.0:
		return "noted"
	return "wanted"


static func guns(sim) -> String:
	var therm := float(sim.player.get("therm", 0.0))
	var cooling := float(Fit.stats(sim.defs, sim.player).cooling)
	var line := "Guns %.0f / 100. Plate cooling %.0f." % [therm, cooling]
	if bool(sim.player.get("overheat", false)):
		line += " The guns are held."
	return line


static func chip(sim) -> String:
	var heat := float(sim.heat.get(sim._pdo_id(), 0.0))
	var stage := str(sim.heat_stage())
	var heat_word := word(heat)
	if stage == "guns":
		heat_word = "guns"
	elif stage == "fine":
		heat_word = "fined"
	elif stage == "hail":
		heat_word = "hailed"
	var line := "HEAT  %s" % heat_word
	var gang := _gang(sim)
	if gang != "":
		line += "  ·  %s" % gang
	return line


static func _gang(sim) -> String:
	var pdo := str(sim._pdo_id())
	var best_name := ""
	var best := 7.9
	for faction_id in sim.defs.factions.keys():
		if str(faction_id) == pdo:
			continue
		var faction: Dictionary = sim.defs.factions[faction_id]
		if str(faction.get("kind", "")) == "pdo":
			continue
		var value := float(sim.heat.get(faction_id, 0.0))
		if value <= best:
			continue
		best = value
		best_name = str(faction.get("name", ""))
	if best_name == "":
		return ""
	return "%s %s" % [best_name, word(best)]


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
