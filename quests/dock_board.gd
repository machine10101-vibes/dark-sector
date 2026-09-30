class_name DockBoard
extends RefCounted

const SCAN_PAY := 80
const HAUL_PAY := 120
const SALVAGE_PAY := 40
const ESCORT_PAY := 60
const PAD := 220.0
const RING := 160.0
const HOLD_REACH := 200.0
const CUTTER_REACH := 180.0
const CRATE := "dock_crate"
const GOOD := "glasswheat"
const BUY_PRICE := 12
const SELL_PRICE := 8
const TAG_LEN := 12


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
		{
			"id": "salvage",
			"title": "Tow tag at Seized Hold",
			"pay": SALVAGE_PAY,
			"state": state(sim, "dock_salvage"),
			"blurb": salvage_blurb(sim),
		},
		{
			"id": "escort",
			"title": "Show the Compact the lane",
			"pay": ESCORT_PAY,
			"state": state(sim, "dock_escort"),
			"blurb": escort_blurb(sim),
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


static func salvage_blurb(sim) -> String:
	var value := state(sim, "dock_salvage")
	if value == "done":
		return "Filed. The dock already paid %d for the tow tag." % SALVAGE_PAY
	if value == "active" and bool(sim.quest_flags.get("dock_salvage_cut", false)):
		return "The tag is cut. Bring it to the Helion pad. Pay %d." % SALVAGE_PAY
	if value == "active":
		return "Target Seized Hold. Strip the tow tag, then stand the pad. Pay %d." % SALVAGE_PAY
	return "Fly to Seized Hold, strip one tow tag, and bring it back. Pay %d." % SALVAGE_PAY


static func escort_blurb(sim) -> String:
	var value := state(sim, "dock_escort")
	if value == "done":
		return "Filed. The dock already paid %d for the lane show." % ESCORT_PAY
	if value == "active" and bool(sim.quest_flags.get("dock_escort_met", false)):
		return "The Compact cutter saw the keel. Stand the Helion pad. Pay %d." % ESCORT_PAY
	if value == "active":
		return "Target the Compact cutter. Show it the lane, then stand the pad. Pay %d." % ESCORT_PAY
	return "Fly out to the Compact cutter and come back to the pad. Pay %d." % ESCORT_PAY


static func take(sim, job_id: String) -> String:
	if not at_pad(sim):
		return "The board is at the Helion Dock pad."
	if job_id == "scan":
		return _take_scan(sim)
	if job_id == "haul":
		return _take_haul(sim)
	if job_id == "salvage":
		return _take_salvage(sim)
	if job_id == "escort":
		return _take_escort(sim)
	return "That slip is blank."


static func pulse(sim, _dt: float) -> void:
	if sim.player.is_empty():
		return
	_pulse_scan(sim)
	_pulse_haul(sim)
	_pulse_salvage(sim)
	_pulse_escort(sim)


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
	var face: Vector2 = beam_aim(sim)
	if face.length() > 8.0:
		sim.player.rot = face.angle()
	sim.say("Ring haul taken. Crate aboard. Hold toward the ice ring — don't clear the band yet. Pay %d." % HAUL_PAY)
	_cue_outbound(sim)
	return ""


static func _take_salvage(sim) -> String:
	var value := state(sim, "dock_salvage")
	if value == "done":
		return "The tow tag is already filed."
	if value == "active":
		return "The tow tag is already on the slate."
	sim.quest_flags.dock_salvage = "active"
	sim.quest_flags.dock_salvage_cut = false
	sim.quest_flags.salvage_cue_bucket = -999
	_face(sim, sim.trash_pos)
	sim.say("Tow tag taken. Seized Hold is the target. Pay %d on the pad." % SALVAGE_PAY)
	return ""


static func _take_escort(sim) -> String:
	var value := state(sim, "dock_escort")
	if value == "done":
		return "The lane show is already filed."
	if value == "active":
		return "The Compact show is already on the slate."
	sim.quest_flags.dock_escort = "active"
	sim.quest_flags.dock_escort_met = false
	sim.quest_flags.escort_cue_bucket = -999
	_face(sim, cutter_pos(sim))
	sim.say("Lane show taken. Find the Compact cutter. Pay %d on the pad." % ESCORT_PAY)
	return ""


static func _face(sim, world: Vector2) -> void:
	if world == Vector2.ZERO:
		return
	var face: Vector2 = world - sim.player.pos
	if face.length() > 8.0:
		sim.player.rot = face.angle()


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


## World vector the amber ribbon and the nose share.
## Outbound: keel → ice-ring drop. Return: keel → Helion pad.
## Thrust along it closes that leg. Absolute world headings open it.
## Zero when the crate is not on a leg.
static func beam_aim(sim) -> Vector2:
	if sim == null or sim.player.is_empty():
		return Vector2.ZERO
	if str(sim.quest_flags.get("dock_haul", "")) != "active":
		return Vector2.ZERO
	if bool(sim.quest_flags.get("dock_haul_ring", false)):
		if at_pad(sim):
			return Vector2.ZERO
		return sim.beacon_pos - sim.player.pos
	var ring = sim.survey_node("aegis_ring")
	if ring == null:
		return Vector2.ZERO
	return ring.pos - sim.player.pos


## Helm text. A live haul keeps the ice-ring line. Otherwise the open slip.
static func slip_line(sim) -> String:
	var haul := haul_line(sim)
	if haul != "":
		return haul
	var salvage := salvage_line(sim)
	if salvage != "":
		return salvage
	return escort_line(sim)


static func salvage_line(sim) -> String:
	if state(sim, "dock_salvage") != "active":
		return ""
	if bool(sim.quest_flags.get("dock_salvage_cut", false)):
		if at_pad(sim):
			return ""
		var back: float = sim.player.pos.distance_to(sim.beacon_pos)
		return "Helion Dock %d m — bring the tag back." % int(back)
	if sim.trash_pos == Vector2.ZERO:
		return ""
	var gap: float = sim.player.pos.distance_to(sim.trash_pos)
	return "Seized Hold %d m — strip the tag." % int(gap)


static func escort_line(sim) -> String:
	if state(sim, "dock_escort") != "active":
		return ""
	if bool(sim.quest_flags.get("dock_escort_met", false)):
		if at_pad(sim):
			return ""
		var back: float = sim.player.pos.distance_to(sim.beacon_pos)
		return "Helion Dock %d m — the cutter saw you." % int(back)
	var cutter := cutter_pos(sim)
	if cutter == Vector2.ZERO:
		return ""
	var gap: float = sim.player.pos.distance_to(cutter)
	return "Compact cutter %d m — show the lane." % int(gap)


## World point the glass arrow stands on. Haul still owns it while the crate is out.
static func cue_point(sim) -> Vector2:
	var aim := cue_aim(sim)
	if sim == null or sim.player.is_empty() or aim.length() <= 8.0:
		return Vector2.ZERO
	return sim.player.pos + aim


## Arrow aim. Haul still owns it while the crate is out.
## Always keel → target. An absolute world heading opens the range.
static func cue_aim(sim) -> Vector2:
	var haul := beam_aim(sim)
	if haul.length() > 8.0:
		return haul
	if state(sim, "dock_salvage") == "active":
		if bool(sim.quest_flags.get("dock_salvage_cut", false)):
			if at_pad(sim):
				return Vector2.ZERO
			return sim.beacon_pos - sim.player.pos
		if sim.trash_pos != Vector2.ZERO:
			return sim.trash_pos - sim.player.pos
	if state(sim, "dock_escort") == "active":
		if bool(sim.quest_flags.get("dock_escort_met", false)):
			if at_pad(sim):
				return Vector2.ZERO
			return sim.beacon_pos - sim.player.pos
		var cutter := cutter_pos(sim)
		if cutter != Vector2.ZERO:
			return cutter - sim.player.pos
	return Vector2.ZERO


static func cutter_pos(sim) -> Vector2:
	for shell in sim.traffic:
		var row: Dictionary = shell
		if str(row.get("kind", "")) == "pdo":
			return row.pos
	return Vector2.ZERO


## The ring touch swings the nose and the way-on onto the pad.
## Leaving the outbound heading pointed makes Helion Dock meters climb.
static func _face_pad(sim) -> void:
	var home: Vector2 = sim.beacon_pos - sim.player.pos
	if home.length() <= 8.0:
		return
	var dir := home.normalized()
	sim.player.rot = dir.angle()
	var spd: float = sim.player.vel.length()
	if spd > 1.0:
		sim.player.vel = dir * spd


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
			_face_pad(sim)
	_cue_return(sim)
	if bool(sim.quest_flags.get("dock_haul_ring", false)) and at_pad(sim):
		sim.spend_cargo(CRATE, 1)
		sim.quest_flags.dock_haul = "done"
		sim.quest_flags.dock_haul_ring = false
		_pay(sim, HAUL_PAY, "Ring haul filed. Helion Dock paid %d." % HAUL_PAY)


static func _pulse_salvage(sim) -> void:
	if state(sim, "dock_salvage") != "active":
		return
	if str(sim.defs.system.id) != "HC-V1-R1-S1":
		return
	if bool(sim.quest_flags.get("dock_salvage_cut", false)) == false and at_pad(sim) == false and _near_hold(sim):
		sim.quest_flags.dock_salvage_cut = true
		sim.quest_flags.salvage_back_bucket = -999
		sim.say("Seized Hold has the tag. Bring it back to the Helion pad.")
	_cue_salvage(sim)
	if bool(sim.quest_flags.get("dock_salvage_cut", false)) and at_pad(sim):
		sim.quest_flags.dock_salvage = "done"
		sim.quest_flags.dock_salvage_cut = false
		_pay(sim, SALVAGE_PAY, "Tow tag filed. Helion Dock paid %d." % SALVAGE_PAY)


static func _steer(sim, world: Vector2) -> void:
	if sim.player.is_empty() or world == Vector2.ZERO:
		return
	var face: Vector2 = world - sim.player.pos
	if face.length() <= 8.0:
		return
	var dir := face.normalized()
	sim.player.rot = dir.angle()
	var spd: float = sim.player.vel.length()
	if spd > 1.0 and sim.player.vel.normalized().dot(dir) < 0.45:
		sim.player.vel = dir * spd


static func _pulse_escort(sim) -> void:
	if state(sim, "dock_escort") != "active":
		return
	if str(sim.defs.system.id) != "HC-V1-R1-S1":
		return
	# The cutter orbits. A heading taken once points outward within a few seconds.
	if bool(sim.quest_flags.get("dock_escort_met", false)):
		_steer(sim, sim.beacon_pos)
	else:
		_steer(sim, cutter_pos(sim))
	if bool(sim.quest_flags.get("dock_escort_met", false)) == false and at_pad(sim) == false and _near_cutter(sim):
		sim.quest_flags.dock_escort_met = true
		sim.quest_flags.escort_back_bucket = -999
		sim.say("The Compact cutter saw the keel. Bring it back to the Helion pad.")
	_cue_escort(sim)
	if bool(sim.quest_flags.get("dock_escort_met", false)) and at_pad(sim):
		sim.quest_flags.dock_escort = "done"
		sim.quest_flags.dock_escort_met = false
		_pay(sim, ESCORT_PAY, "Lane show filed. Helion Dock paid %d." % ESCORT_PAY)


static func _cue_salvage(sim) -> void:
	var line := salvage_line(sim)
	if line == "":
		return
	var bucket := int(sim.player.pos.distance_to(sim.trash_pos if bool(sim.quest_flags.get("dock_salvage_cut", false)) == false else sim.beacon_pos) / 60)
	var key := "salvage_back_bucket" if bool(sim.quest_flags.get("dock_salvage_cut", false)) else "salvage_cue_bucket"
	if int(sim.quest_flags.get(key, -999)) == bucket:
		return
	sim.quest_flags[key] = bucket
	sim.say(line)


static func _cue_escort(sim) -> void:
	var line := escort_line(sim)
	if line == "":
		return
	var cutter := cutter_pos(sim)
	var anchor: Vector2 = sim.beacon_pos if bool(sim.quest_flags.get("dock_escort_met", false)) else cutter
	var bucket := int(sim.player.pos.distance_to(anchor) / 60)
	var key := "escort_back_bucket" if bool(sim.quest_flags.get("dock_escort_met", false)) else "escort_cue_bucket"
	if int(sim.quest_flags.get(key, -999)) == bucket:
		return
	sim.quest_flags[key] = bucket
	sim.say(line)


static func holding(sim) -> int:
	return int(sim.player.cargo.get(GOOD, 0))


static func buy_good(sim) -> String:
	if not at_pad(sim):
		return "The Helion market stands on the pad."
	if purse(sim) < BUY_PRICE:
		return "Purse is short of %d for glasswheat." % BUY_PRICE
	var stats: Dictionary = Fit.stats(sim.defs, sim.player)
	if Fit.cargo_used(sim.player) >= int(stats.cargo_cap):
		return "The hold is full."
	sim.quest_flags.purse = purse(sim) - BUY_PRICE
	sim._add_cargo(GOOD, 1)
	sim.say("Bought glasswheat for %d. Purse %d." % [BUY_PRICE, purse(sim)])
	return ""


static func sell_good(sim) -> String:
	if not at_pad(sim):
		return "The Helion market stands on the pad."
	if not sim.spend_cargo(GOOD, 1):
		return "No glasswheat in the hold."
	_pay(sim, SELL_PRICE, "Sold glasswheat for %d." % SELL_PRICE)
	return ""


static func tag_of(sim) -> String:
	if sim == null or sim.player.is_empty():
		return ""
	return str(sim.player.get("corp_tag", "")).strip_edges()


static func clip_tag(raw: String) -> String:
	var text := raw.strip_edges()
	var out := ""
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		var ok := ch == " " or ch == "-" or (ch >= "0" and ch <= "9")
		if ok == false:
			ok = (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z")
		if ok:
			out += ch
		if out.length() >= TAG_LEN:
			break
	return out.strip_edges()


static func set_tag(sim, raw: String) -> String:
	var clean := clip_tag(raw)
	sim.player.corp_tag = clean
	if clean == "":
		sim.say("Corp tag cleared.")
	else:
		sim.say("Corp tag set to %s." % clean)
	return clean


static func _near_hold(sim) -> bool:
	if sim.trash_pos == Vector2.ZERO:
		return false
	return sim.player.pos.distance_to(sim.trash_pos) <= HOLD_REACH


static func _near_cutter(sim) -> bool:
	var at := cutter_pos(sim)
	if at == Vector2.ZERO:
		return false
	return sim.player.pos.distance_to(at) <= CUTTER_REACH


static func _near_ring(sim) -> bool:
	var ring = sim.survey_node("aegis_ring")
	if ring == null:
		return false
	return sim.player.pos.distance_to(ring.pos) <= RING


static func _pay(sim, amount: int, line: String) -> void:
	var next := purse(sim) + amount
	sim.quest_flags.purse = next
	sim.say("%s Purse %d." % [line, next])
