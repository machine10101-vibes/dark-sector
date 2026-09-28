class_name PocketRules
extends RefCounted


static func status(sim) -> Dictionary:
	var surveyed := bool(sim.claim.get("surveyed", false))
	var line := "Eligible homestead pocket. No Claim Core is aboard, so the stake stays empty."
	if surveyed:
		line = "A shuttle walked the Latch. It will take a dome and a core. Neither is aboard."
	return {
		"name": "Hollow Latch",
		"eligible": true,
		"owned": false,
		"frozen": false,
		"surveyed": surveyed,
		"line": line,
	}


static func confirm_walk(sim) -> void:
	if bool(sim.claim.get("surveyed", false)):
		sim.say("Hollow Latch is already walked. The core is still a future bolt.")
		return
	sim.claim.surveyed = true
	sim.quest_flags["hollow_latch_surveyed"] = true
	sim.say("Hollow Latch will hold a core. The garden is not planted. The keel is still the home.")
	sim.sfx("scan_done")
