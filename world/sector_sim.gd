class_name SectorSim
extends RefCounted

var defs: Dictionary = {}
var seed_value = 0
var time = 0.0
var planets: Array = []
var asteroids: Array = []
var stars: Array = []
var pocket_pos = Vector2.ZERO
var nest_pos = Vector2.ZERO
var player: Dictionary = {}
var actors: Array = []
var craft: Array = []
var projectiles: Array = []
var wrecks: Array = []
var nodes: Array = []
var belt_marks: Array = []
var gather: Dictionary = {}
var works: Dictionary = {}
var beacon: Dictionary = {}
var aim := Vector2.ZERO
var aim_id := ""
var scans: Dictionary = {}
var deposits: Dictionary = {}
var heat: Dictionary = {}
var memory: Dictionary = {}
var heat_log: Array = []
var quest_flags: Dictionary = {}
var claim: Dictionary = {}
var lines: Array = []
var banner = ""
var banner_t = 0.0
var pdo_alert = false
var hailed = false
var sfx_queue: Array = []
var hold_npc = false


func _init(defs_in: Dictionary = {}) -> void:
	defs = defs_in


func new_game(class_id: String) -> void:
	seed_value = int(defs.system.seed)
	time = 0.0
	scans = {}
	wrecks = []
	gather = PlasmaHarvest.fresh_gather()
	works = PlasmaHarvest.fresh_works()
	beacon = {}
	aim = Vector2.ZERO
	aim_id = ""
	projectiles = []
	heat_log = []
	lines = []
	banner = ""
	banner_t = 0.0
	pdo_alert = false
	hailed = false
	sfx_queue = []
	hold_npc = false
	heat = {"vellum_compact": 0.0, "red_keel": 0.0}
	memory = {"vellum_compact": [], "red_keel": []}
	_build_static()
	var hull: Dictionary = defs.ships[class_id]
	var fresh = _blank_ship(class_id, hull.callsign, "agent:captain", "human", "captain")
	fresh.pos = pocket_pos + Vector2(40, 170)
	fresh.rot = (planet("cinder").pos - fresh.pos).angle()
	fresh.yard = hull.yard.duplicate()
	fresh.slots = hull.slots.duplicate()
	fresh.crew = hull.crew.duplicate(true)
	_ensure_fab_slots(fresh)
	player = fresh
	craft = []
	var running = {}
	for entry in hull.starting_craft:
		var def_id = str(entry.id)
		var count = int(entry.count)
		for _i in count:
			running[def_id] = int(running.get(def_id, 0)) + 1
			craft.append(_make_craft(def_id, int(running[def_id])))
	actors = []
	_spawn_factions()
	quest_flags = {"origin_%s" % class_id: "dormant"}
	claim = PocketRules.blank()
	say("You have the %s, callsign %s." % [hull.class_name, hull.callsign])
	say("Hollow Latch is under the keel. Cinder is the near rust world. Red Keel hunts the Slat. Vellum Compact owns the pale world — the green lane remembers guns.")
	if defs.has("harvest"):
		say("Plasma gatherer is live. Right-click ore, torn plate, or an abandoned hull. Rust Arc, Pale Shelf, Copper Vein, and King's Drift are out in the dark.")
		say("Hollow Latch buys ore and synthetics. The bay can pour alloy, circuit lace, and hull resin, then lay a weapon, a belt, or a boat.")


func tick(dt: float, cmd: Dictionary) -> void:
	var steps = mini(5, maxi(1, int(ceil(dt / 0.05))))
	var step = dt / float(steps)
	for i in steps:
		var frame = cmd if i == 0 else _held(cmd)
		_step(step, frame)


func install(module_id: String) -> Dictionary:
	var result = Fit.try_install(defs, player, module_id)
	say(str(result.reason))
	if result.ok:
		sfx("install")
	return result


func zone_at(pos: Vector2) -> String:
	var vellum = planet("vellum")
	if vellum != null and pos.distance_to(vellum.pos) <= float(defs.system.zones.green.radius):
		return "green"
	if pos.distance_to(nest_pos) <= float(defs.system.zones.amber.radius):
		return "amber"
	if pos.distance_to(pocket_pos) <= float(defs.system.pocket.radius):
		return "pocket"
	return "dark"


func zone_label(zone: String) -> String:
	match zone:
		"green":
			return "Green lane — Vellum Compact. A shot here goes on the slate."
		"amber":
			return "Amber — Red Keel ground. Finish a hull and the wreck is rights."
		"pocket":
			if bool(claim.get("frozen", false)):
				return "Hollow Latch — homestead frozen. The keel is still yours."
			if bool(claim.get("core", false)):
				return "Hollow Latch — your stake. Keep the hen fed."
			return "Hollow Latch — calm pocket. A Claim Core could sit here."
		_:
			return "Unpatrolled dark."


func planet(id: String):
	for body in planets:
		if str(body.id) == id:
			return body
	return null


func wreck_by_id(id: String):
	for wreck in wrecks:
		if str(wreck.id) == id:
			return wreck
	return null


func dossier_complete(planet_id: String) -> bool:
	if not scans.has(planet_id):
		return false
	return bool(scans[planet_id].complete)


func reveal_layer(planet_id: String, layer_name: String) -> bool:
	var dossier = _dossier(planet_id)
	if bool(dossier.layers[layer_name].known):
		return false
	dossier.layers[layer_name].known = true
	var done = true
	for key in dossier.layers.keys():
		if not bool(dossier.layers[key].known):
			done = false
			break
	dossier.complete = done
	return true


func try_extract(planet_id: String) -> String:
	var body = planet(planet_id)
	if body == null:
		return "missing"
	if int(deposits.get(planet_id, 0)) <= 0:
		return "empty"
	var stats = Fit.stats(defs, player)
	if Fit.cargo_used(player) >= int(stats.cargo_cap):
		return "full"
	deposits[planet_id] = int(deposits[planet_id]) - 1
	var res: Dictionary = body.resource
	_add_cargo(str(res.id), 1)
	say("%s aboard from %s. %d left in the seam." % [res.name, body.name, int(deposits[planet_id])])
	sfx("extract")
	if bool(body.protected):
		Ownership.add_heat(self, "vellum_compact", 28.0, "harvested_protected", player.agent_id)
		pdo_alert = true
		banner = "Vellum Compact: \"You cut a protected crust.\""
		banner_t = 0.0
		say("The Compact has the extraction. Heat is on the slate.")
		sfx("hail")
	return "ok"


func try_salvage(wreck_id: String) -> String:
	var wreck = wreck_by_id(wreck_id)
	if wreck == null or bool(wreck.stripped):
		return "empty"
	var stats = Fit.stats(defs, player)
	if Fit.cargo_used(player) >= int(stats.cargo_cap):
		return "full"
	wreck.stripped = true
	_add_cargo("salvage_parts", 1)
	var extra = ""
	var moved = false
	for key in wreck.cargo.keys():
		if int(wreck.cargo[key]) <= 0:
			continue
		if Fit.cargo_used(player) >= int(stats.cargo_cap):
			break
		_add_cargo(str(key), 1)
		wreck.cargo[key] = int(wreck.cargo[key]) - 1
		extra = " and %s" % resource_name(str(key))
		moved = true
		break
	if not moved:
		extra = ""
	say("Tender brought keel salvage%s off %s." % [extra, wreck.name])
	sfx("extract")
	return "ok"


func resource_name(id: String) -> String:
	if id == "salvage_parts":
		return "keel salvage"
	if id == "scrap":
		return "scrap"
	if defs.has("harvest"):
		var mats: Dictionary = defs.harvest.get("materials", {})
		if mats.has(id):
			return str(mats[id].name)
	if defs.has("claim"):
		var goods: Dictionary = defs.claim.get("goods", {})
		if goods.has(id):
			return str(goods[id])
	for body in planets:
		if str(body.resource.id) == id:
			return str(body.resource.name)
	return id


func nearest_hostile(pos: Vector2, radius: float):
	var best = null
	var best_dist = radius
	for actor in actors:
		if not bool(actor.alive):
			continue
		if str(actor.team) == "captain":
			continue
		if str(actor.team) == "vellum_compact" and not pdo_alert and float(heat.get("vellum_compact", 0.0)) < 40.0:
			continue
		var dist = pos.distance_to(actor.pos)
		if dist < best_dist:
			best_dist = dist
			best = actor
	return best


func try_fire(unit: Dictionary, gun: Dictionary) -> bool:
	if float(unit.get("fire_cd", 0.0)) > 0.0:
		return false
	if gun.is_empty():
		return false
	unit.fire_cd = float(gun.cooldown)
	var dir = Vector2.from_angle(float(unit.rot))
	projectiles.append({
		"pos": unit.pos + dir * (float(unit.get("muzzle", 28.0))),
		"vel": unit.vel + dir * float(gun.speed),
		"damage": float(gun.damage),
		"team": unit.team,
		"ttl": float(gun.get("ttl", 1.1)),
		"agent_id": unit.agent_id,
	})
	sfx("gun")
	if str(unit.team) == "captain":
		Ownership.on_captain_shot(self, unit.pos)
	return true


func damage_unit(unit: Dictionary, amount: float, attacker: String) -> void:
	if unit.has("state"):
		if str(unit.state) == "docked" or str(unit.state) == "lost":
			return
		unit.hp = float(unit.hp) - amount
		if float(unit.hp) <= 0.0:
			unit.hp = 0.0
			unit.state = "lost"
			say("%s lost. Write it off the board." % unit.name)
			sfx("destroyed")
		return
	if not bool(unit.get("alive", false)):
		return
	unit.hp = float(unit.hp) - amount
	unit.hurt_cd = 0.4
	if float(unit.hp) <= 0.0:
		_kill(unit, attacker)


func say(text: String) -> void:
	if not lines.is_empty() and str(lines[0].text) == text and float(lines[0].age) < 1.2:
		return
	lines.push_front({"text": text, "age": 0.0})
	if lines.size() > 6:
		lines.pop_back()


func sfx(name: String) -> void:
	sfx_queue.append(name)
	if sfx_queue.size() > 12:
		sfx_queue.pop_front()


func to_dict() -> Dictionary:
	var actor_rows: Array = []
	for actor in actors:
		actor_rows.append(_ship_out(actor))
	var craft_rows: Array = []
	for item in craft:
		craft_rows.append(_craft_out(item))
	var shots: Array = []
	for shot in projectiles:
		var row = shot.duplicate(true)
		row.pos = Serde.vec_out(shot.pos)
		row.vel = Serde.vec_out(shot.vel)
		shots.append(row)
	var wreck_rows: Array = []
	for wreck in wrecks:
		var row = wreck.duplicate(true)
		row.pos = Serde.vec_out(wreck.pos)
		wreck_rows.append(row)
	return {
		"version": 1,
		"galaxy_seed": seed_value,
		"system_id": defs.system.id,
		"time": time,
		"player": _ship_out(player),
		"actors": actor_rows,
		"craft": craft_rows,
		"projectiles": shots,
		"wrecks": wreck_rows,
		"scans": scans.duplicate(true),
		"deposits": deposits.duplicate(true),
		"heat": heat.duplicate(true),
		"memory": memory.duplicate(true),
		"heat_log": heat_log.duplicate(true),
		"quest_flags": quest_flags.duplicate(true),
		"claim": claim.duplicate(true),
		"lines": lines.duplicate(true),
		"banner": banner,
		"pdo_alert": pdo_alert,
		"hailed": hailed,
		"node_stock": PlasmaHarvest.stock_out(self),
		"runtime_nodes": PlasmaHarvest.runtime_out(self),
		"works": PlasmaHarvest.works_out(self),
		"beacon": _beacon_out(),
	}


func from_dict(data: Dictionary) -> void:
	seed_value = int(data.galaxy_seed)
	time = float(data.time)
	_build_static()
	player = _ship_in(data.player)
	actors = []
	for row in data.actors:
		actors.append(_ship_in(row))
	craft = []
	for row in data.craft:
		craft.append(_craft_in(row))
	projectiles = []
	for row in data.get("projectiles", []):
		var shot = row.duplicate(true)
		shot.pos = Serde.vec_in(shot.pos)
		shot.vel = Serde.vec_in(shot.vel)
		projectiles.append(shot)
	wrecks = []
	for row in data.get("wrecks", []):
		var wreck = row.duplicate(true)
		wreck.pos = Serde.vec_in(wreck.pos)
		wrecks.append(wreck)
	scans = data.scans.duplicate(true)
	deposits = data.deposits.duplicate(true)
	for key in deposits.keys():
		deposits[key] = int(deposits[key])
	heat = data.heat.duplicate(true)
	for key in heat.keys():
		heat[key] = float(heat[key])
	memory = data.memory.duplicate(true)
	heat_log = data.get("heat_log", []).duplicate(true)
	quest_flags = data.quest_flags.duplicate(true)
	claim = PocketRules.normalize(data.claim.duplicate(true))
	lines = data.get("lines", []).duplicate(true)
	banner = str(data.get("banner", ""))
	banner_t = 0.0
	pdo_alert = bool(data.get("pdo_alert", false))
	hailed = bool(data.get("hailed", false))
	sfx_queue = []
	hold_npc = false
	gather = PlasmaHarvest.fresh_gather()
	works = PlasmaHarvest.works_in(data.get("works", {}))
	beacon = _beacon_in(data.get("beacon", {}))
	aim = Vector2.ZERO
	aim_id = ""
	PlasmaHarvest.apply_stock(self, data.get("node_stock", {}))
	PlasmaHarvest.restore_runtime(self, data.get("runtime_nodes", []))
	_ensure_fab_slots(player)
	var fitted := Fit.stats(defs, player)
	player.max_hp = int(fitted.hp_max)
	if float(player.hp) > float(player.max_hp):
		player.hp = float(player.max_hp)


func _step(dt: float, cmd: Dictionary) -> void:
	time += dt
	_step_player(dt, cmd)
	for item in craft:
		CraftOrders.step(self, item, dt)
	if not hold_npc:
		for actor in actors:
			_step_npc(actor, dt)
	PocketRules.tick(self, dt)
	_step_projectiles(dt)
	if player.alive:
		_bump_world(player)
	if not hold_npc:
		for actor in actors:
			if bool(actor.alive):
				_bump_world(actor)
	if cmd.has("aim"):
		aim = cmd.aim
	if cmd.has("gather_at"):
		PlasmaHarvest.engage(self, cmd.gather_at)
	PlasmaHarvest.step(self, dt)
	for line in lines:
		line.age = float(line.age) + dt
	banner_t += dt
	if banner_t > 9.0:
		banner = ""


func _step_player(dt: float, cmd: Dictionary) -> void:
	player.fire_cd = maxf(0.0, float(player.fire_cd) - dt)
	player.hurt_cd = maxf(0.0, float(player.hurt_cd) - dt)
	if not bool(player.alive):
		player.thrusting = false
		player.pos += player.vel * dt
		return
	var stats = Fit.stats(defs, player)
	player.rot += float(cmd.get("rot", 0.0)) * float(stats.turn) * dt
	var forward = Vector2.from_angle(player.rot)
	var thrust = float(cmd.get("thrust", 0.0))
	var retro = float(cmd.get("retro", 0.0))
	var strafe = float(cmd.get("strafe", 0.0))
	player.thrusting = thrust > 0.0
	if thrust > 0.0:
		player.vel += forward * float(stats.accel) * dt
	if retro > 0.0:
		player.vel -= forward * float(stats.accel) * 0.62 * dt
	if absf(strafe) > 0.0:
		player.vel += forward.orthogonal() * float(stats.strafe_accel) * strafe * dt
	player.vel *= 1.0 - float(stats.damp) * dt
	if player.vel.length() > float(stats.vmax):
		player.vel = player.vel.limit_length(float(stats.vmax))
	player.pos += player.vel * dt
	if bool(cmd.get("fire", false)):
		try_fire(player, stats.gun)


func _step_npc(actor: Dictionary, dt: float) -> void:
	actor.fire_cd = maxf(0.0, float(actor.fire_cd) - dt)
	actor.hurt_cd = maxf(0.0, float(actor.hurt_cd) - dt)
	if not bool(actor.alive):
		return
	var dest: Vector2 = actor.pos
	var target = null
	if str(actor.team) == "red_keel":
		var enraged = bool(actor.ai.get("enraged", false)) or memory.get("red_keel", []).has("killed_a_skiff")
		var leash = 1500.0 if enraged else 980.0
		if player.alive and player.pos.distance_to(actor.pos) < leash and player.pos.distance_to(actor.home) < leash + 520.0:
			target = player
		else:
			var ang = time * 0.22 + float(actor.ai.phase)
			dest = actor.home + Vector2.from_angle(ang) * 170.0
	elif str(actor.team) == "vellum_compact":
		var engage = pdo_alert or float(heat.get("vellum_compact", 0.0)) >= 40.0
		var blooded = memory.get("vellum_compact", []).has("killed_patrol")
		if engage and player.alive:
			var leash = 1700.0 if blooded else 1200.0
			var near_lane = player.pos.distance_to(planet("vellum").pos) < float(defs.system.zones.green.radius) + 280.0
			if near_lane or player.pos.distance_to(actor.pos) < leash:
				target = player
		if target == null:
			var ang = time * 0.16 + float(actor.ai.phase)
			dest = actor.home + Vector2.from_angle(ang) * float(actor.ai.radius)
	if target != null:
		dest = target.pos
		var dist = actor.pos.distance_to(target.pos)
		var stats = Fit.stats(defs, actor)
		var gun: Dictionary = stats.gun
		var aligned = absf(wrapf((target.pos - actor.pos).angle() - actor.rot, -PI, PI)) < 0.42
		var heat_v = float(heat.get("vellum_compact", 0.0))
		var hailing = str(actor.team) == "vellum_compact" and heat_v < 40.0 and not memory.get("vellum_compact", []).has("killed_patrol")
		if hailing and dist < 780.0 and not bool(actor.ai.get("said_hail", false)):
			actor.ai.said_hail = true
			banner = "Vellum Compact cutter: \"You are in the green. Stow the guns.\""
			banner_t = 0.0
			sfx("hail")
		if dist < float(gun.range) and aligned and not hailing:
			try_fire(actor, gun)
		if dist < 190.0:
			dest = actor.pos - (target.pos - actor.pos).normalized() * 30.0
	_fly_ship(actor, dest, dt, target != null)


func _fly_ship(ship: Dictionary, dest: Vector2, dt: float, aggressive: bool) -> void:
	var stats = Fit.stats(defs, ship)
	var to = dest - ship.pos
	var dist = to.length()
	if dist > 12.0:
		var diff = wrapf(to.angle() - ship.rot, -PI, PI)
		var max_turn = float(stats.turn) * dt
		ship.rot += clampf(diff, -max_turn, max_turn)
		var want = absf(diff) < 0.55 and dist > (150.0 if aggressive else 50.0)
		ship.thrusting = want
		if want:
			ship.vel += Vector2.from_angle(ship.rot) * float(stats.accel) * dt
	else:
		ship.thrusting = false
	ship.vel *= 1.0 - float(stats.damp) * dt
	if ship.vel.length() > float(stats.vmax):
		ship.vel = ship.vel.limit_length(float(stats.vmax))
	ship.pos += ship.vel * dt


func _step_projectiles(dt: float) -> void:
	var kept: Array = []
	for shot in projectiles:
		shot.ttl = float(shot.ttl) - dt
		if float(shot.ttl) <= 0.0:
			continue
		shot.pos += shot.vel * dt
		var hit = _projectile_hit(shot)
		if hit != null:
			damage_unit(hit, float(shot.damage), str(shot.agent_id))
			sfx("hit")
			continue
		kept.append(shot)
	projectiles = kept


func _projectile_hit(shot: Dictionary):
	var bodies: Array = []
	if player.alive:
		bodies.append(player)
	for actor in actors:
		if bool(actor.alive):
			bodies.append(actor)
	for unit in bodies:
		if str(unit.team) == str(shot.team):
			continue
		var radius = float(Fit.stats(defs, unit).hit_radius)
		if shot.pos.distance_to(unit.pos) <= radius:
			return unit
	for item in craft:
		if str(item.state) == "docked" or str(item.state) == "lost":
			continue
		if str(item.team) == str(shot.team):
			continue
		if shot.pos.distance_to(item.pos) <= float(item.radius) + 4.0:
			return item
	return null


func _bump_world(ship: Dictionary) -> void:
	if not bool(ship.alive):
		return
	_bump_circle(ship, Vector2.ZERO, float(defs.system.star.radius), 16.0)
	for body in planets:
		_bump_circle(ship, body.pos, float(body.radius) * 0.94, 9.0)


func _bump_circle(ship: Dictionary, center: Vector2, radius: float, dmg: float) -> void:
	var delta = ship.pos - center
	var dist = delta.length()
	var limit = radius + float(Fit.stats(defs, ship).hit_radius) * 0.35
	if dist >= limit or dist < 0.01:
		return
	var normal = delta / dist
	ship.pos = center + normal * limit
	ship.vel = ship.vel.slide(normal) * 0.45 - normal * 30.0
	if float(ship.hurt_cd) <= 0.0:
		damage_unit(ship, dmg, "world")
		if str(ship.agent_id) == str(player.agent_id) and bool(player.alive):
			say("The keel scrapes. Capital ships stay off the crust.")


func _kill(unit: Dictionary, attacker: String) -> void:
	unit.alive = false
	unit.hp = 0.0
	unit.thrusting = false
	var wreck = {
		"id": "wreck_%d" % wrecks.size(),
		"agent_id": unit.agent_id,
		"controller": unit.controller,
		"team": unit.team,
		"class_id": unit.class_id,
		"pos": unit.pos,
		"cargo": unit.cargo.duplicate(true) if unit.has("cargo") else {},
		"stripped": false,
		"name": unit.name,
	}
	wrecks.append(wreck)
	PlasmaHarvest.spawn_battle_debris(self, unit)
	sfx("destroyed")
	if str(unit.team) == "red_keel":
		Ownership.add_heat(self, "red_keel", 10.0, "killed_a_skiff", attacker)
		for actor in actors:
			if str(actor.team) == "red_keel" and bool(actor.alive):
				actor.ai.enraged = true
		say("Red Keel will remember %s." % unit.name)
	elif str(unit.team) == "vellum_compact":
		Ownership.add_heat(self, "vellum_compact", 36.0, "killed_patrol", attacker)
		pdo_alert = true
		banner = "Vellum Compact: \"Patrol blood. The lane is closed to you.\""
		banner_t = 0.0
		say("A Compact cutter is gone. The slate does not forget.")
	elif str(unit.agent_id) == "agent:captain":
		banner = "Hull lost. The wreck keeps your name. Load the log, or leave the Reach."
		banner_t = 0.0
		say("The keel is broken. What is left is a wreck with your agent id on it.")


func _add_cargo(id: String, count: int) -> void:
	player.cargo[id] = int(player.cargo.get(id, 0)) + count


func _ensure_fab_slots(ship: Dictionary) -> void:
	if str(ship.get("controller", "")) != "human":
		return
	for slot in ["Weapon", "Drive", "Plate"]:
		if not ship.slots.has(slot):
			ship.slots.append(slot)


func _build_static() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	planets = []
	for source in defs.system.planets:
		var body: Dictionary = source.duplicate(true)
		body.pos = Vector2.from_angle(float(body.angle)) * float(body.distance)
		body.radius = float(body.radius)
		planets.append(body)
	for body in planets:
		deposits[body.id] = int(body.resource.amount)
	var anchor = planet(str(defs.system.pocket.anchor))
	pocket_pos = anchor.pos + Vector2.from_angle(float(defs.system.pocket.angle)) * float(defs.system.pocket.distance)
	nest_pos = Vector2.from_angle(float(defs.system.nest.angle)) * float(defs.system.nest.distance)
	asteroids = []
	var belt: Dictionary = defs.system.belt
	for _i in int(belt.count):
		var ang = rng.randf() * TAU
		var rad = float(belt.radius) + rng.randf_range(-float(belt.width), float(belt.width))
		var center = Vector2.from_angle(ang) * rad
		var size = rng.randf_range(7.0, 20.0)
		var rot = rng.randf() * TAU
		var verts = PackedVector2Array()
		var sides = rng.randi_range(5, 7)
		for s in sides:
			var a = rot + float(s) / float(sides) * TAU
			var rr = size * rng.randf_range(0.65, 1.15)
			verts.append(center + Vector2.from_angle(a) * rr)
		asteroids.append({"pos": center, "verts": verts, "size": size})
	stars = []
	PlasmaHarvest.seed(self)
	for _i in 420:
		var ang = rng.randf() * TAU
		var rad = rng.randf_range(200.0, 9200.0)
		stars.append({
			"pos": Vector2.from_angle(ang) * rad,
			"a": rng.randf_range(0.2, 0.85),
			"r": rng.randf_range(0.8, 1.8),
		})


func _spawn_factions() -> void:
	for i in int(defs.system.pdo.count):
		var actor = _blank_ship("cutter", "Vellum Cutter %d" % (i + 1), "agent:vellum_compact:%d" % i, "npc", "vellum_compact")
		var ang = float(i) * PI
		actor.home = planet("vellum").pos
		actor.pos = actor.home + Vector2.from_angle(ang) * float(defs.system.pdo.radius)
		actor.rot = ang + PI * 0.5
		actor.ai = {"phase": ang, "radius": float(defs.system.pdo.radius), "enraged": false}
		actor.cargo = {"scrap": 1}
		actors.append(actor)
	for i in int(defs.system.pirates.count):
		var actor = _blank_ship("skiff", "Red Keel %d" % (i + 1), "agent:red_keel:%d" % i, "npc", "red_keel")
		var ang = float(i) / float(defs.system.pirates.count) * TAU
		actor.home = nest_pos
		actor.pos = nest_pos + Vector2.from_angle(ang) * 150.0
		actor.rot = ang
		actor.ai = {"phase": ang, "radius": 180.0, "enraged": false}
		actor.cargo = {"scrap": 1}
		actors.append(actor)


func _blank_ship(class_id: String, ship_name: String, agent_id: String, controller: String, team: String) -> Dictionary:
	var stats = Fit.stats(defs, {"class_id": class_id, "modules": []})
	return {
		"id": agent_id,
		"class_id": class_id,
		"name": ship_name,
		"agent_id": agent_id,
		"controller": controller,
		"team": team,
		"pos": Vector2.ZERO,
		"vel": Vector2.ZERO,
		"rot": 0.0,
		"hp": int(stats.hp_max),
		"max_hp": int(stats.hp_max),
		"modules": [],
		"cargo": {},
		"scrip": 0,
		"yard": [],
		"slots": [],
		"crew": [],
		"fire_cd": 0.0,
		"hurt_cd": 0.0,
		"alive": true,
		"thrusting": false,
		"home": Vector2.ZERO,
		"ai": {},
		"muzzle": 34.0,
	}


func _make_craft(def_id: String, index: int) -> Dictionary:
	var spec: Dictionary = defs.craft[def_id]
	var craft_name = str(spec.name)
	if index > 1:
		craft_name = "%s %s" % [spec.name, _roman(index)]
	return {
		"uid": "%s_%d" % [def_id, index],
		"def_id": def_id,
		"name": craft_name,
		"team": "captain",
		"agent_id": "agent:captain",
		"state": "docked",
		"pos": pocket_pos,
		"vel": Vector2.ZERO,
		"rot": 0.0,
		"hp": int(spec.hp),
		"max_hp": int(spec.hp),
		"battery": float(spec.battery),
		"max_battery": float(spec.battery),
		"drain": float(spec.drain),
		"speed": float(spec.speed),
		"radius": float(spec.radius),
		"work_step": float(spec.work) if float(spec.work) > 0.0 else 1.0,
		"work": 0.0,
		"layers_done": 0,
		"target": "",
		"did_job": false,
		"fire_cd": 0.0,
		"gun": spec.get("gun", {}).duplicate(true),
		"muzzle": 16.0,
	}


func _dossier(planet_id: String) -> Dictionary:
	if scans.has(planet_id):
		return scans[planet_id]
	var body = planet(planet_id)
	var layers = {}
	for key in ["orbit", "atmosphere", "surface", "crust", "biosign", "ruins", "legal"]:
		layers[key] = {"known": false, "text": str(body.layers[key])}
	scans[planet_id] = {
		"planet_id": planet_id,
		"name": body.name,
		"layers": layers,
		"complete": false,
		"legal": body.legal,
		"resource_id": body.resource.id,
		"resource_name": body.resource.name,
	}
	return scans[planet_id]


func _held(cmd: Dictionary) -> Dictionary:
	return {
		"thrust": cmd.get("thrust", 0.0),
		"retro": cmd.get("retro", 0.0),
		"rot": cmd.get("rot", 0.0),
		"strafe": cmd.get("strafe", 0.0),
		"fire": cmd.get("fire", false),
	}


func _ship_out(ship: Dictionary) -> Dictionary:
	var row = ship.duplicate(true)
	row.pos = Serde.vec_out(ship.pos)
	row.vel = Serde.vec_out(ship.vel)
	if ship.has("home"):
		row.home = Serde.vec_out(ship.home)
	return row


func _ship_in(row: Dictionary) -> Dictionary:
	var ship = row.duplicate(true)
	ship.pos = Serde.vec_in(ship.pos)
	ship.vel = Serde.vec_in(ship.vel)
	if ship.has("home"):
		ship.home = Serde.vec_in(ship.home)
	ship.hp = float(ship.hp)
	ship.max_hp = int(ship.max_hp)
	ship.rot = float(ship.rot)
	ship.fire_cd = float(ship.get("fire_cd", 0.0))
	ship.hurt_cd = float(ship.get("hurt_cd", 0.0))
	ship.alive = bool(ship.alive)
	ship.thrusting = false
	if not ship.has("muzzle"):
		ship.muzzle = 34.0
	for key in ship.cargo.keys():
		ship.cargo[key] = int(ship.cargo[key])
	ship.scrip = int(ship.get("scrip", 0))
	return ship


func _craft_out(item: Dictionary) -> Dictionary:
	var row = item.duplicate(true)
	row.pos = Serde.vec_out(item.pos)
	row.vel = Serde.vec_out(item.vel)
	return row


func _craft_in(row: Dictionary) -> Dictionary:
	var item = row.duplicate(true)
	item.pos = Serde.vec_in(item.pos)
	item.vel = Serde.vec_in(item.vel)
	item.hp = float(item.hp)
	item.battery = float(item.battery)
	item.rot = float(item.rot)
	return item


func _beacon_out() -> Dictionary:
	if beacon.is_empty():
		return {}
	var row: Dictionary = beacon.duplicate(true)
	if row.has("pos"):
		row.pos = Serde.vec_out(row.pos)
	return row


func _beacon_in(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or raw.is_empty():
		return {}
	var row: Dictionary = raw.duplicate(true)
	if row.has("pos"):
		row.pos = Serde.vec_in(row.pos)
	return row


func _roman(index: int) -> String:
	match index:
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		_:
			return str(index)
