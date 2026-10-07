class_name CraftOrders
extends RefCounted

const LAYERS = ["orbit", "atmosphere", "surface", "crust", "biosign", "ruins", "legal"]


static func launch(sim, def_id: String) -> String:
	if def_id == "":
		return "This keel has no boat in the rack."
	if def_id == "salvage_tender":
		return _launch_tender(sim)
	if def_id == "livestock_lighter":
		return _launch_lighter(sim)
	var craft = _first_docked(sim, def_id)
	if craft == null:
		var any = _any_of(sim, def_id)
		if any == null:
			return "This keel has no %s." % _pretty(def_id)
		if str(any.state) == "lost":
			return "%s is lost. Rebuild it from returned mass." % any.name
		return "%s is already out." % any.name
	match def_id:
		"survey_probe":
			var place = _next_scan_target(sim)
			if place == null:
				return "No node left to put a probe on."
			return order(sim, str(craft.uid), "scan", str(place.id))
		"harvest_drone":
			var place = _next_harvest_target(sim)
			if place == null:
				return "No surveyed seam. Read a dossier before you drop the drone."
			if sim.player.pos.distance_to(place.pos) > one_way_range(craft):
				return "Harvester stays in the neighborhood. Bring the keel closer to %s." % place.name
			return order(sim, str(craft.uid), "launch", str(place.id))
		"away_shuttle":
			_depart(sim, craft, str(sim.defs.system.pocket.id))
			craft.order = "walk"
			sim.say("Shuttle away to %s." % sim.defs.system.pocket.name)
			sim.sfx("launch")
			return ""
		"fighter":
			return order(sim, str(craft.uid), "launch", "")
	return "That craft has no order on the board."


static func order(sim, uid: String, verb: String, node_id: String) -> String:
	var craft = _by_uid(sim, uid)
	if craft == null:
		return "That rack slot is empty."
	if verb == "rebuild":
		return rebuild(sim, uid)
	if verb == "return":
		if str(craft.state) == "lost":
			return "%s is lost. Rebuild it from returned mass." % craft.name
		if str(craft.state) == "docked":
			return "%s is already in the rack." % craft.name
		if sim.hangar_down():
			return "The hangar is down. Craft cannot come aboard."
		craft.state = "returning"
		craft.order = "return"
		sim.say("%s recalled." % craft.name)
		if str(sim.player.get("agent_id", "")) == str(sim.claim.get("agent_id", "")):
			Homestead.abort_crack(sim, "recall")
		return ""
	if str(craft.def_id) == "salvage_tender":
		return _order_tender(sim, craft, node_id)
	if str(craft.def_id) == "livestock_lighter":
		return _order_lighter(sim, craft)
	if str(craft.state) == "lost":
		return "%s is lost. Rebuild it from returned mass." % craft.name
	if str(craft.def_id) == "fighter":
		return _order_fighter(sim, craft, verb)
	var place = sim.survey_node(node_id)
	if place == null:
		return "Pick a node first."
	if str(craft.def_id) == "harvest_drone":
		if not sim.dossier_complete(node_id):
			return "Scan %s before the drone cuts it." % place.name
		if int(sim.deposits.get(node_id, 0)) <= 0:
			return "%s has nothing left to cut." % place.name
		if str(craft.state) == "docked" and sim.player.pos.distance_to(place.pos) > one_way_range(craft):
			return "Harvester stays in the neighborhood. Bring the keel closer to %s." % place.name
		_send(sim, craft, place, "cut")
		sim.say("Harvest drone dropped for %s." % place.name)
		sim.sfx("launch")
		return ""
	if str(craft.def_id) != "survey_probe":
		return "%s has no survey order." % craft.name
	if verb == "orbit":
		_send(sim, craft, place, "orbit")
		sim.say("%s ordered to orbit %s." % [craft.name, place.name])
		sim.sfx("launch")
		return ""
	if verb == "scan" or verb == "launch":
		_send(sim, craft, place, "scan")
		sim.say("%s away to scan %s." % [craft.name, place.name])
		sim.sfx("launch")
		return ""
	return "That order is not on the board."


static func rebuild(sim, uid: String) -> String:
	var craft = _by_uid(sim, uid)
	if craft == null:
		return "That rack slot is empty."
	if str(craft.state) != "lost":
		return "%s is still on the board." % craft.name
	if int(sim.player.cargo.get("raw_mass", 0)) < 1:
		return "Rebuild wants one unit of returned mass."
	sim.spend_cargo("raw_mass", 1)
	craft.state = "docked"
	craft.hp = float(craft.max_hp)
	craft.battery = float(craft.max_battery)
	craft.vel = Vector2.ZERO
	craft.pos = sim.player.pos
	craft.work = 0.0
	craft.layers_done = 0
	craft.did_job = false
	craft.target = ""
	craft.order = ""
	sim.say("%s rebuilt from returned mass." % craft.name)
	sim.sfx("install")
	return ""


static func recall(sim, uid: String) -> void:
	var message := order(sim, uid, "return", "")
	if message != "":
		sim.say(message)


static func fleet(sim, verb: String) -> String:
	if verb == "recall":
		return _fleet_recall(sim)
	if verb != "form" and verb != "attack":
		return "That order is not on the board."
	var wing: String = "attack" if verb == "attack" else "escort"
	var sent := 0
	var first := ""
	for craft in sim.craft:
		if str(craft.def_id) != "fighter":
			continue
		if str(craft.state) == "lost":
			if first == "":
				first = "%s is lost. Rebuild it from returned mass." % craft.name
			continue
		var message := order(sim, str(craft.uid), wing, "")
		if message == "":
			sent += 1
		elif first == "":
			first = message
	if sent > 0:
		return ""
	if first != "":
		return first
	return "No fighter is on the keel."


static func _fleet_recall(sim) -> String:
	var sent := 0
	var first := ""
	for craft in sim.craft:
		if str(craft.state) == "docked" or str(craft.state) == "lost":
			continue
		var message := order(sim, str(craft.uid), "return", "")
		if message == "":
			sent += 1
		elif first == "":
			first = message
	if sent > 0:
		return ""
	if first != "":
		return first
	return "Nothing is out to recall."


static func step(sim, craft, dt: float) -> void:
	if str(craft.state) == "docked" or str(craft.state) == "lost":
		return
	_hazards(sim, craft)
	if str(craft.state) == "lost":
		return
	craft.fire_cd = maxf(0.0, float(craft.fire_cd) - dt)
	var drain := float(craft.drain)
	if str(craft.def_id) == "fighter" and str(craft.state) == "escort":
		if craft.pos.distance_to(sim.player.pos) < 1100.0:
			drain = 0.0
	craft.battery = maxf(0.0, float(craft.battery) - drain * dt)
	if float(craft.battery) <= 8.0 and str(craft.state) != "returning":
		craft.state = "returning"
		craft.order = "return"
		sim.say("%s is short on battery and turning for the keel." % craft.name)
	match str(craft.def_id):
		"survey_probe":
			_step_probe(sim, craft, dt)
		"harvest_drone":
			_step_harvest(sim, craft, dt)
		"salvage_tender":
			_step_tender(sim, craft, dt)
		"livestock_lighter":
			_step_lighter(sim, craft, dt)
		"away_shuttle":
			_step_shuttle(sim, craft, dt)
		"fighter":
			_step_fighter(sim, craft, dt)
	if str(craft.state) != "lost":
		_hazards(sim, craft)
	if float(craft.hp) <= 0.0 and str(craft.state) != "lost":
		craft.state = "lost"
		craft.hp = 0.0
		ScaleFrame.mark_lost(sim, craft)
		sim.say("%s lost. Rebuild it from returned mass." % craft.name)
		sim.sfx("destroyed")


static func one_way_range(craft) -> float:
	var drain = float(craft.drain)
	if drain <= 0.01:
		return 99999.0
	var burn = float(craft.max_battery) * 0.42
	return burn / drain * float(craft.speed)


static func _step_probe(sim, craft, dt: float) -> void:
	var place = sim.survey_node(str(craft.target))
	if place == null:
		craft.state = "returning"
		_return_home(sim, craft, dt)
		return
	var order_name := str(craft.order)
	if str(craft.state) == "outbound":
		var dist = _fly_safe(sim, craft, _work_point(place, craft.pos), dt, float(craft.speed))
		craft.layer = ScaleFrame.CRAFT
		var fly_km: Vector2 = ScaleFrame.local_km(sim, craft.pos)
		craft.km_x = fly_km.x
		craft.km_y = fly_km.y
		if dist < 28.0:
			if order_name == "scan":
				craft.state = "working"
				craft.work = 0.0
				if sim.dossier_complete(str(place.id)):
					craft.work = 100.0
			else:
				craft.state = "orbiting"
	elif str(craft.state) == "orbiting":
		_fly_safe(sim, craft, _orbit_point(place, sim.time), dt, float(craft.speed) * 0.45)
		if order_name == "scan":
			craft.state = "working"
			craft.work = 0.0
	elif str(craft.state) == "working":
		_fly_safe(sim, craft, _work_point(place, craft.pos), dt, float(craft.speed) * 0.35)
		if order_name == "orbit":
			craft.state = "orbiting"
			return
		if sim.dossier_complete(str(place.id)) and float(craft.work) >= 100.0:
			craft.state = "returning"
			sim.say("Survey of %s still holds." % place.name)
			return
		var pace := ScaleFrame.scan_pace(sim, place)
		craft.work = float(craft.work) + dt / pace
		craft.layer = ScaleFrame.CRAFT
		var km: Vector2 = ScaleFrame.local_km(sim, craft.pos)
		craft.km_x = km.x
		craft.km_y = km.y
		var step_time = float(craft.work_step)
		var should = int(float(craft.work) / step_time)
		while int(craft.layers_done) < should and int(craft.layers_done) < LAYERS.size():
			var layer_name: String = LAYERS[int(craft.layers_done)]
			var fresh: bool = sim.reveal_layer(str(place.id), layer_name)
			craft.layers_done = int(craft.layers_done) + 1
			if fresh:
				sim.say("%s — %s." % [place.name, layer_name])
		if int(craft.layers_done) >= LAYERS.size():
			craft.state = "returning"
			sim.say("Dossier sealed: %s." % place.name)
			sim.sfx("scan_done")
	elif str(craft.state) == "returning":
		_return_home(sim, craft, dt)


static func _step_harvest(sim, craft, dt: float) -> void:
	var place = sim.survey_node(str(craft.target))
	if place == null:
		craft.state = "returning"
		_return_home(sim, craft, dt)
		return
	if str(craft.state) == "outbound":
		var dist = _fly_safe(sim, craft, _work_point(place, craft.pos), dt, float(craft.speed))
		if dist < 30.0:
			craft.state = "working"
			craft.work = 0.0
	elif str(craft.state) == "working":
		_fly_safe(sim, craft, _work_point(place, craft.pos), dt, float(craft.speed) * 0.25)
		craft.work = float(craft.work) + dt
		if float(craft.work) >= float(craft.work_step) and not bool(craft.did_job):
			craft.did_job = true
			var result = str(sim.try_extract(str(place.id)))
			if result == "full":
				sim.say("Hold is full. The drone is coming home empty.")
			elif result == "empty":
				sim.say("%s's seam is worked out." % place.name)
			craft.state = "returning"
	elif str(craft.state) == "returning":
		_return_home(sim, craft, dt)


static func _launch_tender(sim) -> String:
	var craft = _first_docked(sim, "salvage_tender")
	if craft == null:
		var any = _any_of(sim, "salvage_tender")
		if any == null:
			return "This keel has no Salvage Tender."
		if str(any.state) == "lost":
			return "Salvage Tender is lost. Rebuild it from returned mass."
		return "Salvage Tender is already out."
	var target := _salvage_mark(sim)
	if target == "":
		return "Salvage Tender stays parked until a wreck or a seized field is in reach."
	return order(sim, str(craft.uid), "strip", target)


static func _launch_lighter(sim) -> String:
	var craft = _first_docked(sim, "livestock_lighter")
	if craft == null:
		var any = _any_of(sim, "livestock_lighter")
		if any == null:
			return "This keel has no Livestock Lighter."
		if str(any.state) == "lost":
			return "Livestock Lighter is lost. Rebuild it from returned mass."
		return "Livestock Lighter is already out."
	if str(sim.player.class_id) != "anvil" and not sim.player.modules.has("lighter_dock"):
		return "The livestock lighter wants its dock on the keel."
	if not bool(sim.claim.get("owned", false)):
		return "No claim is holding kine."
	return order(sim, str(craft.uid), "haul", str(sim.claim.get("pocket_id", "")))


static func _order_tender(sim, craft, node_id: String) -> String:
	if str(craft.state) == "lost":
		return "%s is lost. Rebuild it from returned mass." % craft.name
	var wreck = sim.wreck_by_id(node_id)
	var place = sim.survey_node(node_id)
	if wreck == null and place == null:
		return "Point the tender at a wreck or a trash field."
	_depart(sim, craft, node_id)
	craft.order = "strip"
	if wreck != null:
		sim.say("Tender away to %s." % wreck.name)
	else:
		sim.say("Tender away to %s." % place.name)
	sim.sfx("launch")
	return ""


static func _order_lighter(sim, craft) -> String:
	if str(craft.state) == "lost":
		return "%s is lost. Rebuild it from returned mass." % craft.name
	_depart(sim, craft, str(sim.claim.get("pocket_id", "")))
	craft.order = "haul"
	sim.say("Lighter away to the claim.")
	sim.sfx("launch")
	return ""


static func _salvage_mark(sim) -> String:
	var best := ""
	var best_d := 720.0
	for wreck in sim.wrecks:
		if bool(wreck.get("stripped", false)):
			continue
		var dist: float = sim.player.pos.distance_to(wreck.pos)
		if dist < best_d:
			best = str(wreck.id)
			best_d = dist
	if best != "":
		return best
	var gyre := str(sim.defs.system.id) == "HC-V1-R6-S1"
	for row in sim.nodes:
		var kind := str(row.get("kind", ""))
		if kind != "trash" and kind != "stream":
			continue
		if not gyre and sim.player.pos.distance_to(row.pos) > 720.0:
			continue
		return str(row.id)
	return ""


static func _step_tender(sim, craft, dt: float) -> void:
	var wreck = sim.wreck_by_id(str(craft.target))
	var place = sim.survey_node(str(craft.target))
	if wreck == null and place == null:
		craft.state = "returning"
		_return_home(sim, craft, dt)
		return
	var aim: Vector2 = wreck.pos if wreck != null else place.pos
	if str(craft.state) == "outbound":
		var dist = _fly_safe(sim, craft, aim, dt, float(craft.speed))
		if dist < 28.0:
			craft.state = "working"
			craft.work = 0.0
	elif str(craft.state) == "working":
		_fly_safe(sim, craft, aim, dt, float(craft.speed) * 0.2)
		craft.work = float(craft.work) + dt
		if float(craft.work) >= float(craft.work_step) and not bool(craft.did_job):
			craft.did_job = true
			var result := "empty"
			if wreck != null:
				result = str(sim.try_salvage(str(wreck.id)))
			else:
				result = str(sim.try_field_salvage(str(place.id)))
			if result == "full":
				sim.say("Hold is full. The tender leaves the field where it is.")
				craft.did_job = false
			craft.state = "returning"
	else:
		_return_home(sim, craft, dt)


static func _step_lighter(sim, craft, dt: float) -> void:
	var aim: Vector2 = sim.pocket_pos
	if str(sim.claim.get("system_id", "")) == str(sim.defs.system.id):
		aim = Vector2(float(sim.claim.get("x", sim.pocket_pos.x)), float(sim.claim.get("y", sim.pocket_pos.y)))
	if str(craft.state) == "outbound":
		var dist = _fly_safe(sim, craft, aim, dt, float(craft.speed))
		if dist < 30.0:
			craft.state = "working"
			craft.work = 0.0
	elif str(craft.state) == "working":
		_fly_safe(sim, craft, aim, dt, 24.0)
		craft.work = float(craft.work) + dt
		if float(craft.work) >= float(craft.work_step) and not bool(craft.did_job):
			craft.did_job = true
			Homestead.lighter_transfer(sim)
			craft.state = "returning"
	else:
		_return_home(sim, craft, dt)


static func _step_shuttle(sim, craft, dt: float) -> void:
	if str(craft.state) == "outbound":
		var dist = _fly_safe(sim, craft, sim.pocket_pos, dt, float(craft.speed))
		if dist < 24.0:
			craft.state = "working"
			craft.work = 0.0
	elif str(craft.state) == "working":
		_fly_safe(sim, craft, sim.pocket_pos, dt, 30.0)
		craft.work = float(craft.work) + dt
		if float(craft.work) >= float(craft.work_step) and not bool(craft.did_job):
			craft.did_job = true
			PocketRules.confirm_walk(sim)
			craft.state = "returning"
	else:
		_return_home(sim, craft, dt)


static func escort_pose(sim, craft, index: int) -> Dictionary:
	var lead: Vector2 = sim.player.pos
	var now := _escort_offset(sim, craft, index, float(sim.time))
	var ahead := _escort_offset(sim, craft, index, float(sim.time) + 0.4)
	var delta: Vector2 = ahead - now
	var rot := float(sim.player.rot)
	if delta.length_squared() > 0.25:
		rot = delta.angle()
	var lift := 28.0 + float(index) * 12.0 + sin(float(sim.time) * 0.7 + float(index) * 1.3) * 10.0
	return {"pos": lead + now, "rot": rot, "height": lift}


static func _escort_offset(sim, craft, index: int, t: float) -> Vector2:
	var reach := float(Fit.stats(sim.defs, sim.player).hit_radius)
	var span := maxf(reach * 9.0, 280.0)
	var phase := float(absi(str(craft.get("uid", index)).hash()) % 1000) * 0.00628
	var kind := str(craft.get("def_id", ""))
	var slot := float(index)
	var nose := Vector2.from_angle(float(sim.player.rot))
	var side := Vector2(-nose.y, nose.x)
	var local := Vector2.RIGHT * span * 2.0
	if kind == "fighter":
		var flank := 1.0 if index % 2 == 0 else -1.0
		var wobble := t * 0.85 + phase
		var along := span * (0.15 + 0.55 * sin(wobble))
		var beam := flank * span * (2.05 + slot * 0.35) + sin(wobble * 0.5) * span * 0.22
		local = nose * along + side * beam
	elif kind == "survey_probe":
		var ang := t * (0.33 + slot * 0.05) + phase
		var ring := span * (2.35 + slot * 0.38)
		local = Vector2(cos(ang) * ring, sin(ang) * ring * 0.62)
	elif kind == "harvest_drone":
		var lap := t * 0.27 + phase + slot * 0.8
		var along := -span * (2.15 + 0.35 * sin(lap))
		var beam := sin(lap * 1.7) * span * (1.35 + slot * 0.2)
		local = nose * along + side * beam
	else:
		var ang := -t * (0.22 + slot * 0.04) + phase + slot
		var ring := span * (2.9 + slot * 0.42)
		local = Vector2(cos(ang), sin(ang)) * ring
	var body = sim.planet(str(sim.body_id))
	if body != null:
		var sky: Vector2 = sim.player.pos - Vector2(body.pos)
		if sky.length() > 1.0:
			sky = sky.normalized()
			var outward := local.dot(sky)
			if outward < span * 0.35:
				local += sky * (span * 0.35 - outward)
	if local.length() < span * 1.85:
		if local.length() < 1.0:
			local = Vector2.RIGHT
		local = local.normalized() * span * 1.85
	return local


static func _seat(sim, craft) -> int:
	var index := 0
	for item in sim.craft:
		if item == craft:
			return index
		index += 1
	return 0


static func _order_fighter(sim, craft, verb: String) -> String:
	if verb != "launch" and verb != "attack" and verb != "escort":
		return "That order is not on the board."
	var mark := ""
	if verb == "attack":
		mark = _attack_mark(sim)
	if str(craft.state) == "docked":
		_depart(sim, craft, mark)
	craft.state = "escort"
	craft.order = "attack" if verb == "attack" else "escort"
	craft.target = mark
	if verb == "attack" and mark != "":
		sim.say("%s breaks formation to attack." % craft.name)
	elif verb == "attack":
		sim.say("%s is out. It will hit whatever hunts the keel." % craft.name)
	else:
		sim.say("%s takes a station on the wing." % craft.name)
	sim.sfx("launch")
	return ""


static func _attack_mark(sim) -> String:
	var locked = HelmCombat.locked_unit(sim, sim.player)
	if locked != null and bool(locked.get("alive", false)):
		var team := str(locked.get("team", ""))
		if team != "captain" and team != "civilian":
			return str(locked.get("agent_id", ""))
	var hostile = sim.nearest_hostile(sim.player.pos, 1600.0)
	if hostile != null:
		return str(hostile.get("agent_id", ""))
	return ""


static func _fighter_quarry(sim, craft):
	if str(craft.get("order", "")) == "attack":
		var marked = HelmCombat.find_unit(sim, str(craft.get("target", "")))
		if marked != null and bool(marked.get("alive", false)):
			return marked
		craft.target = ""
	var locked = HelmCombat.locked_unit(sim, sim.player)
	if locked != null and bool(locked.get("alive", false)):
		var team := str(locked.get("team", ""))
		if team != "captain" and team != "civilian":
			return locked
	return sim.nearest_hostile(craft.pos, 1400.0)


static func _attack_slot(seat: int, target: Vector2, lead: Vector2) -> Vector2:
	var approach: Vector2 = lead - target
	if approach.length() < 1.0:
		approach = Vector2.RIGHT
	approach = approach.normalized()
	var side := Vector2(-approach.y, approach.x)
	var flank := 1.0 if seat % 2 == 0 else -1.0
	var ring := 1 + int(seat / 2)
	return target + approach * (170.0 + float(ring) * 40.0) + side * flank * (80.0 + float(seat) * 24.0)


static func _step_fighter(sim, craft, dt: float) -> void:
	if str(craft.state) == "returning" or float(craft.battery) <= 8.0:
		craft.state = "returning"
		_return_home(sim, craft, dt)
		return
	var seat := _seat(sim, craft)
	var catch := maxf(float(craft.speed), sim.player.vel.length() + 80.0)
	var hostile = _fighter_quarry(sim, craft)
	if hostile == null:
		var pose: Dictionary = escort_pose(sim, craft, seat)
		_fly_safe(sim, craft, pose.pos, dt, catch)
		return
	var slot := _attack_slot(seat, hostile.pos, sim.player.pos)
	var on_station: bool = craft.pos.distance_to(slot) < 48.0
	if on_station:
		var aim: Vector2 = hostile.pos - craft.pos
		if aim.length() > 1.0:
			craft.rot = aim.angle()
		craft.vel *= 0.9
	else:
		_fly_safe(sim, craft, slot, dt, float(craft.speed))
	if craft.pos.distance_to(hostile.pos) < float(craft.gun.range) and _facing(craft, hostile.pos) < 0.5:
		sim.try_fire(craft, craft.gun)


static func _return_home(sim, craft, dt: float) -> void:
	if not sim.player.alive:
		_fly_safe(sim, craft, sim.player.pos, dt, float(craft.speed))
		return
	var catch = maxf(float(craft.speed), sim.player.vel.length() + 90.0)
	if float(craft.battery) <= 0.0:
		catch = 70.0
	var dist = _fly_safe(sim, craft, sim.player.pos, dt, catch)
	if dist < 46.0:
		if sim.hangar_down():
			if not bool(craft.get("hangar_said", false)):
				craft.hangar_said = true
				sim.say("The hangar is down. %s cannot come aboard." % craft.name)
			return
		_dock(sim, craft)
		sim.say("%s is back in the rack." % craft.name)
		sim.sfx("dock")


static func _dock(sim, craft) -> void:
	craft.state = "docked"
	craft.battery = float(craft.max_battery)
	craft.vel = Vector2.ZERO
	craft.pos = sim.player.pos
	craft.work = 0.0
	craft.layers_done = 0
	craft.did_job = false
	craft.target = ""
	craft.order = ""


static func _depart(sim, craft, target: String) -> void:
	craft.state = "outbound"
	craft.target = target
	craft.pos = sim.player.pos + Vector2.from_angle(sim.player.rot) * 36.0
	craft.vel = sim.player.vel
	craft.rot = sim.player.rot
	craft.work = 0.0
	craft.layers_done = 0
	craft.did_job = false


static func _send(sim, craft, place, order_name: String) -> void:
	var same := str(craft.target) == str(place.id) and str(craft.state) != "docked"
	if str(craft.state) == "docked":
		_depart(sim, craft, str(place.id))
	elif not same:
		craft.target = str(place.id)
		craft.layers_done = 0
		craft.work = 0.0
		craft.did_job = false
		craft.state = "outbound"
	craft.order = order_name
	craft.target = str(place.id)
	if same and order_name == "scan" and str(craft.state) == "orbiting":
		craft.state = "working"
		craft.work = 0.0
	elif same and order_name == "orbit" and str(craft.state) == "working":
		craft.state = "orbiting"
	elif same and order_name == "cut" and str(craft.state) == "returning":
		craft.state = "outbound"
		craft.did_job = false
		craft.work = 0.0


static func _fly_safe(sim, craft, target: Vector2, dt: float, speed: float) -> float:
	return _fly_toward(craft, _avoid(sim, craft, target), dt, speed)


static func _avoid(sim, craft, target: Vector2) -> Vector2:
	var pos: Vector2 = craft.pos
	var pad := float(craft.radius) + 18.0
	for body in sim.planets:
		if _segment_hits(pos, target, body.pos, float(body.radius) + pad):
			return _slide(pos, target, body.pos)
	var star_r := float(sim.defs.system.star.radius) + pad
	if _segment_hits(pos, target, Vector2.ZERO, star_r):
		return _slide(pos, target, Vector2.ZERO)
	for actor in sim.actors:
		if not bool(actor.get("alive", false)):
			continue
		if str(actor.team) != sim._pdo_id():
			continue
		var hull := float(Fit.stats(sim.defs, actor).hit_radius) + float(craft.radius) + 20.0
		if _segment_hits(pos, target, actor.pos, hull):
			return _slide(pos, target, actor.pos)
	return target


static func _slide(pos: Vector2, target: Vector2, center: Vector2) -> Vector2:
	var away := pos - center
	if away.length() < 1.0:
		away = Vector2.RIGHT
	var tangent := Vector2(-away.y, away.x).normalized()
	if tangent.dot(target - pos) < 0.0:
		tangent = -tangent
	return pos + tangent * 180.0 + away.normalized() * 36.0


static func _segment_hits(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 1.0:
		return a.distance_to(center) < radius
	var t := clampf((center - a).dot(ab) / len2, 0.0, 1.0)
	var closest := a + ab * t
	return closest.distance_to(center) < radius


static func _hazards(sim, craft) -> void:
	var pos: Vector2 = craft.pos
	var reach := float(craft.radius)
	if pos.length() < float(sim.defs.system.star.radius) + reach:
		_lose(sim, craft, "star")
		return
	for body in sim.planets:
		if pos.distance_to(body.pos) < float(body.radius) + reach:
			_lose(sim, craft, "planet")
			return
	for actor in sim.actors:
		if not bool(actor.get("alive", false)):
			continue
		if str(actor.team) != sim._pdo_id():
			continue
		var hull := float(Fit.stats(sim.defs, actor).hit_radius)
		if pos.distance_to(actor.pos) < hull + reach:
			_lose(sim, craft, "patrol")
			return


static func _lose(sim, craft, why: String) -> void:
	craft.hp = 0.0
	craft.state = "lost"
	craft.vel = Vector2.ZERO
	sim.say("%s lost in the %s. Rebuild it from returned mass." % [craft.name, why])
	sim.sfx("destroyed")


static func _fly_toward(craft, target: Vector2, dt: float, speed: float) -> float:
	var to = target - craft.pos
	var dist = to.length()
	if dist <= 1.0:
		craft.pos = target
		craft.vel = Vector2.ZERO
		return 0.0
	var dir = to / dist
	craft.rot = dir.angle()
	var step = speed * dt
	if step >= dist:
		craft.pos = target
		craft.vel = dir * speed
		return 0.0
	craft.pos += dir * step
	craft.vel = dir * speed
	return dist - step


static func _work_point(place, from: Vector2) -> Vector2:
	if bool(place.get("solid", false)):
		var dir: Vector2 = from - place.pos
		if dir.length() < 1.0:
			dir = Vector2.RIGHT
		return place.pos + dir.normalized() * (float(place.radius) + 72.0)
	return place.pos


static func _orbit_point(place, time: float) -> Vector2:
	var spin := Vector2.from_angle(time * 0.7)
	if bool(place.get("solid", false)):
		return place.pos + spin * (float(place.radius) + 72.0)
	return place.pos + spin * 22.0


static func _facing(craft, target: Vector2) -> float:
	return absf(wrapf((target - craft.pos).angle() - float(craft.rot), -PI, PI))


static func _first_docked(sim, def_id: String):
	for craft in sim.craft:
		if str(craft.def_id) == def_id and str(craft.state) == "docked":
			return craft
	return null


static func _any_of(sim, def_id: String):
	for craft in sim.craft:
		if str(craft.def_id) == def_id:
			return craft
	return null


static func _by_uid(sim, uid: String):
	for craft in sim.craft:
		if str(craft.uid) == uid:
			return craft
	return null


static func _next_scan_target(sim):
	# The dock slip is Aegis Prime. From the pad the ice ring is closer,
	# and a nearest-node launch sealed that ring and left the purse at 0.
	if DockBoard.state(sim, "dock_scan") == "active" and sim.dossier_complete("aegis_prime") == false:
		var prime = sim.survey_node("aegis_prime")
		if prime != null and _targeted(sim, "aegis_prime") == false:
			return prime
	var best = null
	var best_dist = 1.0e12
	for place in sim.nodes:
		if _targeted(sim, str(place.id)):
			continue
		if sim.dossier_complete(str(place.id)):
			continue
		var dist = sim.player.pos.distance_to(place.pos)
		if dist < best_dist:
			best_dist = dist
			best = place
	if best != null:
		return best
	best_dist = 1.0e12
	for place in sim.nodes:
		if _targeted(sim, str(place.id)):
			continue
		var dist = sim.player.pos.distance_to(place.pos)
		if dist < best_dist:
			best_dist = dist
			best = place
	return best


static func _next_harvest_target(sim):
	var best = null
	var best_dist = 1.0e12
	for place in sim.nodes:
		if not sim.dossier_complete(str(place.id)):
			continue
		if int(sim.deposits.get(place.id, 0)) <= 0:
			continue
		var dist = sim.player.pos.distance_to(place.pos)
		if dist < best_dist:
			best_dist = dist
			best = place
	return best


static func _nearest_wreck(sim):
	var best = null
	var best_dist = 1.0e12
	for wreck in sim.wrecks:
		if bool(wreck.stripped):
			continue
		var dist = sim.player.pos.distance_to(wreck.pos)
		if dist < best_dist:
			best_dist = dist
			best = wreck
	return best


static func _targeted(sim, node_id: String) -> bool:
	for craft in sim.craft:
		if str(craft.def_id) != "survey_probe":
			continue
		if str(craft.state) == "docked" or str(craft.state) == "lost":
			continue
		if str(craft.target) == node_id:
			return true
	return false


static func _pretty(def_id: String) -> String:
	return def_id.replace("_", " ")
