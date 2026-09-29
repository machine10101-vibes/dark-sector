class_name CraftOrders
extends RefCounted

const LAYERS = ["orbit", "atmosphere", "surface", "crust", "biosign", "ruins", "legal"]


static func launch(sim, def_id: String) -> String:
	var craft = _first_docked(sim, def_id)
	if craft == null:
		var any = _any_of(sim, def_id)
		if any == null:
			return "This keel has no %s." % _pretty(def_id)
		if str(any.state) == "lost":
			return "%s is a write-off. Nothing aboard can rebuild it yet." % any.name
		return "%s is already out." % any.name
	match def_id:
		"survey_probe":
			var planet = _next_scan_target(sim)
			if planet == null:
				return "No world left to put a probe on."
			_depart(sim, craft, str(planet.id))
			sim.say("%s away for %s." % [craft.name, planet.name])
			sim.sfx("launch")
			return ""
		"harvest_drone":
			var node = _next_harvest_target(sim)
			if node == null:
				return "No surveyed seam. Read a dossier before you drop the drone."
			if sim.player.pos.distance_to(node.pos) > one_way_range(craft):
				return "Harvester stays in the neighborhood. Bring the keel closer to %s." % node.name
			_depart(sim, craft, str(node.id))
			sim.say("Harvest drone dropped for %s." % node.name)
			sim.sfx("launch")
			return ""
		"salvage_tender":
			var wreck = _nearest_wreck(sim)
			if wreck == null:
				return "No wreck in the dark worth a tender."
			if sim.player.pos.distance_to(wreck.pos) > one_way_range(craft) * 1.4:
				return "Tender wants the wreck closer. The keel has to do the crossing."
			_depart(sim, craft, str(wreck.id))
			sim.say("Tender out to strip %s." % wreck.name)
			sim.sfx("launch")
			return ""
		"fighter":
			_depart(sim, craft, "")
			craft.state = "escort"
			sim.say("Fighter clear of the throat.")
			sim.sfx("launch")
			return ""
		"away_shuttle":
			_depart(sim, craft, "hollow_latch")
			sim.say("Shuttle away to walk Hollow Latch.")
			sim.sfx("launch")
			return ""
	return "That craft has no order on the board."


static func recall(sim, uid: String) -> void:
	for craft in sim.craft:
		if str(craft.uid) == uid and str(craft.state) != "docked" and str(craft.state) != "lost":
			craft.state = "returning"
			sim.say("%s recalled." % craft.name)
			return


static func step(sim, craft, dt: float) -> void:
	if str(craft.state) == "docked" or str(craft.state) == "lost":
		return
	craft.fire_cd = maxf(0.0, float(craft.fire_cd) - dt)
	craft.battery = maxf(0.0, float(craft.battery) - float(craft.drain) * dt)
	if float(craft.battery) <= 8.0 and str(craft.state) != "returning":
		craft.state = "returning"
		sim.say("%s is short on battery and turning for the keel." % craft.name)
	match str(craft.def_id):
		"survey_probe":
			_step_probe(sim, craft, dt)
		"harvest_drone":
			_step_harvest(sim, craft, dt)
		"salvage_tender":
			_step_tender(sim, craft, dt)
		"away_shuttle":
			_step_shuttle(sim, craft, dt)
		"fighter":
			_step_fighter(sim, craft, dt)
	if float(craft.hp) <= 0.0 and str(craft.state) != "lost":
		craft.state = "lost"
		craft.hp = 0.0
		sim.say("%s lost. Write it off the board." % craft.name)
		sim.sfx("destroyed")


static func one_way_range(craft) -> float:
	var drain = float(craft.drain)
	if drain <= 0.01:
		return 99999.0
	var burn = float(craft.max_battery) * 0.42
	return burn / drain * float(craft.speed)


static func _step_probe(sim, craft, dt: float) -> void:
	var planet = sim.planet(str(craft.target))
	if planet == null:
		craft.state = "returning"
	if str(craft.state) == "outbound":
		var dist = _fly_toward(craft, _orbit_point(planet, craft.pos), dt, float(craft.speed))
		if dist < 28.0:
			craft.state = "working"
			craft.work = 0.0
			if sim.dossier_complete(str(planet.id)):
				craft.work = 100.0
	elif str(craft.state) == "working":
		_fly_toward(craft, _orbit_point(planet, sim.player.pos), dt, float(craft.speed) * 0.35)
		if sim.dossier_complete(str(planet.id)) and float(craft.work) >= 100.0:
			craft.state = "returning"
			sim.say("Survey of %s still holds." % planet.name)
			return
		craft.work = float(craft.work) + dt
		var step_time = float(craft.work_step)
		var should = int(float(craft.work) / step_time)
		while int(craft.layers_done) < should and int(craft.layers_done) < LAYERS.size():
			var layer_name: String = LAYERS[int(craft.layers_done)]
			var fresh: bool = sim.reveal_layer(str(planet.id), layer_name)
			craft.layers_done = int(craft.layers_done) + 1
			if fresh:
				sim.say("%s — %s." % [planet.name, layer_name])
		if int(craft.layers_done) >= LAYERS.size():
			craft.state = "returning"
			sim.say("Dossier sealed: %s." % planet.name)
			sim.sfx("scan_done")
	elif str(craft.state) == "returning":
		_return_home(sim, craft, dt)


static func _step_harvest(sim, craft, dt: float) -> void:
	var planet = sim.planet(str(craft.target))
	if planet == null:
		craft.state = "returning"
		_return_home(sim, craft, dt)
		return
	if str(craft.state) == "outbound":
		var dist = _fly_toward(craft, _orbit_point(planet, craft.pos), dt, float(craft.speed))
		if dist < 30.0:
			craft.state = "working"
			craft.work = 0.0
	elif str(craft.state) == "working":
		_fly_toward(craft, _orbit_point(planet, craft.pos), dt, float(craft.speed) * 0.25)
		craft.work = float(craft.work) + dt
		if float(craft.work) >= float(craft.work_step) and not bool(craft.did_job):
			craft.did_job = true
			var result = str(sim.try_extract(str(planet.id)))
			if result == "full":
				sim.say("Hold is full. The drone is coming home empty.")
			elif result == "empty":
				sim.say("%s's seam is worked out." % planet.name)
			craft.state = "returning"
	elif str(craft.state) == "returning":
		_return_home(sim, craft, dt)


static func _step_tender(sim, craft, dt: float) -> void:
	var wreck = sim.wreck_by_id(str(craft.target))
	if wreck == null:
		craft.state = "returning"
		_return_home(sim, craft, dt)
		return
	if str(craft.state) == "outbound":
		var dist = _fly_toward(craft, wreck.pos, dt, float(craft.speed))
		if dist < 28.0:
			craft.state = "working"
			craft.work = 0.0
	elif str(craft.state) == "working":
		_fly_toward(craft, wreck.pos, dt, float(craft.speed) * 0.2)
		craft.work = float(craft.work) + dt
		if float(craft.work) >= float(craft.work_step) and not bool(craft.did_job):
			craft.did_job = true
			var result = str(sim.try_salvage(str(wreck.id)))
			if result == "full":
				sim.say("Hold is full. The tender leaves the wreck where it is.")
				craft.did_job = false
			craft.state = "returning"
	else:
		_return_home(sim, craft, dt)


static func _step_shuttle(sim, craft, dt: float) -> void:
	if str(craft.state) == "outbound":
		var dist = _fly_toward(craft, sim.pocket_pos, dt, float(craft.speed))
		if dist < 24.0:
			craft.state = "working"
			craft.work = 0.0
	elif str(craft.state) == "working":
		_fly_toward(craft, sim.pocket_pos, dt, 30.0)
		craft.work = float(craft.work) + dt
		if float(craft.work) >= float(craft.work_step) and not bool(craft.did_job):
			craft.did_job = true
			PocketRules.confirm_walk(sim)
			craft.state = "returning"
	else:
		_return_home(sim, craft, dt)


static func _step_fighter(sim, craft, dt: float) -> void:
	if str(craft.state) == "returning" or float(craft.battery) <= 8.0:
		craft.state = "returning"
		_return_home(sim, craft, dt)
		return
	var hostile = sim.nearest_hostile(craft.pos, 1100.0)
	if hostile == null:
		var aim = sim.player.pos + Vector2.from_angle(sim.time * 1.15) * 160.0
		_fly_toward(craft, aim, dt, float(craft.speed))
		return
	var dist = _fly_toward(craft, hostile.pos, dt, float(craft.speed))
	if dist < float(craft.gun.range) and _facing(craft, hostile.pos) < 0.45:
		sim.try_fire(craft, craft.gun)


static func _return_home(sim, craft, dt: float) -> void:
	if not sim.player.alive:
		_fly_toward(craft, sim.player.pos, dt, float(craft.speed))
		return
	var catch = maxf(float(craft.speed), sim.player.vel.length() + 90.0)
	if float(craft.battery) <= 0.0:
		catch = 70.0
	var dist = _fly_toward(craft, sim.player.pos, dt, catch)
	if dist < 46.0:
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


static func _depart(sim, craft, target: String) -> void:
	craft.state = "outbound"
	craft.target = target
	craft.pos = sim.player.pos + Vector2.from_angle(sim.player.rot) * 36.0
	craft.vel = sim.player.vel
	craft.rot = sim.player.rot
	craft.work = 0.0
	craft.layers_done = 0
	craft.did_job = false


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


static func _orbit_point(planet, from: Vector2) -> Vector2:
	var dir = from - planet.pos
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	return planet.pos + dir.normalized() * (float(planet.radius) + 56.0)


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


static func _next_scan_target(sim):
	var best = null
	var best_dist = 1.0e12
	for planet in sim.planets:
		if _targeted(sim, str(planet.id)):
			continue
		if sim.dossier_complete(str(planet.id)):
			continue
		var dist = sim.player.pos.distance_to(planet.pos)
		if dist < best_dist:
			best_dist = dist
			best = planet
	if best != null:
		return best
	best_dist = 1.0e12
	for planet in sim.planets:
		if _targeted(sim, str(planet.id)):
			continue
		var dist = sim.player.pos.distance_to(planet.pos)
		if dist < best_dist:
			best_dist = dist
			best = planet
	return best


static func _next_harvest_target(sim):
	var best = null
	var best_dist = 1.0e12
	for planet in sim.planets:
		if not sim.dossier_complete(str(planet.id)):
			continue
		if int(sim.deposits.get(planet.id, 0)) <= 0:
			continue
		var dist = sim.player.pos.distance_to(planet.pos)
		if dist < best_dist:
			best_dist = dist
			best = planet
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


static func _targeted(sim, planet_id: String) -> bool:
	for craft in sim.craft:
		if str(craft.def_id) != "survey_probe":
			continue
		if str(craft.state) == "docked" or str(craft.state) == "lost":
			continue
		if str(craft.target) == planet_id:
			return true
	return false


static func _pretty(def_id: String) -> String:
	return def_id.replace("_", " ")
