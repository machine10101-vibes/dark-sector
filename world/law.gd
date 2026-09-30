class_name Law
extends RefCounted

## Green, amber, and red on the same chart. Crime uses the heat slate.


static func at(sim, pos: Vector2) -> String:
	var layer := int(sim.layer)
	if layer == ScaleFrame.CHART or layer == ScaleFrame.APPROACH:
		return _transit_law(sim, pos)
	if str(sim.defs.system.get("law_color", "")) == "red":
		return "red"
	var red := _red_box(sim)
	if not red.is_empty() and pos.distance_to(red.pos) <= float(red.radius):
		return "red"
	var ice := _ice_band(sim)
	if not ice.is_empty():
		var span: float = pos.distance_to(ice.pos)
		if span >= float(ice.inner) and span <= float(ice.outer):
			return "amber"
	if _in_trash(sim, pos):
		if _compact_on_trash(sim):
			return "green"
		return "amber"
	if _in_green(sim, pos):
		return "green"
	var country := _claim_country(sim)
	if not country.is_empty() and pos.distance_to(country.pos) <= float(country.radius):
		return "amber"
	var pocket_r := float(sim.defs.system.pocket.get("radius", 0.0))
	if bool(sim.defs.system.pocket.get("plantable", false)) and pos.distance_to(sim.pocket_pos) <= pocket_r:
		return "amber"
	if str(sim.defs.system.get("law_color", "")) == "amber":
		return "amber"
	return "dark"


static func hud_line(sim, pos: Vector2) -> String:
	match at(sim, pos):
		"green":
			return "GREEN — Compact law. A shot on a captain brings the patrol."
		"amber":
			return "AMBER — lease, claim country, or an unwatched trash field."
		"red":
			return "RED — Perimeter road. Wreck rights. No incoming law."
		_:
			return "DARK — unpatrolled."


static func color_of(law: String) -> Color:
	match law:
		"green":
			return Color("8fbf8a")
		"amber":
			return Color("c4923a")
		"red":
			return Color("c4512c")
		_:
			return Color("8a8070")


static func discs(sim) -> Array:
	var out: Array = []
	for row in _green_zones(sim):
		out.append(row)
	var ice := _ice_band(sim)
	if not ice.is_empty():
		out.append({
			"kind": "amber",
			"pos": ice.pos,
			"radius": ice.outer,
			"inner": ice.inner,
			"label": "Amber — ice ring lease",
		})
	if int(sim.defs.system.get("trash", {}).get("count", 0)) > 0:
		var spread := float(sim.defs.system.trash.get("spread", 150.0)) + 40.0
		var watched := _compact_on_trash(sim)
		var field_name := str(sim.defs.system.trash.get("name", "Trash field"))
		var label := "%s — amber, Compact off site" % field_name
		if watched:
			label = "%s — green, Compact on site" % field_name
		out.append({
			"kind": "green" if watched else "amber",
			"pos": sim.trash_pos,
			"radius": spread,
			"inner": 0.0,
			"label": label,
		})
	var country := _claim_country(sim)
	if not country.is_empty():
		out.append({
			"kind": "amber",
			"pos": country.pos,
			"radius": country.radius,
			"inner": 0.0,
			"label": "Amber — First Soil claim country",
		})
	var red := _red_box(sim)
	if not red.is_empty():
		out.append({
			"kind": "red",
			"pos": red.pos,
			"radius": red.radius,
			"inner": 0.0,
			"label": str(red.label),
		})
	return out


static func muzzle_clean(sim, unit: Dictionary) -> bool:
	var where := at(sim, unit.pos)
	if where == "red":
		return true
	if where != "amber":
		return false
	if _claim_fight(sim, unit.pos):
		return true
	if bool(unit.get("flagged", false)) and _other_flagged(sim, unit):
		return true
	return false


static func on_captain_hit(sim, attacker: Dictionary, victim: Dictionary) -> void:
	if str(attacker.get("agent_id", "")) == str(victim.get("agent_id", "")):
		return
	var where := at(sim, victim.pos)
	if where == "red":
		sim.say("Red ground. The wreck is rights. No slate.")
		return
	if where == "dark":
		return
	if where == "amber":
		if _amber_legal(sim, attacker, victim):
			sim.say("Amber fight. Flagged, or the claim is in it. The slate stays shut.")
			return
		_charge(sim, attacker, 12.0, "amber_offense", false)
		sim.say("Amber offense. The slate notes it. Not a warrant.")
		return
	_charge(sim, attacker, 40.0, "fired_on_player", true)
	attacker.warrant = true
	if str(attacker.get("agent_id", "")) == str(sim.player.agent_id):
		sim.quest_flags.warrant = true
		sim.pdo_alert = true
	else:
		attacker.alert = true
	sim.law_target = str(attacker.agent_id)
	sim.banner = "%s: \"You fired in the green. Warrant.\"" % sim._pdo_name()
	sim.banner_t = 0.0
	sim.say("The patrol turns on the shot. This is not a fine. It is guns.")
	sim.sfx("hail")


static func scan_tag(sim, ship: Dictionary) -> String:
	if bool(ship.get("warrant", false)):
		return "WARRANT"
	var heat_v := _heat_value(sim, ship)
	if heat_v >= 40.0:
		return "WARRANT"
	if bool(ship.get("flagged", false)):
		return "flagged"
	return ""


static func in_grace(sim, unit: Dictionary) -> bool:
	if str(unit.get("controller", "")) != "human":
		return false
	if float(unit.get("grace_t", 0.0)) <= 0.0:
		return false
	return str(sim.defs.system.id) == "HC-V1-R1-S1"


static func _charge(sim, unit: Dictionary, amount: float, reason: String, guns: bool) -> void:
	var faction: String = sim._pdo_id()
	if str(unit.get("agent_id", "")) == str(sim.player.agent_id):
		Ownership.add_heat(sim, faction, amount, reason, str(unit.agent_id))
		unit.heat_compact = float(sim.heat.get(faction, 0.0))
		if guns:
			unit.alert = true
		return
	unit.heat_compact = float(unit.get("heat_compact", 0.0)) + amount
	if guns:
		unit.alert = true
		unit.warrant = true


static func _heat_value(sim, ship: Dictionary) -> float:
	if str(ship.get("agent_id", "")) == str(sim.player.get("agent_id", "")):
		return float(sim.heat.get(sim._pdo_id(), 0.0))
	return float(ship.get("heat_compact", 0.0))


static func _amber_legal(sim, attacker: Dictionary, victim: Dictionary) -> bool:
	if bool(attacker.get("flagged", false)) and bool(victim.get("flagged", false)):
		return true
	if _claim_fight(sim, victim.pos) or _claim_fight(sim, attacker.pos):
		return true
	return false


static func _claim_fight(sim, pos: Vector2) -> bool:
	if not bool(sim.claim.get("owned", false)) or bool(sim.claim.get("frozen", false)):
		return false
	if str(sim.claim.get("agent_id", "")) == "":
		return false
	if str(sim.claim.get("system_id", "")) != str(sim.defs.system.id):
		return false
	var reach := float(sim.defs.system.pocket.get("radius", 0.0))
	if pos.distance_to(sim.pocket_pos) <= reach:
		return true
	var core := Vector2(float(sim.claim.get("x", sim.pocket_pos.x)), float(sim.claim.get("y", sim.pocket_pos.y)))
	return pos.distance_to(core) <= reach


static func _other_flagged(sim, unit: Dictionary) -> bool:
	var others: Array = []
	if str(sim.player.agent_id) != str(unit.get("agent_id", "")):
		others.append(sim.player)
	for mate in sim.captains:
		if str(mate.agent_id) != str(unit.get("agent_id", "")):
			others.append(mate)
	for other in others:
		if not bool(other.get("flagged", false)):
			continue
		if unit.pos.distance_to(other.pos) < 900.0:
			return true
	return false


static func _transit_law(sim, pos: Vector2) -> String:
	# Chart and approach positions are kilometers. The band discs are meters
	# around Aegis, so a numeric overlap used to read green while the keel
	# was still a sector away from the pad.
	var painted := str(sim.defs.system.get("law_color", ""))
	if painted == "red":
		return "red"
	var home = sim.planet(str(sim.defs.system.get("pdo", {}).get("home", "")))
	var world := pos
	if int(sim.layer) == ScaleFrame.APPROACH:
		var focus = sim.planet(str(sim.body_id))
		if focus != null:
			world = focus.chart_km + pos
	else:
		world = sim.local_origin + pos
	if home != null and sim.in_dock_approach(world):
		return "green"
	if painted == "amber":
		return "amber"
	return "dark"


static func _in_green(sim, pos: Vector2) -> bool:
	var body = sim.planet(str(sim.defs.system.zones.green.anchor))
	var reach := float(sim.defs.system.zones.green.radius)
	if body != null and reach > 1.0 and pos.distance_to(body.pos) <= reach:
		return true
	if str(sim.defs.system.id) == "HC-V1-R1-S1":
		for gate in sim.gates:
			var row: Dictionary = gate
			var disc := float(row.get("radius", 80.0)) + 220.0
			if pos.distance_to(row.pos) <= disc:
				return true
		return false
	for gate in sim.gates:
		var lane: Dictionary = gate
		if str(lane.get("color", "")) != "green":
			continue
		var reach_lane := float(lane.get("radius", 80.0)) + 160.0
		if pos.distance_to(lane.pos) <= reach_lane:
			return true
	return false


static func _in_trash(sim, pos: Vector2) -> bool:
	if int(sim.defs.system.get("trash", {}).get("count", 0)) <= 0:
		return false
	var spread := float(sim.defs.system.trash.get("spread", 150.0)) + 40.0
	return pos.distance_to(sim.trash_pos) <= spread


static func _compact_on_trash(sim) -> bool:
	if not _in_trash(sim, sim.trash_pos):
		return false
	var spread := float(sim.defs.system.trash.get("spread", 150.0)) + 80.0
	var faction := str(sim.defs.system.pdo.get("faction", ""))
	for actor in sim.actors:
		if not bool(actor.get("alive", false)):
			continue
		if str(actor.team) != faction:
			continue
		if actor.pos.distance_to(sim.trash_pos) <= spread:
			return true
	return false


static func _ice_band(sim) -> Dictionary:
	for body in sim.planets:
		if not bool(body.get("ring", false)):
			continue
		if str(body.get("ring_kind", "")) != "ice":
			continue
		var radius := float(body.radius)
		return {"pos": body.pos, "inner": radius + 24.0, "outer": radius + 70.0}
	return {}


static func _claim_country(sim) -> Dictionary:
	if str(sim.defs.system.id) != "HC-V1-R5-S1":
		return {}
	var body = sim.planet("green_wound")
	if body == null:
		return {}
	return {"pos": body.pos, "radius": 1200.0}


static func _red_box(sim) -> Dictionary:
	var law: Dictionary = sim.defs.system.get("law", {})
	var red: Dictionary = law.get("red", {})
	if red.is_empty():
		return {}
	var anchor = sim.planet(str(red.get("anchor", "")))
	var origin := Vector2.ZERO
	if anchor != null:
		origin = anchor.pos
	var pos := origin + Vector2.from_angle(float(red.get("angle", 0.0))) * float(red.get("distance", 0.0))
	return {
		"pos": pos,
		"radius": float(red.get("radius", 400.0)),
		"label": "%s — red — %s" % [str(red.get("name", "Red")), str(red.get("atlas", ""))],
	}


static func _green_zones(sim) -> Array:
	var out: Array = []
	var body = sim.planet(str(sim.defs.system.zones.green.anchor))
	var reach := float(sim.defs.system.zones.green.radius)
	if body != null and reach > 1.0:
		out.append({
			"kind": "green",
			"pos": body.pos,
			"radius": reach,
			"inner": 0.0,
			"label": "Green — Aegis orbit",
		})
	if str(sim.defs.system.id) == "HC-V1-R1-S1":
		for gate in sim.gates:
			var row: Dictionary = gate
			out.append({
				"kind": "green",
				"pos": row.pos,
				"radius": float(row.get("radius", 80.0)) + 220.0,
				"inner": 0.0,
				"label": "Green — %s" % str(row.get("name", "lane")),
			})
	else:
		for gate in sim.gates:
			var lane: Dictionary = gate
			if str(lane.get("color", "")) != "green":
				continue
			out.append({
				"kind": "green",
				"pos": lane.pos,
				"radius": float(lane.get("radius", 80.0)) + 160.0,
				"inner": 0.0,
				"label": "Green — %s" % str(lane.get("name", "lane")),
			})
	if str(sim.defs.system.get("law_color", "")) == "red":
		out.append({
			"kind": "red",
			"pos": Vector2.ZERO,
			"radius": 4200.0,
			"inner": 0.0,
			"label": "Red — %s" % str(sim.defs.system.name),
		})
	return out
