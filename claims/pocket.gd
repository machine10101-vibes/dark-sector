class_name PocketRules
extends RefCounted


static func status(sim) -> Dictionary:
	var pocket: Dictionary = sim.defs.system.pocket
	var plantable := bool(pocket.get("plantable", false))
	var surveyed := bool(sim.claim.get("surveyed", false))
	var line := str(pocket.get("why", "Marked pocket."))
	if not plantable:
		line = "%s is marked and closed. Nothing can be planted." % pocket.name
	elif surveyed:
		line = "A shuttle walked the pocket. It will take a dome and a core. Neither is aboard."
	return {
		"name": str(pocket.name),
		"eligible": plantable,
		"owned": false,
		"frozen": false,
		"surveyed": surveyed,
		"line": line,
	}


static func confirm_walk(sim) -> void:
	if not bool(sim.defs.system.pocket.get("plantable", false)):
		sim.say("%s stays closed. No core goes in the ground." % sim.defs.system.pocket.name)
		return
	if bool(sim.claim.get("surveyed", false)):
		sim.say("The pocket is already walked. The core is still a future bolt.")
		return
	sim.claim.surveyed = true
	sim.quest_flags["hollow_latch_surveyed"] = true
	sim.say("The pocket will hold a core. The garden is not planted. The keel is still the home.")
	sim.sfx("scan_done")
