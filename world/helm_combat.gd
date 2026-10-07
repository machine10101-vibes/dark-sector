class_name HelmCombat
extends RefCounted

## Tank layers, capacitor, thermal load, target locks, turret aim, and helm
## orders. Every keel and every NPC runs through the same rules. The host sim
## owns all of it; guests only send lock and order verbs.

const SHIELD_DELAY := 3.0
const THERM_MAX := 100.0
const THERM_RESET := 35.0
const BOOST_THERM := 3.0
const ORDER_KINDS := ["approach", "orbit", "keep", "stop"]
const ORBIT_DEFAULT := 320.0
const KEEP_DEFAULT := 450.0
const APPROACH_STAND := 160.0


static func ensure_tank(sim, unit: Dictionary, stats: Dictionary = {}) -> void:
	if stats.is_empty():
		stats = Fit.stats(sim.defs, unit)
	if not unit.has("shield"):
		unit.shield = float(stats.shield_max)
	if not unit.has("armor_hp"):
		unit.armor_hp = float(stats.armor_max)
	if not unit.has("cap"):
		unit.cap = float(stats.cap_max)
	for pair in [["shield", "shield_max"], ["armor_hp", "armor_max"], ["cap", "cap_max"]]:
		var grown := float(stats[pair[1]]) - float(unit.get(pair[1], stats[pair[1]]))
		if grown > 0.0:
			unit[pair[0]] = float(unit[pair[0]]) + grown
	unit.shield_max = float(stats.shield_max)
	unit.armor_max = float(stats.armor_max)
	unit.cap_max = float(stats.cap_max)
	unit.shield = clampf(float(unit.shield), 0.0, float(unit.shield_max))
	unit.armor_hp = clampf(float(unit.armor_hp), 0.0, float(unit.armor_max))
	unit.cap = clampf(float(unit.cap), 0.0, float(unit.cap_max))
	if not unit.has("therm"):
		unit.therm = 0.0
	if not unit.has("overheat"):
		unit.overheat = false
	if not unit.has("tank_cd"):
		unit.tank_cd = 0.0
	if not unit.has("lock_id"):
		unit.lock_id = ""
		unit.lock_t = 0.0
		unit.lock_ok = false
		unit.lock_need = 0.0
	if not unit.has("order"):
		unit.order = {}


static func refill(unit: Dictionary, hull_share: float = 1.0) -> void:
	unit.shield = float(unit.get("shield_max", 0.0))
	unit.armor_hp = float(unit.get("armor_max", 0.0)) * hull_share
	unit.cap = float(unit.get("cap_max", 0.0))
	unit.therm = 0.0
	unit.overheat = false


static func step_systems(sim, unit: Dictionary, stats: Dictionary, dt: float, boosting: bool) -> void:
	ensure_tank(sim, unit, stats)
	unit.tank_cd = maxf(0.0, float(unit.tank_cd) - dt)
	if float(unit.tank_cd) <= 0.0:
		unit.shield = minf(float(unit.shield_max), float(unit.shield) + float(stats.shield_regen) * dt)
	unit.cap = minf(float(unit.cap_max), float(unit.cap) + float(stats.cap_regen) * dt)
	var load := BOOST_THERM * dt if boosting else 0.0
	unit.therm = clampf(float(unit.therm) + load - float(stats.cooling) * dt, 0.0, THERM_MAX)
	if bool(unit.overheat) and float(unit.therm) <= THERM_RESET:
		unit.overheat = false
		if _is_local(sim, unit):
			sim.say("Guns cool. Fire control is back.")


static func effective_signature(sim, unit: Dictionary) -> float:
	var sig := float(Fit.stats(sim.defs, unit).signature)
	return sig * (1.0 + 0.5 * float(unit.get("therm", 0.0)) / THERM_MAX)


static func ensure_rounds(unit: Dictionary) -> void:
	if not unit.has("rounds"):
		unit.rounds = {
			"iron": 40,
			"tungsten": 0,
			"incendiary": 0,
			"splinter": 8,
			"breacher": 0,
			"siege": 0,
		}
	if not unit.has("belt"):
		unit.belt = "iron"
	if not unit.has("crystal"):
		unit.crystal = "standard"
	if not unit.has("rack"):
		unit.rack = "splinter"


## How a load bites each tank layer. 1.0 is the bare gun. Empty profile stays even.
static func layer_bias(profile: Dictionary) -> Dictionary:
	var bias := {"shield": 1.0, "armor": 1.0, "hull": 1.0, "heat": 0.0}
	var family := str(profile.get("family", ""))
	var load := str(profile.get("load", ""))
	var small := float(profile.get("signature", 1.0))
	if family == "bullet":
		if load == "tungsten":
			bias = {"shield": 0.62, "armor": 1.5, "hull": 0.85, "heat": 0.0}
		elif load == "incendiary":
			bias = {"shield": 0.4, "armor": 0.85, "hull": 1.0, "heat": 16.0}
		elif load == "iron":
			bias = {"shield": 0.9, "armor": 0.72, "hull": 1.25, "heat": 0.0}
	elif family == "laser":
		if load == "infrared":
			bias = {"shield": 0.75, "armor": 0.7, "hull": 0.8, "heat": 0.0}
		elif load == "ultraviolet":
			bias = {"shield": 1.75, "armor": 0.5, "hull": 0.45, "heat": 0.0}
		elif load == "standard":
			bias = {"shield": 1.15, "armor": 0.9, "hull": 0.8, "heat": 0.0}
	elif family == "missile":
		if load == "breacher":
			bias = {"shield": 0.5, "armor": 1.65, "hull": 0.75, "heat": 0.0}
		elif load == "siege":
			bias = {"shield": 1.05, "armor": 1.15, "hull": 1.35, "heat": 0.0}
			if small < 0.5:
				bias.shield = 0.45
				bias.armor = 0.45
				bias.hull = 0.4
		elif load == "splinter":
			bias = {"shield": 0.85, "armor": 0.8, "hull": 1.1, "heat": 0.0}
			if small < 0.55:
				bias.hull = 1.45
	return bias


## Shield first, then armor plate, then the hull. Returns what the hull takes.
static func absorb(sim, unit: Dictionary, amount: float, profile: Dictionary = {}) -> float:
	if not unit.has("shield"):
		ensure_tank(sim, unit)
	var bias := layer_bias(profile)
	unit.tank_cd = SHIELD_DELAY
	var left := amount
	var layer := "hull"
	var sh := float(unit.shield)
	if sh > 0.0:
		var bite := left * float(bias.shield)
		var take := minf(sh, bite)
		unit.shield = sh - take
		left -= take / maxf(0.05, float(bias.shield))
		layer = "shield"
	var ar := float(unit.armor_hp)
	if left > 0.0 and ar > 0.0:
		var plate_bite := left * float(bias.armor)
		var plate := minf(ar, plate_bite)
		unit.armor_hp = ar - plate
		left -= plate / maxf(0.05, float(bias.armor))
		layer = "armor"
	if left > 0.0:
		left *= float(bias.hull)
		layer = "hull"
	if float(bias.heat) > 0.0 and amount > 0.0:
		unit.therm = float(unit.get("therm", 0.0)) + float(bias.heat)
		if float(unit.therm) >= THERM_MAX:
			unit.therm = THERM_MAX
			unit.overheat = true
	unit.hit_layer = layer
	unit.hit_at = float(sim.time)
	return left


static func can_fire(sim, unit: Dictionary, gun: Dictionary) -> bool:
	if bool(unit.get("overheat", false)):
		return false
	var cost := float(gun.get("cap", 0.0))
	if cost > 0.0 and unit.has("cap") and float(unit.cap) < cost:
		if _is_local(sim, unit) and float(sim.quest_flags.get("dry_note", -20.0)) < float(sim.time) - 4.0:
			sim.quest_flags.dry_note = float(sim.time)
			sim.say("Capacitor dry. Let it climb before the next volley.")
			sim.sfx("dry")
		return false
	return true


static func spend_shot(sim, unit: Dictionary, gun: Dictionary) -> void:
	if unit.has("cap"):
		unit.cap = maxf(0.0, float(unit.cap) - float(gun.get("cap", 0.0)))
	unit.therm = float(unit.get("therm", 0.0)) + float(gun.get("therm", 0.0))
	if float(unit.therm) >= THERM_MAX:
		unit.therm = THERM_MAX
		unit.overheat = true
		if _is_local(sim, unit):
			sim.say("Overheat. Fire control shuts the guns until the plates cool.")
			sim.banner = "OVERHEAT — guns offline"
			sim.banner_t = 6.0


# Targets ------------------------------------------------------------------

static func find_unit(sim, id: String):
	if id == "":
		return null
	if str(sim.player.get("agent_id", "")) == id:
		return sim.player
	for mate in sim.captains:
		if str(mate.get("agent_id", "")) == id:
			return mate
	for actor in sim.actors:
		if str(actor.get("agent_id", "")) == id:
			return actor
	return null


static func targets(sim, unit: Dictionary, reach: float = -1.0) -> Array:
	var rows: Array = []
	if int(sim.layer) != ScaleFrame.BAND:
		return rows
	if reach < 0.0:
		reach = float(Fit.stats(sim.defs, unit).sensor) * 1.6
	var pool: Array = []
	for actor in sim.actors:
		pool.append(actor)
	for mate in sim.captains:
		pool.append(mate)
	pool.append(sim.player)
	for other in pool:
		if str(other.get("agent_id", "")) == str(unit.get("agent_id", "")):
			continue
		if not bool(other.get("alive", false)):
			continue
		var dist: float = unit.pos.distance_to(other.pos)
		if dist > reach:
			continue
		rows.append({"id": str(other.agent_id), "dist": dist, "unit": other})
	rows.sort_custom(func(a, b): return float(a.dist) < float(b.dist))
	return rows


## The mark under a cursor. A tighter disc wins, so a ship in front of a
## planet or a lane buoy on the limb is the thing the click means.
static func pick_mark(at: Vector2, marks: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_gap := 0.0
	var best_rad := 0.0
	for row in marks:
		var spot: Vector2 = row.at
		var rad: float = float(row.rad)
		var gap: float = at.distance_to(spot)
		if gap > rad:
			continue
		var tighter := best.is_empty() or rad < best_rad - 4.0 or (absf(rad - best_rad) <= 4.0 and gap < best_gap)
		if tighter:
			best = row
			best_gap = gap
			best_rad = rad
	return best


static func set_lock(sim, unit: Dictionary, id: String) -> void:
	if str(unit.get("lock_id", "")) == id:
		return
	unit.lock_id = id
	unit.lock_t = 0.0
	unit.lock_ok = false


static func cycle_lock(sim, unit: Dictionary, step: int = 1) -> void:
	var rows := targets(sim, unit)
	if rows.is_empty():
		set_lock(sim, unit, "")
		return
	var current := str(unit.get("lock_id", ""))
	var at := -1
	for i in rows.size():
		if str(rows[i].id) == current:
			at = i
	var next := 0 if at < 0 else posmod(at + step, rows.size())
	set_lock(sim, unit, str(rows[next].id))


static func step_lock(sim, unit: Dictionary, stats: Dictionary, dt: float) -> void:
	var id := str(unit.get("lock_id", ""))
	if id == "":
		unit.lock_t = 0.0
		unit.lock_ok = false
		return
	var other = find_unit(sim, id)
	if other == null or not bool(other.get("alive", false)) or int(sim.layer) != ScaleFrame.BAND:
		if _is_local(sim, unit) and bool(unit.get("lock_ok", false)):
			sim.say("Lock dropped.")
		set_lock(sim, unit, "")
		return
	var dist: float = unit.pos.distance_to(other.pos)
	var reach := float(stats.sensor)
	var need := Fit.lock_time(float(stats.scan_res), effective_signature(sim, other))
	unit.lock_need = need
	if dist > reach * 1.25:
		if _is_local(sim, unit):
			sim.say("%s slipped past sensor range." % str(other.get("name", "Target")))
		set_lock(sim, unit, "")
		return
	if dist > reach:
		unit.lock_t = maxf(0.0, float(unit.lock_t) - dt)
		unit.lock_ok = false
		return
	if not bool(unit.get("lock_ok", false)):
		unit.lock_t = minf(need, float(unit.get("lock_t", 0.0)) + dt)
		if float(unit.lock_t) >= need:
			unit.lock_ok = true
			if _is_local(sim, unit):
				sim.say("Locked %s." % str(other.get("name", "target")))
				sim.sfx("lock")


static func locked_unit(sim, unit: Dictionary):
	if not bool(unit.get("lock_ok", false)):
		return null
	return find_unit(sim, str(unit.get("lock_id", "")))


# Turrets ------------------------------------------------------------------

## Probability a turret shot lands, from angular velocity against tracking
## and range against optimal plus falloff.
static func hit_chance(shooter: Dictionary, other: Dictionary, gun: Dictionary) -> float:
	var rel: Vector2 = other.pos - shooter.pos
	var dist := maxf(1.0, rel.length())
	var rv: Vector2 = other.vel - shooter.vel
	var transversal := absf(rv.cross(rel / dist))
	var omega := transversal / dist
	var track_term := omega / maxf(0.05, float(gun.get("tracking", 0.6)))
	var range_term := maxf(0.0, dist - float(gun.get("optimal", 400.0))) / maxf(1.0, float(gun.get("falloff", 200.0)))
	return pow(0.5, track_term * track_term + range_term * range_term)


static func transversal(shooter: Dictionary, other: Dictionary) -> float:
	var rel: Vector2 = other.pos - shooter.pos
	var dist := maxf(1.0, rel.length())
	var rv: Vector2 = other.vel - shooter.vel
	return absf(rv.cross(rel / dist))


static func _lead(shooter: Dictionary, other: Dictionary, speed: float) -> Vector2:
	var rp: Vector2 = other.pos - shooter.pos
	var rv: Vector2 = other.vel - shooter.vel
	var a := rv.length_squared() - speed * speed
	var b := 2.0 * rp.dot(rv)
	var c := rp.length_squared()
	var t := 0.0
	if absf(a) < 0.001:
		t = -c / b if absf(b) > 0.001 else 0.0
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var root := sqrt(disc)
			var t1 := (-b - root) / (2.0 * a)
			var t2 := (-b + root) / (2.0 * a)
			t = t1 if t1 > 0.0 else t2
			if t1 > 0.0 and t2 > 0.0:
				t = minf(t1, t2)
	if t <= 0.0:
		return rp.normalized()
	return (rp + rv * t).normalized()


## The shot direction for a gun. Nose guns and unlocked turrets fire along the
## nose. A locked turret traverses toward a lead point inside its arc, and a
## failed tracking roll throws the shot just wide of the hull.
static func aim(sim, unit: Dictionary, gun: Dictionary) -> Dictionary:
	var nose := Vector2.from_angle(float(unit.rot))
	var out := {"dir": nose, "turret": false, "chance": -1.0}
	if str(gun.get("kind", "nose")) != "turret":
		return out
	var other = locked_unit(sim, unit)
	if other == null:
		return out
	var dir := _lead(unit, other, float(gun.speed))
	if absf(nose.angle_to(dir)) > float(gun.get("arc", 0.0)):
		return out
	var chance := hit_chance(unit, other, gun)
	var roll := _roll(sim)
	var sure := roll <= chance
	if not sure:
		var dist := maxf(1.0, unit.pos.distance_to(other.pos))
		var size := atan(float(Fit.stats(sim.defs, other).hit_radius) * 1.7 / dist) + 0.02
		var side := 1.0 if _roll(sim) < 0.5 else -1.0
		dir = dir.rotated(size * side)
	unit.turret_aim = dir.angle()
	return {"dir": dir, "turret": true, "chance": chance, "mark": str(other.agent_id) if sure else ""}


## A turret round that won its tracking roll still has to fly to the hull,
## but a target that jinked after the lead was solved does not dodge it.
static func sure_hit(sim, shot: Dictionary, origin: Vector2, dest: Vector2):
	var mark := str(shot.get("mark", ""))
	if mark == "":
		return null
	var other = find_unit(sim, mark)
	if other == null or not bool(other.get("alive", false)):
		return null
	var radius := float(Fit.stats(sim.defs, other).hit_radius) * 2.6
	if sim._shot_reaches(origin, dest, other.pos, radius):
		return other
	return null


static func _roll(sim) -> float:
	var n := int(sim.quest_flags.get("tracking_roll", 0)) + 1
	sim.quest_flags.tracking_roll = n
	var h := hash(Vector3i(int(sim.seed_value), n, 7919))
	return float(posmod(h, 100000)) / 100000.0


# Helm orders --------------------------------------------------------------

static func set_order(sim, unit: Dictionary, order) -> void:
	if typeof(order) != TYPE_DICTIONARY:
		unit.order = {}
		return
	var kind := str(order.get("kind", ""))
	if not ORDER_KINDS.has(kind):
		unit.order = {}
		return
	var row := {"kind": kind, "target": str(order.get("target", ""))}
	match kind:
		"orbit":
			row.range = float(order.get("range", ORBIT_DEFAULT))
		"keep":
			row.range = float(order.get("range", KEEP_DEFAULT))
		"approach":
			row.range = float(order.get("range", APPROACH_STAND))
	if order.has("x") and order.has("y"):
		row.x = float(order.x)
		row.y = float(order.y)
	if str(order.get("label", "")) != "":
		row.label = str(order.label)
	if kind == "stop":
		unit.engage = ""
	if kind != "stop" and row.target == "" and not row.has("x"):
		row.target = str(unit.get("lock_id", ""))
		if row.target == "":
			unit.order = {}
			return
	row.side = 1.0
	unit.order = row
	if _is_local(sim, unit):
		var label := order_label(sim, row)
		if label != "":
			sim.say(label + ".")


static func order_label(sim, order: Dictionary) -> String:
	var kind := str(order.get("kind", ""))
	if kind == "":
		return ""
	var name := "the mark"
	var other = find_unit(sim, str(order.get("target", "")))
	if other != null:
		name = str(other.get("name", "target"))
	else:
		var wreck = sim.wreck_by_id(str(order.get("target", "")))
		if wreck != null:
			name = "wreck of %s" % str(wreck.get("name", "a keel"))
		elif str(order.get("label", "")) != "":
			name = str(order.label)
	match kind:
		"approach":
			return "Approaching %s" % name
		"orbit":
			return "Orbiting %s at %d m" % [name, int(order.get("range", ORBIT_DEFAULT))]
		"keep":
			return "Keeping %s at %d m" % [name, int(order.get("range", KEEP_DEFAULT))]
		"stop":
			return "All stop"
	return ""


static func _order_goal(sim, order: Dictionary) -> Dictionary:
	var id := str(order.get("target", ""))
	if id != "":
		var other = find_unit(sim, id)
		if other != null and bool(other.get("alive", false)):
			return {"pos": Vector2(other.pos), "vel": Vector2(other.vel), "ok": true}
		var wreck = sim.wreck_by_id(id)
		if wreck != null:
			return {"pos": Vector2(wreck.pos), "vel": Vector2.ZERO, "ok": true}
		return {"ok": false}
	if order.has("x"):
		return {"pos": Vector2(float(order.x), float(order.y)), "vel": Vector2.ZERO, "ok": true}
	return {"ok": false}


static func manual_input(cmd: Dictionary) -> bool:
	return absf(float(cmd.get("thrust", 0.0))) > 0.15 \
		or float(cmd.get("retro", 0.0)) > 0.15 \
		or absf(float(cmd.get("strafe", 0.0))) > 0.15 \
		or absf(float(cmd.get("rot", 0.0))) > 0.35 \
		or bool(cmd.get("boost", false))


## Turns a standing order into the same thrust, retro, and yaw a captain
## would hold. Any manual helm input cancels it.
static func steer(sim, unit: Dictionary, cmd: Dictionary, stats: Dictionary) -> Dictionary:
	var order: Dictionary = unit.get("order", {})
	if order.is_empty():
		return cmd
	if manual_input(cmd) or int(sim.layer) != ScaleFrame.BAND or bool(unit.get("moored", false)):
		if manual_input(cmd) and _is_local(sim, unit):
			sim.say("Helm back in hand.")
		unit.order = {}
		return cmd
	var kind := str(order.kind)
	var desired := Vector2.ZERO
	var face := Vector2.ZERO
	var cruise := float(stats.vmax) * 0.8
	if kind != "stop":
		var goal := _order_goal(sim, order)
		if not bool(goal.get("ok", false)):
			if _is_local(sim, unit):
				sim.say("Order target lost. Holding.")
			unit.order = {"kind": "stop", "target": ""}
			return cmd
		var to: Vector2 = goal.pos - unit.pos
		var dist := maxf(1.0, to.length())
		var toward := to / dist
		var carry: Vector2 = goal.vel
		match kind:
			"approach":
				var stand := float(order.get("range", APPROACH_STAND))
				desired = toward * clampf((dist - stand) * 0.7, 0.0, cruise) + carry
			"keep":
				var keep := float(order.get("range", KEEP_DEFAULT))
				desired = toward * clampf((dist - keep) * 0.8, -cruise, cruise) + carry
			"orbit":
				var ring := float(order.get("range", ORBIT_DEFAULT))
				var side := float(order.get("side", 1.0))
				var tangent := toward.orthogonal() * side
				var lap := cruise * 0.85
				desired = tangent * lap + toward * clampf((dist - ring) * 0.9, -cruise, cruise) + carry
		face = toward
	var vel := Vector2(unit.vel)
	var out := cmd.duplicate()
	out.thrust = 0.0
	out.retro = 0.0
	out.rot = 0.0
	if kind == "stop" and vel.length() < 6.0:
		unit.vel = Vector2.ZERO
		unit.order = {}
		return out
	# The hull grip bends the drift onto the nose, so the helm only has to
	# point along the wanted course and set the speed on that line.
	var line := desired
	if line.length() < 20.0:
		line = vel if vel.length() > 6.0 else face
	if line.length() < 0.01:
		return out
	var heading := line.angle()
	out.rot = _yaw_toward(unit, heading)
	var nose := Vector2.from_angle(float(unit.rot))
	var along := desired.dot(line.normalized()) - vel.dot(nose)
	var lined := absf(wrapf(heading - float(unit.rot), -PI, PI)) < 0.45
	if along > 4.0 and lined:
		out.thrust = clampf(along / 60.0, 0.2, 1.0)
	elif along < -4.0:
		out.retro = clampf(-along / 60.0, 0.2, 1.0)
	return out


static func _yaw_toward(unit: Dictionary, angle: float) -> float:
	var diff := wrapf(angle - float(unit.rot), -PI, PI)
	return clampf(diff * 2.6, -1.0, 1.0)


static func _is_local(sim, unit: Dictionary) -> bool:
	return str(unit.get("agent_id", "")) == str(sim.player.get("agent_id", ""))
