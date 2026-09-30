class_name DockBoard
extends RefCounted

const SCAN_PAY := 80
const HAUL_PAY := 120
const PAD := 220.0
const RING := 160.0
const CRATE := "dock_crate"


static func at_pad(sim) -> bool:
	if sim == null or sim.player.is_empty():
		return false
	if str(sim.defs.system.id) != "HC-V1-R1-S1":
		return false
	if bool(sim.player.get("moored", false)):
		return true
	if sim.beacon_pos == Vector2.ZERO:
		return false
	return sim.player.pos.distance_to(sim.beacon_pos) <= PAD


static func purse(sim) -> int:
	return int(sim.quest_flags.get("purse", 0))


static func jobs(sim) -> Array:
	return [
		{
			"id": "scan",
			"title": "Seal Aegis Prime",
			"pay": SCAN_PAY,
			"state": state(sim, "dock_scan"),
			"blurb": scan_blurb(sim),
		},
		{
			"id": "haul",
			"title": "Crate to the ice ring",
			"pay": HAUL_PAY,
			"state": state(sim, "dock_haul"),
			"blurb": haul_blurb(sim),
		},
	]


static func state(sim, key: String) -> String:
	var value := str(sim.quest_flags.get(key, "open"))
	if value != "active" and value != "done":
		return "open"
	return value


static func scan_blurb(sim) -> String:
	var value := state(sim, "dock_scan")
	if value == "done":
		return "Filed. The dock already paid %d." % SCAN_PAY
	if value == "active":
		if sim.dossier_complete("aegis_prime"):
			return "Aegis Prime is sealed. Stand the pad. Pay %d lands on contact." % SCAN_PAY
		return "The probe reads Aegis Prime. The dock pays %d when that dossier seals on the pad." % SCAN_PAY
	return "Launch a probe on Aegis Prime. Pay %d when the dossier seals." % SCAN_PAY


static func haul_blurb(sim) -> String:
	var value := state(sim, "dock_haul")
	if value == "done":
		return "Filed. The dock already paid %d." % HAUL_PAY
	if value == "active" and bool(sim.quest_flags.get("dock_haul_ring", false)):
		return "The ice ring has the mark. Bring the crate back to the pad for %d." % HAUL_PAY
	if value == "active":
		return "The crate is in the hold. Fly it to the Aegis ice ring, then back to the pad. Pay %d." % HAUL_PAY
	return "Carry a sealed crate to the Aegis ice ring and bring it back. Pay %d." % HAUL_PAY


static func take(sim, job_id: String) -> String:
	if not at_pad(sim):
		return "The board is at the Helion Dock pad."
	if job_id == "scan":
		return _take_scan(sim)
	if job_id == "haul":
		return _take_haul(sim)
	return "That slip is blank."


static func pulse(sim, _dt: float) -> void:
	if sim.player.is_empty():
		return
	_pulse_scan(sim)
	_pulse_haul(sim)


static func _take_scan(sim) -> String:
	var value := state(sim, "dock_scan")
	if value == "done":
		return "Aegis scan is already filed."
	if value == "active":
		return "Aegis scan is already on the slate."
	sim.quest_flags.dock_scan = "active"
	# A probe already in flight was aimed at the nearest node, which from
	# this pad is the ice ring. The slip is Aegis Prime. Send it there.
	if sim.dossier_complete("aegis_prime") == false:
		for craft in sim.craft:
			if str(craft.def_id) != "survey_probe":
				continue
			if str(craft.state) == "docked" or str(craft.state) == "lost":
				continue
			if str(craft.target) == "aegis_prime":
				continue
			CraftOrders.order(sim, str(craft.uid), "scan", "aegis_prime")
	sim.say("Aegis scan taken. The probe reads Aegis Prime. Stand the pad when the dossier seals for %d." % SCAN_PAY)
	return ""


static func _take_haul(sim) -> String:
	var value := state(sim, "dock_haul")
	if value == "done":
		return "The ring haul is already filed."
	if value == "active":
		return "The ring crate is already in the hold."
	var stats: Dictionary = Fit.stats(sim.defs, sim.player)
	if Fit.cargo_used(sim.player) >= int(stats.cargo_cap):
		return "The hold is full. The dock will not hand over the crate."
	sim._add_cargo(CRATE, 1)
	sim.quest_flags.dock_haul = "active"
	sim.quest_flags.dock_haul_ring = false
	sim.quest_flags.haul_cue_bucket = -999
	sim.say("Ring haul taken. Crate aboard. Hold toward the ice ring — don't clear the band yet. Pay %d." % HAUL_PAY)
	_cue_outbound(sim)
	return ""


static func _pulse_scan(sim) -> void:
	if state(sim, "dock_scan") != "active":
		return
	if sim.dossier_complete("aegis_prime") == false:
		return
	# Sealing off the pad keeps the slip open. Purse moves on the pad,
	# which includes a fresh Moored, not only a keel that never left.
	if at_pad(sim) == false:
		return
	sim.quest_flags.dock_scan = "done"
	_pay(sim, SCAN_PAY, "Aegis scan filed. Helion Dock paid %d." % SCAN_PAY)


static func haul_line(sim) -> String:
	if state(sim, "dock_haul") != "active":
		return ""
	if bool(sim.quest_flags.get("dock_haul_ring", false)):
		if at_pad(sim):
			return ""
		var back: float = sim.player.pos.distance_to(sim.beacon_pos)
		return "Helion Dock %d m — bring the crate back." % int(back)
	var ring = sim.survey_node("aegis_ring")
	if ring == null:
		return ""
	var gap: float = sim.player.pos.distance_to(ring.pos)
	return "Ice ring %d m — hold that way." % int(gap)


## Same plane as the amber beam. The camera lives in render meters
## (world minus the floating origin). Absolute world meters point the
## other way from the pad, and the range number climbs.
static var forced_origin: Variant = null


static func marker_xy(sim, world: Vector2) -> Vector2:
	var shown := world
	if sim != null and int(sim.layer) == ScaleFrame.CHART:
		shown = ScaleFrame.chart_view(sim, world)
	var origin := Vector2.ZERO
	if forced_origin is Vector2:
		origin = forced_origin
	else:
		var gate: Variant = WorldCoord.gate()
		if gate != null:
			origin = gate.origin_m
	return shown - origin


static func _cue_outbound(sim) -> void:
	if sim.haul_outbound() == false:
		return
	var ring = sim.survey_node("aegis_ring")
	if ring == null:
		return
	var gap := int(sim.player.pos.distance_to(ring.pos))
	var bucket := int(gap / 60)
	if int(sim.quest_flags.get("haul_cue_bucket", -999)) == bucket:
		return
	sim.quest_flags.haul_cue_bucket = bucket
	sim.say("Ice ring %d m — hold that way." % gap)


static func _cue_return(sim) -> void:
	if state(sim, "dock_haul") != "active":
		return
	if bool(sim.quest_flags.get("dock_haul_ring", false)) == false:
		return
	if at_pad(sim):
		return
	var gap := int(sim.player.pos.distance_to(sim.beacon_pos))
	var bucket := int(gap / 60)
	if int(sim.quest_flags.get("haul_back_bucket", -999)) == bucket:
		return
	sim.quest_flags.haul_back_bucket = bucket
	sim.say("Helion Dock %d m — bring the crate back." % gap)


static func _pulse_haul(sim) -> void:
	if state(sim, "dock_haul") != "active":
		return
	if int(sim.player.cargo.get(CRATE, 0)) < 1:
		sim.quest_flags.dock_haul = "open"
		sim.quest_flags.dock_haul_ring = false
		sim.say("The ring crate is gone. The board put the slip back.")
		return
	_cue_outbound(sim)
	if str(sim.defs.system.id) == "HC-V1-R1-S1" and _near_ring(sim):
		if bool(sim.quest_flags.get("dock_haul_ring", false)) == false:
			sim.quest_flags.dock_haul_ring = true
			sim.quest_flags.haul_back_bucket = -999
			sim.say("Ice ring has the crate. Bring it back to the Helion pad.")
	_cue_return(sim)
	if bool(sim.quest_flags.get("dock_haul_ring", false)) and at_pad(sim):
		sim.spend_cargo(CRATE, 1)
		sim.quest_flags.dock_haul = "done"
		sim.quest_flags.dock_haul_ring = false
		_pay(sim, HAUL_PAY, "Ring haul filed. Helion Dock paid %d." % HAUL_PAY)


static func _near_ring(sim) -> bool:
	var ring = sim.survey_node("aegis_ring")
	if ring == null:
		return false
	return sim.player.pos.distance_to(ring.pos) <= RING


static func _pay(sim, amount: int, line: String) -> void:
	var next := purse(sim) + amount
	sim.quest_flags.purse = next
	sim.say("%s Purse %d." % [line, next])
