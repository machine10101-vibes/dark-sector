class_name SectorSim
extends RefCounted

const BODY_SCALE := 3.4
const ROCK_SCALE := 4.2
const DOCK_GAP := 320.0

var defs: Dictionary = {}
var seed_value = 0
var time = 0.0
var planets: Array = []
var nodes: Array = []
var asteroids: Array = []
var trash: Array = []
var meteors: Array = []
var visited: Array = []
var stream_origin := Vector2.ZERO
var stars: Array = []
var pocket_pos = Vector2.ZERO
var gates: Array = []
var nest_pos = Vector2.ZERO
var beacon_pos = Vector2.ZERO
var star_radius := 180.0
var trash_pos = Vector2.ZERO
var pack_pos = Vector2.ZERO
var fined := false
var player: Dictionary = {}
var actors: Array = []
var craft: Array = []
var projectiles: Array = []
var wrecks: Array = []
var scans: Dictionary = {}
var deposits: Dictionary = {}
var heat: Dictionary = {}
var memory: Dictionary = {}
var heat_log: Array = []
var quest_flags: Dictionary = {}
var contracts: Array = []
var nav_mark: Dictionary = {}
var market: Dictionary = {"glasswheat": 4}
var claim: Dictionary = {}
var captains: Array = []
var commands: Dictionary = {}
var law_target := ""
var chat: Array = []
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
	var chart: Dictionary = defs.get("systems", {})
	if chart.has("HC-V1-R1-S1"):
		defs.system = chart["HC-V1-R1-S1"]
	seed_value = int(defs.system.seed)
	time = 0.0
	scans = {}
	wrecks = []
	projectiles = []
	heat_log = []
	lines = []
	banner = ""
	banner_t = 0.0
	pdo_alert = false
	hailed = false
	fined = false
	sfx_queue = []
	hold_npc = false
	heat = {}
	memory = {}
	for faction_id in defs.factions.keys():
		heat[str(faction_id)] = 0.0
		memory[str(faction_id)] = []
	_build_static()
	var hull: Dictionary = defs.ships[class_id]
	var fresh = _blank_ship(class_id, hull.callsign, "agent:captain", "human", "captain")
	var dock = planet(str(defs.system.pdo.home))
	fresh.pos = dock.pos + Vector2(float(dock.radius) + DOCK_GAP, 40.0)
	fresh.rot = (fresh.pos - dock.pos).angle()
	fresh.yard = hull.yard.duplicate()
	fresh.slots = hull.slots.duplicate()
	fresh.crew = hull.crew.duplicate(true)
	player = fresh
	player.hangar_hp = 22.0
	player.hangar_max = 22.0
	player.module_hp = {}
	player.fight_cd = 0.0
	player.player_id = "captain-host"
	player.warrant = false
	player.flagged = false
	player.grace_t = 0.0
	player.grace_armed = false
	player.heat_compact = 0.0
	player.alert = false
	player.dock_x = player.pos.x
	player.dock_y = player.pos.y
	captains = []
	commands = {}
	law_target = ""
	chat = []
	craft = []
	var running = {}
	for entry in hull.starting_craft:
		var def_id = str(entry.id)
		var count = int(entry.count)
		for _i in count:
			running[def_id] = int(running.get(def_id, 0)) + 1
			craft.append(_make_craft(def_id, int(running[def_id])))
	actors = []
	quest_flags = {}
	_spawn_factions()
	quest_flags = {
		"origin_%s" % class_id: "dormant",
		"authored_shakedown_01": "active",
		"shakedown_beat": "undock",
		"dock_x": player.pos.x,
		"dock_y": player.pos.y,
		"compact_standing": 0,
	}
	contracts = []
	nav_mark = {}
	market = {}
	_fill_market()
	visited = [str(defs.system.id)]
	var pocket: Dictionary = defs.system.pocket
	claim = {
		"pocket_id": str(pocket.id),
		"owned": false,
		"frozen": false,
		"core": false,
		"agent_id": "",
		"surveyed": false,
		"plantable": bool(pocket.get("plantable", false)),
	}
	player.cargo["claim_core"] = 1
	say("You have the %s, callsign %s." % [hull.class_name, hull.callsign])
	say("%s. %s is the city-orbital. The ice ring is lit. %s holds confiscated hulls. %s is marked and not a homestead." % [defs.system.name, planet(str(defs.system.pdo.home)).name, defs.system.trash.name, pocket.name])
	say("A Claim Core is in the hold. The Homestead Road buoy is off the green. L takes the lane.")
	say("Green spine buoys leave for Brass Lantern and Writ. From First Soil the amber road reaches Perimeter, and the hatch reaches Gyre.")
	say("Shakedown is on the log. J reads it. Y marks the next place. The keel stays put.")


func tick(dt: float, cmd: Dictionary) -> void:
	var steps = mini(5, maxi(1, int(ceil(dt / 0.05))))
	var step = dt / float(steps)
	for i in steps:
		var frame = cmd if i == 0 else _held(cmd)
		_step(step, frame)


func install(module_id: String) -> Dictionary:
	if in_combat():
		var shut := {"ok": false, "reason": "The bay is shut. Break off before you touch a bolt."}
		say(str(shut.reason))
		return shut
	var result = Fit.try_install(defs, player, module_id)
	say(str(result.reason))
	if result.ok:
		if not player.has("module_hp"):
			player.module_hp = {}
		player.module_hp[module_id] = 22.0
		sfx("install")
	return result


func uninstall(module_id: String) -> Dictionary:
	if in_combat():
		var shut := {"ok": false, "reason": "The bay is shut. Break off before you touch a bolt."}
		say(str(shut.reason))
		return shut
	var result = Fit.try_remove(defs, player, module_id)
	say(str(result.reason))
	if result.ok:
		if player.has("module_hp"):
			player.module_hp.erase(module_id)
		sfx("install")
	return result


func in_combat() -> bool:
	if pdo_alert:
		return true
	for shot in projectiles:
		if str(shot.team) != str(player.team):
			return true
	return false


func _pdo_id() -> String:
	return str(defs.system.pdo.get("faction", "vellum_compact"))


func _pdo_name() -> String:
	var faction: Dictionary = defs.factions.get(_pdo_id(), {})
	return str(faction.get("name", "Compact"))


func zone_at(pos: Vector2) -> String:
	var green_body = planet(str(defs.system.zones.green.anchor))
	if green_body != null and pos.distance_to(green_body.pos) <= float(defs.system.zones.green.radius):
		return "green"
	var amber_r := float(defs.system.zones.amber.radius)
	if amber_r > 1.0 and pos.distance_to(nest_pos) <= amber_r:
		return "amber"
	if pos.distance_to(pocket_pos) <= float(defs.system.pocket.radius):
		return "pocket"
	return "dark"


func zone_label(zone: String) -> String:
	match zone:
		"green":
			return "Green lane — %s. A shot here goes on the slate." % _pdo_name()
		"amber":
			return "Amber — Red Keel ground. Finish a hull and the wreck is rights."
		"pocket":
			if bool(defs.system.pocket.get("plantable", false)):
				return "%s — calm pocket. A Claim Core could sit here." % defs.system.pocket.name
			return "%s — marked pocket. Compact law. Not a homestead." % defs.system.pocket.name
		_:
			return "Unpatrolled dark."


func planet(id: String):
	for body in planets:
		if str(body.id) == id:
			return body
	return null


func survey_node(id: String):
	for row in nodes:
		if str(row.id) == id:
			return row
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


func try_extract(node_id: String) -> String:
	var row = survey_node(node_id)
	if row == null:
		return "missing"
	if int(deposits.get(node_id, 0)) <= 0:
		return "empty"
	var stats = Fit.stats(defs, player)
	if Fit.cargo_used(player) >= int(stats.cargo_cap):
		return "full"
	var held := Fit.cargo_used(player)
	deposits[node_id] = int(deposits[node_id]) - 1
	var res: Dictionary = row.resource
	_add_cargo(str(res.id), 1)
	say("%s aboard from %s. %d left in the seam." % [res.name, row.name, int(deposits[node_id])])
	sfx("extract")
	_heat_for_cut(row, held)
	return "ok"


func _heat_for_cut(row: Dictionary, held_before: int) -> void:
	var policy := str(row.get("heat", ""))
	if policy == "pdo":
		Ownership.add_heat(self, _pdo_id(), 28.0, "harvested_protected", player.agent_id)
		pdo_alert = true
		banner = "%s: \"That cut was not yours.\"" % _pdo_name()
		banner_t = 0.0
		say("Illegal cut on %s. %s heat is on the slate." % [row.name, _pdo_name()])
		sfx("hail")
	elif policy == "lease":
		var amount := 16.0
		if held_before < 3:
			amount = 6.0
		Ownership.add_heat(self, _pdo_id(), amount, "lease_cut", player.agent_id)
		if held_before < 3:
			say("Lease cut on %s. The hold is still small, so the slate takes less." % row.name)
		else:
			say("Lease cut on %s. The hold is no longer small." % row.name)


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


func try_field_salvage(node_id: String) -> String:
	var row = survey_node(node_id)
	if row == null:
		return "missing"
	if int(deposits.get(node_id, 0)) <= 0:
		return "empty"
	var stats = Fit.stats(defs, player)
	if Fit.cargo_used(player) >= int(stats.cargo_cap):
		return "full"
	deposits[node_id] = int(deposits[node_id]) - 1
	_add_cargo("salvage_parts", 1)
	var origin := str(row.get("origin", ""))
	if origin == "":
		origin = str(defs.system.get("trash", {}).get("origin", "an unmarked field"))
	say("Tender strips %s. Origin: %s." % [row.name, origin])
	sfx("extract")
	if str(row.get("heat", "")) == "pdo":
		_heat_for_cut(row, 0)
	return "ok"


func _fill_market() -> void:
	var defaults := {
		"glasswheat": 4,
		"voidbean": 6,
		"ember_kale": 5,
		"ghost_gourd": 7,
		"dock_fee": 2,
	}
	for key in defaults.keys():
		if not market.has(key):
			market[key] = int(defaults[key])
	market.glasswheat = int(market.get("glasswheat", 4))


func resource_name(id: String) -> String:
	if id == "raw_mass":
		return "raw mass"
	if id == "salvage_parts":
		return "keel salvage"
	if id == "scrap":
		return "scrap"
	if id == "claim_core":
		return "Claim Core"
	if id == "food_mass":
		return "food mass"
	if id == "milk_analogue":
		return "milk analogue"
	if id == "fodder":
		return "fodder"
	for row in nodes:
		if str(row.resource.id) == id:
			return str(row.resource.name)
	for body in planets:
		if str(body.resource.id) == id:
			return str(body.resource.name)
	return id


func spend_cargo(id: String, count: int) -> bool:
	if int(player.cargo.get(id, 0)) < count:
		return false
	player.cargo[id] = int(player.cargo[id]) - count
	if int(player.cargo[id]) <= 0:
		player.cargo.erase(id)
	return true


func nearest_hostile(pos: Vector2, radius: float):
	var best = null
	var best_dist = radius
	for actor in actors:
		if not bool(actor.alive):
			continue
		var team := str(actor.team)
		if team == "captain" or team == "civilian":
			continue
		var engage_at := 40.0
		if defs.factions.has(team):
			engage_at = float(defs.factions[team].get("heat_to_engage", 40.0))
		if (team == "vellum_compact" or team == _pdo_id()) and not pdo_alert and float(heat.get(team, 0.0)) < engage_at:
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
	if str(unit.get("controller", "")) == "human":
		unit.fight_cd = 2.4
		if str(unit.agent_id) == str(player.agent_id) and not Law.muzzle_clean(self, unit):
			Ownership.on_captain_shot(self, unit.pos)
	return true


func damage_unit(unit: Dictionary, amount: float, attacker: String) -> void:
	_note_hit(attacker, unit)
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
	if unit.has("class_id") and not unit.has("state"):
		var belt := float(Fit.stats(defs, unit).armor)
		if belt > 0.0:
			amount = maxf(0.35, amount * (1.0 - belt))
	if str(unit.get("controller", "")) == "human":
		_chip_capital(unit, amount)
	var shooter = human_by_agent(attacker)
	if shooter != null and str(unit.get("controller", "")) == "human" and str(shooter.agent_id) != str(unit.agent_id):
		Law.on_captain_hit(self, shooter, unit)
		var crack: Dictionary = claim.get("crack", {})
		if bool(crack.get("active", false)) and str(crack.get("agent_id", "")) == str(unit.agent_id):
			if str(shooter.agent_id) == str(claim.get("agent_id", "")):
				Homestead.abort_crack(self, "shot")
	if str(unit.get("team", "")) == _pdo_id() and attacker == "agent:captain":
		Ownership.add_heat(self, _pdo_id(), 28.0, "shot_patrol", attacker)
		pdo_alert = true
		banner = "%s: \"You fired on the Guard.\"" % _pdo_name()
		banner_t = 0.0
		say("The patrol is hostile. Heat spikes.")
		sfx("hail")
	unit.hp = float(unit.hp) - amount
	unit.hurt_cd = 0.4
	if float(unit.hp) <= 0.0:
		if shooter != null and Law.in_grace(self, unit):
			unit.hp = 1.0
			say("Green grace. A new keel is not claim-wiped in Helion Dock.")
			return
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
		"contracts": contracts.duplicate(true),
		"nav_mark": nav_mark.duplicate(true),
		"market": market.duplicate(true),
		"visited": visited.duplicate(),
		"claim": claim.duplicate(true),
		"captains": _captain_rows(),
		"law_target": law_target,
		"chat": chat.duplicate(true),
		"lines": lines.duplicate(true),
		"banner": banner,
		"pdo_alert": pdo_alert,
		"hailed": hailed,
		"fined": fined,
	}


func from_dict(data: Dictionary) -> void:
	var want := str(data.get("system_id", ""))
	var chart: Dictionary = defs.get("systems", {})
	if chart.has(want):
		defs.system = chart[want]
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
	contracts = data.get("contracts", []).duplicate(true)
	nav_mark = data.get("nav_mark", {}).duplicate(true)
	market = data.get("market", {}).duplicate(true)
	_fill_market()
	visited = data.get("visited", []).duplicate()
	if visited.is_empty():
		visited = [str(defs.system.id)]
	claim = data.claim.duplicate(true)
	Homestead.normalize(self)
	captains = []
	for row in data.get("captains", []):
		captains.append(_ship_in(row))
	commands = {}
	law_target = str(data.get("law_target", ""))
	chat = data.get("chat", []).duplicate(true)
	if str(player.get("player_id", "")) == "" and str(player.get("controller", "")) == "human":
		player.player_id = "captain-host"
	lines = data.get("lines", []).duplicate(true)
	banner = str(data.get("banner", ""))
	banner_t = 0.0
	pdo_alert = bool(data.get("pdo_alert", false))
	hailed = bool(data.get("hailed", false))
	fined = bool(data.get("fined", false))
	sfx_queue = []
	hold_npc = false


func _step(dt: float, cmd: Dictionary) -> void:
	time += dt
	_apply_verbs(player, cmd)
	for mate in captains:
		var guest_cmd: Dictionary = commands.get(str(mate.get("player_id", "")), {})
		_apply_verbs(mate, guest_cmd)
	_clear_oneshots()
	_step_ship(player, cmd, dt)
	for mate in captains:
		var guest_cmd: Dictionary = commands.get(str(mate.get("player_id", "")), {})
		_step_ship(mate, guest_cmd, dt)
	for item in craft:
		CraftOrders.step(self, item, dt)
	if not hold_npc:
		for actor in actors:
			_step_npc(actor, dt)
	_step_projectiles(dt)
	if player.alive:
		_bump_world(player)
	for mate in captains:
		if bool(mate.get("alive", false)):
			_bump_world(mate)
	if not hold_npc:
		for actor in actors:
			if bool(actor.alive):
				_bump_world(actor)
	for line in lines:
		line.age = float(line.age) + dt
	banner_t += dt
	if banner_t > 9.0:
		banner = ""
	_step_stream(dt)
	Homestead.step(self, dt)
	QuestBoard.pulse(self, dt)
	_step_compact()


func _step_player(dt: float, cmd: Dictionary) -> void:
	_step_ship(player, cmd, dt)


func _step_ship(unit: Dictionary, cmd: Dictionary, dt: float) -> void:
	unit.fire_cd = maxf(0.0, float(unit.fire_cd) - dt)
	unit.hurt_cd = maxf(0.0, float(unit.hurt_cd) - dt)
	unit.fight_cd = maxf(0.0, float(unit.get("fight_cd", 0.0)) - dt)
	if not bool(unit.alive):
		unit.thrusting = false
		unit.pos += unit.vel * dt
		return
	var stats = Fit.stats(defs, unit)
	unit.rot += float(cmd.get("rot", 0.0)) * float(stats.turn) * dt
	var forward = Vector2.from_angle(unit.rot)
	var thrust = float(cmd.get("thrust", 0.0))
	var retro = float(cmd.get("retro", 0.0))
	var strafe = float(cmd.get("strafe", 0.0))
	unit.thrusting = thrust > 0.0
	if thrust > 0.0:
		unit.vel += forward * float(stats.accel) * dt
		var speed := float(unit.vel.length())
		if speed > 12.0:
			var slip := wrapf(forward.angle() - unit.vel.angle(), -PI, PI)
			var grip := clampf(float(stats.turn) * 0.9, 0.45, 3.4)
			var step := clampf(slip, -grip * dt, grip * dt)
			unit.vel = Vector2.from_angle(unit.vel.angle() + step) * speed
	if retro > 0.0:
		unit.vel -= forward * float(stats.accel) * 0.62 * dt
	if absf(strafe) > 0.0:
		unit.vel += forward.orthogonal() * float(stats.strafe_accel) * strafe * dt
	unit.vel *= 1.0 - float(stats.damp) * dt
	if unit.vel.length() > float(stats.vmax):
		unit.vel = unit.vel.limit_length(float(stats.vmax))
	unit.pos += unit.vel * dt
	if bool(cmd.get("fire", false)):
		try_fire(unit, stats.gun)
	_arm_grace(unit, dt)


func _step_npc(actor: Dictionary, dt: float) -> void:
	actor.fire_cd = maxf(0.0, float(actor.fire_cd) - dt)
	actor.hurt_cd = maxf(0.0, float(actor.hurt_cd) - dt)
	if not bool(actor.alive):
		return
	var dest: Vector2 = actor.pos
	var target = null
	var guns_at := 40.0
	if str(actor.team) == "red_keel":
		_step_pirate(actor, dt)
		return
	elif str(actor.team) == "civilian":
		var coast = time * 0.07 + float(actor.ai.phase)
		dest = actor.home + Vector2.from_angle(coast) * float(actor.ai.radius)
		_fly_ship(actor, dest, dt, false)
		return
	elif str(actor.team) == _pdo_id():
		var heat_now := float(heat.get(_pdo_id(), 0.0))
		if defs.factions.has(_pdo_id()):
			guns_at = float(defs.factions[_pdo_id()].get("heat_to_engage", 40.0))
		var engage := pdo_alert or heat_now >= 12.0
		var blooded = memory.get(_pdo_id(), []).has("killed_patrol")
		var quarry = _law_quarry()
		if quarry == null and engage and player.alive:
			quarry = player
		if quarry != null and bool(quarry.get("alive", false)):
			var leash = 1700.0 if blooded else 1200.0
			var lane_body = planet(str(defs.system.zones.green.anchor))
			var near_lane = lane_body != null and quarry.pos.distance_to(lane_body.pos) < float(defs.system.zones.green.radius) + 280.0
			if near_lane or quarry.pos.distance_to(actor.pos) < leash:
				target = quarry
		if target == null:
			var ang = time * 0.16 + float(actor.ai.phase)
			dest = actor.home + Vector2.from_angle(ang) * float(actor.ai.radius)
	if target != null:
		dest = target.pos
		var dist = actor.pos.distance_to(target.pos)
		var stats = Fit.stats(defs, actor)
		var gun: Dictionary = stats.gun
		var aligned = absf(wrapf((target.pos - actor.pos).angle() - actor.rot, -PI, PI)) < 0.42
		var heat_v = _heat_for(target)
		var hailing = str(actor.team) == _pdo_id() and heat_v < guns_at and not memory.get(_pdo_id(), []).has("killed_patrol")
		if hailing and dist < 780.0 and not bool(actor.ai.get("said_hail", false)):
			actor.ai.said_hail = true
			banner = "%s cutter: \"You are in the green. Stow the guns.\"" % _pdo_name()
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
		var origin := Vector2(shot.pos)
		shot.pos += shot.vel * dt
		var hit = _projectile_hit(shot, origin)
		if hit != null:
			damage_unit(hit, float(shot.damage), str(shot.agent_id))
			sfx("hit")
			continue
		kept.append(shot)
	projectiles = kept


func _projectile_hit(shot: Dictionary, origin: Vector2):
	var dest := Vector2(shot.pos)
	var bodies: Array = []
	if player.alive:
		bodies.append(player)
	for mate in captains:
		if bool(mate.get("alive", false)):
			bodies.append(mate)
	for actor in actors:
		if bool(actor.alive):
			bodies.append(actor)
	for unit in bodies:
		if _friendly_fire(shot, unit):
			continue
		var radius = float(Fit.stats(defs, unit).hit_radius)
		if _shot_reaches(origin, dest, unit.pos, radius):
			return unit
	for item in craft:
		if str(item.state) == "docked" or str(item.state) == "lost":
			continue
		if str(item.team) == str(shot.team):
			continue
		if _shot_reaches(origin, dest, item.pos, float(item.radius) + 4.0):
			return item
	return null


func _shot_reaches(origin: Vector2, dest: Vector2, center: Vector2, radius: float) -> bool:
	var span := dest - origin
	var span_len := span.length_squared()
	var along := 0.0
	if span_len > 0.0001:
		along = clampf((center - origin).dot(span) / span_len, 0.0, 1.0)
	var closest := origin + span * along
	return closest.distance_to(center) <= radius


func _bump_world(ship: Dictionary) -> void:
	if not bool(ship.alive):
		return
	_bump_circle(ship, Vector2.ZERO, star_radius, 16.0)
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


func hangar_down() -> bool:
	return float(player.get("hangar_hp", 22.0)) <= 0.0


func heat_stage() -> String:
	var h := float(heat.get(_pdo_id(), 0.0))
	var guns := float(defs.factions[_pdo_id()].get("heat_to_engage", 40.0))
	if h >= guns or pdo_alert:
		return "guns"
	if fined or h >= 26.0:
		return "fine"
	if hailed or h >= 12.0:
		return "hail"
	return "clear"


func try_repair() -> String:
	if player.pos.distance_to(beacon_pos) > 170.0:
		return "The dock beacon is the crane. Bring the keel in."
	var hurt := float(player.hp) < float(player.max_hp) - 0.5
	if float(player.get("hangar_hp", 22.0)) < float(player.get("hangar_max", 22.0)) - 0.5:
		hurt = true
	var hpmap: Dictionary = player.get("module_hp", {})
	for module_id in player.modules:
		if float(hpmap.get(str(module_id), 22.0)) < 21.5:
			hurt = true
			break
	if not hurt:
		return "Nothing to weld."
	var waived := bool(quest_flags.get("repair_discount", false))
	if not waived and int(player.cargo.get("raw_mass", 0)) < 1:
		return "Repair wants one unit of harvested mass."
	if not waived:
		spend_cargo("raw_mass", 1)
	else:
		say("Compact standing waives the mass.")
	player.hp = minf(float(player.max_hp), float(player.hp) + 28.0)
	player.hangar_hp = float(player.get("hangar_max", 22.0))
	if not player.has("module_hp"):
		player.module_hp = {}
	for module_id in player.modules:
		player.module_hp[str(module_id)] = 22.0
	say("Welds hold. The hangar answers.")
	sfx("install")
	return ""


func _step_compact() -> void:
	var faction_id := _pdo_id()
	var h := float(heat.get(faction_id, 0.0))
	if h >= 12.0 and not hailed:
		hailed = true
		banner = "%s: \"Heave to. The slate has you.\"" % _pdo_name()
		banner_t = 0.0
		sfx("hail")
		say("The patrol hails.")
	if h >= 26.0 and not fined:
		_fine_cargo()
	var guns := float(defs.factions[faction_id].get("heat_to_engage", 40.0))
	if h >= guns:
		pdo_alert = true


func _fine_cargo() -> void:
	fined = true
	var taken := ""
	if int(player.cargo.get("raw_mass", 0)) > 0:
		spend_cargo("raw_mass", 1)
		taken = "raw mass"
	else:
		for key in player.cargo.keys():
			if str(key) == "claim_core":
				continue
			if int(player.cargo[key]) <= 0:
				continue
			spend_cargo(str(key), 1)
			taken = resource_name(str(key))
			break
	if taken == "":
		say("The hold is empty. The fine is written anyway.")
		banner = "%s: \"Empty hold. The fine stands.\"" % _pdo_name()
	else:
		say("The patrol fines one %s." % taken)
		banner = "%s: \"Cargo for the slate.\"" % _pdo_name()
	banner_t = 0.0
	sfx("hail")


func _note_hit(attacker: String, unit: Dictionary) -> void:
	var victim := str(unit.get("agent_id", "")) == "agent:captain" or str(unit.get("team", "")) == "captain"
	if not victim:
		return
	if not attacker.begins_with("agent:red_keel"):
		return
	for actor in actors:
		if str(actor.agent_id) != attacker:
			continue
		actor.ai.fired_on_captain = true
		return


func _chip_capital(unit: Dictionary, amount: float) -> void:
	var before := float(unit.get("hangar_hp", 22.0))
	var now := before - amount
	if now < 0.0:
		now = 0.0
	unit.hangar_hp = now
	if before > 0.0 and now <= 0.0:
		say("The hangar is down. Craft cannot come aboard.")
	if not unit.has("module_hp"):
		unit.module_hp = {}
	var hpmap: Dictionary = unit.module_hp
	for module_id in unit.modules:
		var mid := str(module_id)
		var part := float(hpmap.get(mid, 22.0))
		if part <= 0.0:
			continue
		part -= amount
		if part < 0.0:
			part = 0.0
		hpmap[mid] = part
		if part <= 0.0:
			var mod: Dictionary = defs.modules.get(mid, {})
			say("%s is dark until the dock beacon." % str(mod.get("name", mid)))
		break


func _step_pirate(actor: Dictionary, dt: float) -> void:
	var quarry := _pirate_quarry(actor)
	if quarry.is_empty():
		var spin: float = time * 0.22 + float(actor.ai.get("phase", 0.0))
		_fly_ship(actor, actor.home + Vector2.from_angle(spin) * 140.0, dt, false)
		return
	var pressing := float(player.get("fight_cd", 0.0)) > 0.0
	var far: bool = quarry.pos.distance_to(actor.home) > 780.0
	if far and not pressing:
		actor.ai.chase = float(actor.ai.get("chase", 0.0)) + dt
	elif not far:
		actor.ai.chase = 0.0
	var deep := _deep_green(quarry.pos) and not pressing
	if float(actor.ai.get("chase", 0.0)) > 5.0 or deep:
		actor.ai.chase = 0.0
		var spin: float = time * 0.22 + float(actor.ai.get("phase", 0.0))
		_fly_ship(actor, actor.home + Vector2.from_angle(spin) * 140.0, dt, false)
		return
	var aim: Vector2 = quarry.pos
	var offset: Vector2 = aim - actor.pos
	var dist: float = offset.length()
	var stats := Fit.stats(defs, actor)
	var gun: Dictionary = stats.gun
	var dest := aim
	var role := str(actor.ai.get("role", "interceptor"))
	if pressing and dist < float(gun.range) and dist > 1.0:
		dest = aim
	elif role == "kite":
		if dist < 340.0 and dist > 1.0:
			dest = actor.pos - offset.normalized() * 240.0
		elif dist > 460.0:
			dest = aim
		else:
			var side := Vector2(-offset.y, offset.x).normalized()
			dest = actor.pos + side * 90.0
	elif dist < 150.0 and dist > 1.0:
		dest = actor.pos - offset.normalized() * 40.0
	var aligned := absf(wrapf((aim - actor.pos).angle() - actor.rot, -PI, PI)) < 0.42
	if dist < float(gun.range) and aligned:
		try_fire(actor, gun)
	if pressing and dist < 280.0:
		actor.vel *= 1.0 - 2.4 * dt
	_fly_ship(actor, dest, dt, true)


func _pirate_quarry(actor: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 1400.0
	for item in craft:
		if str(item.state) == "docked" or str(item.state) == "lost":
			continue
		if str(item.team) != "captain":
			continue
		var row: Dictionary = item
		var dist: float = actor.pos.distance_to(row.pos)
		if dist < best_d:
			best = row
			best_d = dist
	if not best.is_empty():
		return best
	if not bool(player.alive):
		return {}
	var enraged: bool = bool(actor.ai.get("enraged", false)) or memory.get("red_keel", []).has("killed_a_skiff")
	var reach := 620.0
	var sight := 700.0
	if enraged:
		reach = 900.0
		sight = 1000.0
	if player.pos.distance_to(actor.home) < reach or player.pos.distance_to(actor.pos) < sight:
		return player
	return {}


func _deep_green(pos: Vector2) -> bool:
	var body = planet(str(defs.system.zones.green.anchor))
	if body == null:
		return false
	return pos.distance_to(body.pos) < float(defs.system.zones.green.radius) - 260.0


func _in_trash(pos: Vector2) -> bool:
	var spread := float(defs.system.trash.get("spread", 150.0))
	return pos.distance_to(trash_pos) <= spread + 40.0


func _kill(unit: Dictionary, attacker: String) -> void:
	sfx("destroyed")
	if str(unit.get("controller", "")) == "human":
		var dropped := _split_cargo(unit)
		wrecks.append({
			"id": "wreck_%d" % wrecks.size(),
			"agent_id": unit.agent_id,
			"controller": unit.controller,
			"team": unit.team,
			"class_id": unit.class_id,
			"pos": unit.pos,
			"cargo": dropped,
			"stripped": false,
			"name": unit.name,
		})
		_respawn_captain(unit)
		return
	unit.alive = false
	unit.hp = 0.0
	unit.thrusting = false
	var cargo: Dictionary = {}
	if unit.has("cargo"):
		cargo = unit.cargo.duplicate(true)
	wrecks.append({
		"id": "wreck_%d" % wrecks.size(),
		"agent_id": unit.agent_id,
		"controller": unit.controller,
		"team": unit.team,
		"class_id": unit.class_id,
		"pos": unit.pos,
		"cargo": cargo,
		"stripped": false,
		"name": unit.name,
	})
	if str(unit.team) == "red_keel":
		var provoked := bool(unit.ai.get("fired_on_captain", false))
		if provoked:
			var eased := maxf(0.0, float(heat.get(_pdo_id(), 0.0)) - 5.0)
			heat[_pdo_id()] = eased
			say("They fired first. The slate eases.")
		elif _in_trash(unit.pos):
			Ownership.add_heat(self, _pdo_id(), 6.0, "killed_in_seized", attacker)
			say("That wreck was seized property. The slate takes a little.")
		Ownership.add_heat(self, "red_keel", 10.0, "killed_a_skiff", attacker)
		for actor in actors:
			if str(actor.team) == "red_keel" and bool(actor.alive):
				actor.ai.enraged = true
		say("Red Keel will remember %s." % unit.name)
	elif str(unit.team) == _pdo_id():
		Ownership.add_heat(self, _pdo_id(), 36.0, "killed_patrol", attacker)
		pdo_alert = true
		banner = "%s: \"Patrol blood. The lane is closed to you.\"" % _pdo_name()
		banner_t = 0.0
		say("A Compact cutter is gone. The slate does not forget.")


func _split_cargo(unit: Dictionary) -> Dictionary:
	var dropped := {}
	var kept := {}
	for key in unit.cargo.keys():
		var n := int(unit.cargo[key])
		if n <= 0:
			continue
		var lose := int(n / 2)
		if lose < 1:
			lose = 1
		if lose > n:
			lose = n
		dropped[str(key)] = lose
		var remain := n - lose
		if remain > 0:
			kept[str(key)] = remain
	unit.cargo = kept
	return dropped


func _respawn_captain(unit: Dictionary) -> void:
	var dock = planet(str(defs.system.pdo.home))
	unit.alive = true
	unit.thrusting = false
	unit.vel = Vector2.ZERO
	unit.hp = maxf(1.0, float(unit.max_hp) * 0.45)
	var nudge := 0.0
	if str(unit.agent_id) != str(player.agent_id):
		nudge = 90.0
	if dock != null:
		unit.pos = dock.pos + Vector2(float(dock.radius) + DOCK_GAP, 40.0 + nudge)
		unit.rot = (unit.pos - dock.pos).angle()
	if str(unit.agent_id) == str(player.agent_id):
		banner = "You wake at %s. The wreck still has your name, and some of the hold." % str(defs.system.name)
		say("The keel broke. Layout kept. You are back on the dock.")
	else:
		banner = "%s wakes at %s. The wreck still has their name, and some of the hold." % [str(unit.name), str(defs.system.name)]
		say("%s broke. The layout stays. The ship was not deleted." % str(unit.name))
	banner_t = 0.0


func _add_cargo(id: String, count: int) -> void:
	player.cargo[id] = int(player.cargo.get(id, 0)) + count


func _scale_sky() -> void:
	var authored_star := float(defs.system.star.radius)
	var inner_dist := 12000.0
	var inner_radius := 0.0
	for body in planets:
		var row: Dictionary = body
		var dist := float(row.distance)
		var rad := float(row.radius)
		if dist < inner_dist - 0.5:
			inner_dist = dist
			inner_radius = rad
		elif absf(dist - inner_dist) <= 8.0:
			inner_radius = maxf(inner_radius, rad)
	var star_want := authored_star * BODY_SCALE
	var star_room := inner_dist - inner_radius * BODY_SCALE - 220.0
	if star_room < authored_star:
		star_radius = authored_star
	else:
		star_radius = minf(star_want, star_room)
	var pdo: Dictionary = defs.system.get("pdo", {})
	var home := str(pdo.get("home", ""))
	var pdo_n := int(pdo.get("count", 0))
	var pdo_r := float(pdo.get("radius", 0.0))
	var zones: Dictionary = defs.system.get("zones", {})
	var green: Dictionary = zones.get("green", {})
	var green_anchor := str(green.get("anchor", ""))
	var green_reach := float(green.get("radius", 0.0))
	var haul_limit := {}
	for entry in defs.system.get("haulers", []):
		var haul: Dictionary = entry
		var hid := str(haul.get("home", ""))
		var hr := float(haul.get("radius", 9000.0))
		if haul_limit.has(hid) == false or hr < float(haul_limit[hid]):
			haul_limit[hid] = hr
	var gate_limit := {}
	for entry in defs.system.get("gates", []):
		var gate: Dictionary = entry
		var gid := str(gate.get("anchor", ""))
		if gid == "":
			continue
		var gd := float(gate.get("distance", 9000.0))
		if gate_limit.has(gid) == false or gd < float(gate_limit[gid]):
			gate_limit[gid] = gd
	var pocket: Dictionary = defs.system.get("pocket", {})
	var pocket_anchor := str(pocket.get("anchor", ""))
	var pocket_gap := float(pocket.get("distance", 9000.0)) - float(pocket.get("radius", 0.0)) - 50.0
	for body in planets:
		var row: Dictionary = body
		var authored := float(row.radius)
		var bid := str(row.id)
		var cap := authored * BODY_SCALE
		var room := float(row.distance) - star_radius - 160.0
		cap = minf(cap, maxf(authored, room))
		if bid == home and pdo_n > 0 and pdo_r > 40.0:
			cap = minf(cap, maxf(authored, pdo_r - 110.0))
		if bid == green_anchor and green_reach > 80.0:
			cap = minf(cap, maxf(authored, green_reach - DOCK_GAP - 90.0))
		if haul_limit.has(bid):
			cap = minf(cap, maxf(authored, float(haul_limit[bid]) - 90.0))
		if gate_limit.has(bid):
			cap = minf(cap, maxf(authored, float(gate_limit[bid]) - 140.0))
		if bid == pocket_anchor and pocket_gap > authored:
			cap = minf(cap, pocket_gap)
		row.radius = maxf(authored, cap)


func _build_static() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	planets = []
	for source in defs.system.planets:
		var body: Dictionary = source.duplicate(true)
		body.pos = Vector2.from_angle(float(body.angle)) * float(body.distance)
		body.radius = float(body.radius)
		planets.append(body)
	_scale_sky()
	var anchor = planet(str(defs.system.pocket.anchor))
	pocket_pos = anchor.pos + Vector2.from_angle(float(defs.system.pocket.angle)) * float(defs.system.pocket.distance)
	nest_pos = Vector2.from_angle(float(defs.system.nest.angle)) * float(defs.system.nest.distance)
	asteroids = []
	trash = []
	var field: Dictionary = defs.system.get("trash", {})
	trash_pos = Vector2.ZERO
	if int(field.get("count", 0)) > 0:
		var anchor_body = planet(str(field.get("anchor", "")))
		var origin := Vector2.ZERO
		if anchor_body != null:
			origin = anchor_body.pos + Vector2.from_angle(float(field.angle)) * float(field.distance)
		trash_pos = origin
		var spread := float(field.get("spread", 120.0))
		for i in int(field.count):
			var jitter := Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread * 0.55, spread * 0.55))
			trash.append({
				"pos": origin + jitter,
				"rot": rng.randf() * TAU,
				"kind": i % 3,
				"scale": rng.randf_range(0.85, 1.55),
				"origin": str(field.get("origin", "")),
			})
	var belt: Dictionary = defs.system.belt
	var composition := str(belt.get("composition", ""))
	var tint := _belt_tint(composition)
	for i in int(belt.count):
		var ang = rng.randf() * TAU
		var rad = float(belt.radius) + rng.randf_range(-float(belt.width), float(belt.width))
		var center = Vector2.from_angle(ang) * rad
		var size = (rng.randf_range(7.0, 16.0) + float(i % 5) * 1.4) * ROCK_SCALE
		var rot = rng.randf() * TAU
		var verts = PackedVector2Array()
		var sides = 5 + (i + composition.length()) % 4
		for s in sides:
			var a = rot + float(s) / float(sides) * TAU
			var rr = size * rng.randf_range(0.55, 1.25)
			verts.append(center + Vector2.from_angle(a) * rr)
		asteroids.append({
			"pos": center,
			"verts": verts,
			"size": size,
			"composition": composition,
			"tint": tint,
		})
	_build_meteors(rng)
	stars = []
	for _i in 420:
		var ang = rng.randf() * TAU
		var rad = rng.randf_range(200.0, 9200.0)
		stars.append({
			"pos": Vector2.from_angle(ang) * rad,
			"a": rng.randf_range(0.2, 0.85),
			"r": rng.randf_range(0.8, 1.8),
		})
	var dock = planet(str(defs.system.pdo.get("home", "")))
	beacon_pos = Vector2.ZERO
	if dock != null:
		beacon_pos = dock.pos + Vector2(float(dock.radius) + 430.0, -160.0)
	var green_body = planet(str(defs.system.zones.green.anchor))
	var pirates: Dictionary = defs.system.get("pirates", {})
	var stand := float(pirates.get("standoff", 620.0))
	var pang := float(pirates.get("angle", 2.2))
	var green_r := float(defs.system.zones.green.radius)
	pack_pos = Vector2.from_angle(pang) * (green_r + stand)
	if green_body != null:
		pack_pos = green_body.pos + Vector2.from_angle(pang) * (green_r + stand)
	_build_gates()
	_build_nodes()


func nearby_gate() -> Dictionary:
	var best: Dictionary = {}
	var best_d := 100000.0
	for gate in gates:
		var row: Dictionary = gate
		var reach := float(row.get("radius", 80.0))
		var dist: float = player.pos.distance_to(row.pos)
		if dist <= reach and dist < best_d:
			best = row
			best_d = dist
	return best


func try_lane() -> String:
	var gate := nearby_gate()
	if gate.is_empty():
		return "No lane buoy in reach."
	for item in craft:
		var state := str(item.state)
		if state != "docked" and state != "lost":
			return "Recall %s. The lane does not carry craft home." % str(item.name)
	var dest := str(gate.get("to", ""))
	var chart: Dictionary = defs.get("systems", {})
	if not chart.has(dest):
		return "That lane is charted and not on this keel's board."
	_arrive(dest, str(gate.get("arrive", "")))
	return ""


func _arrive(system_id: String, gate_id: String) -> void:
	if bool(defs.get("live_catalog", false)):
		Catalog.refresh(defs)
	if not defs.systems.has(system_id):
		say("That lane is charted and not on this keel's board.")
		return
	defs.system = defs.systems[system_id]
	seed_value = int(defs.system.seed)
	projectiles = []
	wrecks = []
	actors = []
	_build_static()
	_spawn_factions()
	var spot := _gate_by_id(gate_id)
	if not spot.is_empty():
		var ang := float(spot.get("angle", 0.0))
		player.pos = spot.pos + Vector2.from_angle(ang) * (float(spot.get("radius", 80.0)) + 120.0)
		player.vel = Vector2.ZERO
		player.rot = ang + PI
	else:
		player.vel = Vector2.ZERO
		if not planets.is_empty():
			var body = planets[0]
			player.pos = body.pos + Vector2(float(body.radius) + 280.0, -40.0)
	var seat := 1
	for mate in captains:
		mate.pos = player.pos + Vector2(80.0 * float(seat), 24.0)
		mate.vel = Vector2.ZERO
		seat += 1
	for item in craft:
		var state := str(item.state)
		if state == "lost" or state == "docked":
			continue
		item.state = "lost"
		item.hp = 0.0
		item.vel = Vector2.ZERO
		item.order = ""
		item.target = ""
		say("%s was left behind the lane. It did not jump home." % str(item.name))
	if not visited.has(system_id):
		visited.append(system_id)
	say("The lane opens on %s." % str(defs.system.name))
	sfx("launch")
	Catalog.confiscate(self)
	QuestBoard.on_arrive(self)


func _gate_by_id(gate_id: String) -> Dictionary:
	for gate in gates:
		var row: Dictionary = gate
		if str(row.get("id", "")) == gate_id:
			return row
	return {}


func _build_gates() -> void:
	gates = []
	for source in defs.system.get("gates", []):
		var row: Dictionary = source.duplicate(true)
		var anchor = planet(str(row.get("anchor", "")))
		var origin := Vector2.ZERO
		if anchor != null:
			origin = anchor.pos
		var ang := float(row.get("angle", 0.0))
		row.pos = origin + Vector2.from_angle(ang) * float(row.get("distance", 0.0))
		row.radius = float(row.get("radius", 80.0))
		gates.append(row)


func _build_nodes() -> void:
	nodes = []
	for source in defs.system.get("nodes", []):
		var row: Dictionary = source.duplicate(true)
		var anchor_body = planet(str(row.get("anchor", "")))
		var origin := Vector2.ZERO
		if anchor_body != null:
			origin = anchor_body.pos
		var kind := str(row.get("kind", ""))
		if kind == "planet" and anchor_body != null:
			row.pos = anchor_body.pos
			row.radius = float(anchor_body.radius)
			row.solid = true
		elif kind == "ring" and anchor_body != null:
			var ang := float(row.get("angle", 0.15))
			var band := float(row.get("band", 43.0))
			row.pos = anchor_body.pos + Vector2.from_angle(ang) * (float(anchor_body.radius) + band)
			row.radius = 28.0
			row.solid = false
		else:
			var ang := float(row.get("angle", 0.0))
			var dist := float(row.get("distance", 0.0))
			row.pos = origin + Vector2.from_angle(ang) * dist
			row.radius = float(row.get("radius", 40.0))
			row.solid = false
		nodes.append(row)
		deposits[str(row.id)] = int(row.resource.amount)


func _spawn_factions() -> void:
	var faction_id := _pdo_id()
	var home_body = planet(str(defs.system.pdo.get("home", "")))
	var home := Vector2.ZERO
	if home_body != null:
		home = home_body.pos
	for i in int(defs.system.pdo.count):
		var actor = _blank_ship("cutter", "%s Cutter %d" % [_pdo_name(), i + 1], "agent:%s:%d" % [faction_id, i], "npc", faction_id)
		var ang = float(i) * PI
		actor.home = home
		actor.pos = actor.home + Vector2.from_angle(ang) * float(defs.system.pdo.radius)
		actor.rot = ang + PI * 0.5
		actor.ai = {"phase": ang, "radius": float(defs.system.pdo.radius), "enraged": false}
		actor.cargo = {"scrap": 1}
		actors.append(actor)
	if bool(quest_flags.get("patrol_reinforced", false)) and int(defs.system.pdo.count) > 0:
		var extra = _blank_ship("cutter", "%s Cutter %d" % [_pdo_name(), int(defs.system.pdo.count) + 1], "agent:%s:extra" % faction_id, "npc", faction_id)
		extra.home = home
		extra.pos = home + Vector2(float(defs.system.pdo.radius), 80.0)
		extra.rot = PI * 0.5
		extra.ai = {"phase": 0.4, "radius": float(defs.system.pdo.radius), "enraged": false}
		extra.cargo = {"scrap": 1}
		actors.append(extra)
	for entry in defs.system.get("haulers", []):
		var hauler = _blank_ship(str(entry.class_id), str(entry.name), "agent:civilian:%s" % entry.id, "npc", "civilian")
		var orbit = float(entry.radius)
		var phase = 0.9
		var yard = planet(str(entry.home))
		hauler.home = Vector2.ZERO
		if yard != null:
			hauler.home = yard.pos
		hauler.pos = hauler.home + Vector2.from_angle(phase) * orbit
		hauler.rot = phase + PI * 0.5
		hauler.ai = {"phase": phase, "radius": orbit, "enraged": false}
		actors.append(hauler)
	var pack_count := int(defs.system.pirates.count)
	var roles := ["interceptor", "kite", "raider"]
	var bolted := ["gun_sponson", "sensor_mast", "cargo_blister"]
	for i in pack_count:
		var actor = _blank_ship("skiff", "Red Keel %d" % (i + 1), "agent:red_keel:%d" % i, "npc", "red_keel")
		var ang = float(i) / float(maxi(pack_count, 1)) * TAU
		var part: String = bolted[i % bolted.size()]
		actor.home = pack_pos
		actor.pos = pack_pos + Vector2.from_angle(ang) * 90.0
		actor.rot = ang
		actor.modules = [part]
		actor.module_hp = {part: 22.0}
		actor.ai = {
			"phase": ang,
			"radius": 140.0,
			"enraged": false,
			"role": roles[i % roles.size()],
			"chase": 0.0,
			"fired_on_captain": false,
		}
		actor.cargo = {"scrap": 1}
		actors.append(actor)


func human_by_agent(agent_id: String):
	if str(player.get("agent_id", "")) == agent_id:
		return player
	for mate in captains:
		if str(mate.get("agent_id", "")) == agent_id:
			return mate
	return null


func human_by_player(player_id: String):
	if str(player.get("player_id", "")) == player_id:
		return player
	for mate in captains:
		if str(mate.get("player_id", "")) == player_id:
			return mate
	return null


func admit(class_id: String, player_id: String) -> Dictionary:
	if not defs.ships.has(class_id):
		class_id = "vesper"
	var hull: Dictionary = defs.ships[class_id]
	var ship: Dictionary = _blank_ship(class_id, str(hull.callsign), "agent:%s" % player_id, "human", "captain")
	ship.player_id = player_id
	ship.yard = hull.yard.duplicate()
	ship.slots = hull.slots.duplicate()
	ship.crew = hull.crew.duplicate(true)
	ship.cargo = {"claim_core": 1}
	ship.pos = player.pos + Vector2(140.0, -36.0)
	ship.vel = Vector2.ZERO
	ship.rot = player.rot
	ship.dock_x = ship.pos.x
	ship.dock_y = ship.pos.y
	ship.hangar_hp = 22.0
	ship.hangar_max = 22.0
	captains.append(ship)
	say("%s joins the dock. Same hull, same HP, same module rules." % str(hull.callsign))
	return ship


func post_chat(who: String, text: String) -> void:
	var line := text.strip_edges()
	if line == "":
		return
	if line.length() > 140:
		line = line.substr(0, 140)
	chat.append({"player_id": who, "text": line})
	if chat.size() > 8:
		chat.pop_front()
	say("%s: %s" % [who, line])


func net_snapshot() -> Dictionary:
	var people: Array = [_ship_out(player)]
	for row in _captain_rows():
		people.append(row)
	var actor_rows: Array = []
	for actor in actors:
		actor_rows.append(_ship_out(actor))
	var shots: Array = []
	for shot in projectiles:
		var row: Dictionary = shot.duplicate(true)
		row.pos = Serde.vec_out(shot.pos)
		row.vel = Serde.vec_out(shot.vel)
		shots.append(row)
	var craft_rows: Array = []
	for item in craft:
		craft_rows.append(_craft_out(item))
	var wreck_rows: Array = []
	for wreck in wrecks:
		var row: Dictionary = wreck.duplicate(true)
		row.pos = Serde.vec_out(wreck.pos)
		wreck_rows.append(row)
	var crack: Dictionary = claim.get("crack", {})
	return {
		"system_id": str(defs.system.id),
		"time": time,
		"captains": people,
		"actors": actor_rows,
		"projectiles": shots,
		"craft": craft_rows,
		"wrecks": wreck_rows,
		"law_target": law_target,
		"heat": heat.duplicate(true),
		"heat_agent": str(player.agent_id),
		"chat": chat.duplicate(true),
		"claim": {
			"slot_id": str(claim.get("slot_id", "")),
			"agent_id": str(claim.get("agent_id", "")),
			"owner_name": str(claim.get("owner_name", "")),
			"owned": bool(claim.get("owned", false)),
			"core": bool(claim.get("core", false)),
			"frozen": bool(claim.get("frozen", false)),
			"system_id": str(claim.get("system_id", "")),
			"pocket_id": str(claim.get("pocket_id", "")),
			"pocket_name": str(claim.get("pocket_name", "")),
			"x": float(claim.get("x", 0.0)),
			"y": float(claim.get("y", 0.0)),
			"locked_out": claim.get("locked_out", []).duplicate(),
			"flare": bool(claim.get("flare", false)),
			"crack": crack.duplicate(true),
		},
	}


func apply_snapshot(data: Dictionary) -> void:
	var sid := str(data.get("system_id", ""))
	var chart: Dictionary = defs.get("systems", {})
	if sid != "" and chart.has(sid) and str(defs.system.id) != sid:
		defs.system = chart[sid]
		seed_value = int(defs.system.seed)
		_build_static()
	var local_pid := str(player.get("player_id", ""))
	var next: Array = []
	for row in data.get("captains", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var ship: Dictionary = _ship_in(row)
		if str(ship.get("player_id", "")) == local_pid and local_pid != "":
			player = ship
		else:
			next.append(ship)
	captains = next
	actors = []
	for row in data.get("actors", []):
		if typeof(row) == TYPE_DICTIONARY:
			actors.append(_ship_in(row))
	projectiles = []
	for row in data.get("projectiles", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var shot: Dictionary = row.duplicate(true)
		shot.pos = Serde.vec_in(shot.pos)
		shot.vel = Serde.vec_in(shot.vel)
		projectiles.append(shot)
	craft = []
	for row in data.get("craft", []):
		if typeof(row) == TYPE_DICTIONARY:
			craft.append(_craft_in(row))
	wrecks = []
	for row in data.get("wrecks", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var wreck: Dictionary = row.duplicate(true)
		wreck.pos = Serde.vec_in(wreck.pos)
		wrecks.append(wreck)
	var claim_row: Dictionary = data.get("claim", {})
	for key in claim_row.keys():
		claim[key] = claim_row[key]
	law_target = str(data.get("law_target", ""))
	chat = data.get("chat", []).duplicate(true)
	time = float(data.get("time", time))
	if str(player.get("agent_id", "")) != str(data.get("heat_agent", "")):
		heat[_pdo_id()] = float(player.get("heat_compact", 0.0))
	elif data.has("heat"):
		heat = data.heat.duplicate(true)
		for key in heat.keys():
			heat[key] = float(heat[key])


func _captain_rows() -> Array:
	var rows: Array = []
	for mate in captains:
		rows.append(_ship_out(mate))
	return rows


func _apply_verbs(unit: Dictionary, cmd: Dictionary) -> void:
	if bool(cmd.get("crack", false)):
		var cracked := Homestead.try_crack(self, unit)
		if cracked != "":
			say(cracked)
	if bool(cmd.get("hail", false)):
		var hailed_line := Homestead.try_hail(self, unit)
		if hailed_line != "":
			say(hailed_line)
	if bool(cmd.get("flag", false)):
		unit.flagged = not bool(unit.get("flagged", false))
		if str(unit.get("agent_id", "")) == str(player.agent_id):
			say("Hunt flag up." if bool(unit.flagged) else "Hunt flag down.")
	var spoken := str(cmd.get("chat", ""))
	if spoken != "":
		post_chat(str(unit.get("player_id", "")), spoken)


func _clear_oneshots() -> void:
	for key in commands.keys():
		var row: Dictionary = commands[key]
		row.erase("crack")
		row.erase("hail")
		row.erase("flag")
		row.erase("chat")
		commands[key] = row


func _arm_grace(unit: Dictionary, dt: float) -> void:
	if str(unit.get("controller", "")) != "human":
		return
	if not bool(unit.get("grace_armed", false)):
		var origin := Vector2(float(unit.get("dock_x", unit.pos.x)), float(unit.get("dock_y", unit.pos.y)))
		var moved: float = unit.pos.distance_to(origin)
		if moved > 40.0 or unit.vel.length() > 12.0:
			unit.grace_armed = true
			unit.grace_t = 28.0
			if str(unit.get("agent_id", "")) == str(player.agent_id):
				say("Green grace. Helion Dock will not claim-wipe a new keel.")
		return
	if float(unit.get("grace_t", 0.0)) > 0.0:
		unit.grace_t = maxf(0.0, float(unit.grace_t) - dt)


func _heat_for(unit) -> float:
	if unit == null:
		return 0.0
	if str(unit.get("agent_id", "")) == str(player.get("agent_id", "")):
		return float(heat.get(_pdo_id(), 0.0))
	return float(unit.get("heat_compact", 0.0))


func _law_quarry():
	if law_target != "":
		var marked = human_by_agent(law_target)
		if marked != null and bool(marked.get("alive", false)):
			if _heat_for(marked) >= 40.0 or bool(marked.get("alert", false)) or bool(marked.get("warrant", false)):
				return marked
	if (pdo_alert or float(heat.get(_pdo_id(), 0.0)) >= 40.0) and bool(player.alive):
		return player
	for mate in captains:
		if bool(mate.get("alive", false)) and float(mate.get("heat_compact", 0.0)) >= 40.0:
			return mate
	return null


func _friendly_fire(shot: Dictionary, unit: Dictionary) -> bool:
	if str(unit.get("team", "")) != str(shot.get("team", "")):
		return false
	if str(unit.get("controller", "")) == "human" and str(shot.get("agent_id", "")) != str(unit.get("agent_id", "")):
		return false
	return true


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
		"yard": [],
		"slots": [],
		"crew": [],
		"fire_cd": 0.0,
		"hurt_cd": 0.0,
		"fight_cd": 0.0,
		"hangar_hp": 22.0,
		"hangar_max": 22.0,
		"module_hp": {},
		"alive": true,
		"thrusting": false,
		"home": Vector2.ZERO,
		"ai": {},
		"muzzle": 34.0,
		"player_id": "",
		"warrant": false,
		"flagged": false,
		"grace_t": 0.0,
		"grace_armed": false,
		"heat_compact": 0.0,
		"alert": false,
		"dock_x": 0.0,
		"dock_y": 0.0,
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
		"order": "",
		"did_job": false,
		"fire_cd": 0.0,
		"gun": spec.get("gun", {}).duplicate(true),
		"muzzle": 16.0,
	}


func _dossier(node_id: String) -> Dictionary:
	if scans.has(node_id):
		return scans[node_id]
	var row = survey_node(node_id)
	var layers = {}
	var source: Dictionary = row.layers
	for key in ["orbit", "atmosphere", "surface", "crust", "biosign", "ruins", "legal"]:
		layers[key] = {"known": false, "text": str(source[key])}
	scans[node_id] = {
		"node_id": node_id,
		"name": row.name,
		"layers": layers,
		"complete": false,
		"legal": str(row.legal_title),
		"resource_id": row.resource.id,
		"resource_name": row.resource.name,
	}
	return scans[node_id]


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
	ship.fight_cd = float(ship.get("fight_cd", 0.0))
	ship.hangar_hp = float(ship.get("hangar_hp", 22.0))
	ship.hangar_max = float(ship.get("hangar_max", 22.0))
	if not ship.has("module_hp"):
		ship.module_hp = {}
	ship.alive = bool(ship.alive)
	ship.thrusting = false
	if not ship.has("muzzle"):
		ship.muzzle = 34.0
	for key in ship.cargo.keys():
		ship.cargo[key] = int(ship.cargo[key])
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
	if not item.has("order"):
		item.order = ""
	if not item.has("max_hp"):
		item.max_hp = int(item.hp)
	return item


func _belt_tint(composition: String) -> String:
	if composition == "":
		return "#3a342c"
	var tones := ["#6a5344", "#8a6a3a", "#4e5c68", "#7a4e3a", "#5c6848", "#6e5a68", "#3e4a44"]
	return tones[int(abs(composition.hash())) % tones.size()]


func _build_meteors(rng: RandomNumberGenerator) -> void:
	meteors = []
	stream_origin = Vector2.ZERO
	var spec: Dictionary = defs.system.get("stream", {})
	if spec.is_empty() or str(spec.get("id", "")) == "":
		return
	var anchor = planet(str(spec.get("anchor", "")))
	var origin := Vector2.ZERO
	if anchor != null:
		origin = anchor.pos
	stream_origin = origin + Vector2.from_angle(float(spec.get("angle", 0.0))) * float(spec.get("distance", 0.0))
	var count := 7
	for i in count:
		meteors.append({
			"phase": float(i) / float(count),
			"offset": Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-28.0, 28.0)),
			"size": rng.randf_range(3.0, 8.0),
			"pos": stream_origin,
		})


func _step_stream(dt: float) -> void:
	var spec: Dictionary = defs.system.get("stream", {})
	if spec.is_empty() or str(spec.get("id", "")) == "":
		return
	var period := maxf(float(spec.get("period", 12.0)), 0.1)
	var span := float(spec.get("span", float(spec.get("speed", 70.0)) * period))
	var along := fmod(time, period) / period * span
	var vector := Vector2.from_angle(float(spec.get("vector", 0.0)))
	var node = survey_node(str(spec.id))
	if node != null:
		node.pos = stream_origin + vector * along
	for rock in meteors:
		var phase := float(rock.phase)
		var walk := fmod(along + phase * span, span)
		rock.pos = stream_origin + vector * walk + rock.offset


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
