class_name Fit
extends RefCounted

const ACCEL_SCALE := 82.0
const STRAFE_SCALE := 52.0
const DAMP := 0.1
const VMAX := 340.0

const EFFECT_KEYS := [
	"mass", "power_draw", "cargo", "sensor", "signature",
	"gun_damage", "thrust", "strafe", "turn", "radius",
	"crew", "armor",
	"shield", "armor_hp", "capacitor", "cap_regen", "cooling", "scan_res", "tracking",
]

const LOCK_K := 403.0


static func module_effects(mod: Dictionary) -> Dictionary:
	var effects: Dictionary = mod.get("effects", {})
	var total := {}
	for key in EFFECT_KEYS:
		total[key] = float(effects.get(key, 0.0))
	if mod.has("mass"):
		total.mass = float(mod.mass)
	if mod.has("power"):
		total.power_draw = float(mod.power)
	if mod.has("crew"):
		total.crew = float(mod.crew)
	if mod.has("armor"):
		total.armor = float(mod.armor)
	return total


static func effects_sum(defs: Dictionary, module_ids: Array) -> Dictionary:
	var total := {}
	for key in EFFECT_KEYS:
		total[key] = 0.0
	for module_id in module_ids:
		var mod: Dictionary = defs.modules.get(module_id, {})
		var piece := module_effects(mod)
		for key in EFFECT_KEYS:
			total[key] += float(piece[key])
	return total


static func working_ids(ship: Dictionary, module_ids: Array) -> Array:
	var hpmap: Dictionary = ship.get("module_hp", {})
	var live: Array = []
	for module_id in module_ids:
		if hpmap.has(module_id) and float(hpmap[module_id]) <= 0.0:
			continue
		live.append(module_id)
	return live


static func stats(defs: Dictionary, ship: Dictionary) -> Dictionary:
	var hull: Dictionary = defs.ships[ship.class_id]
	var module_ids: Array = ship.get("modules", [])
	var bolted := effects_sum(defs, module_ids)
	var effects := effects_sum(defs, working_ids(ship, module_ids))
	var mass := float(hull.mass) + float(bolted.mass)
	var thrust := float(hull.thrust) + float(effects.thrust)
	var moment := Vector2.ZERO
	for module_id in module_ids:
		var mod: Dictionary = defs.modules.get(module_id, {})
		var piece := module_effects(mod)
		var attach: Dictionary = mod.get("attach", {})
		var mount := Vector2(float(attach.get("x", 0.0)), float(attach.get("y", 0.0)))
		moment += mount * float(piece.mass)
	var com := Vector2.ZERO
	if mass > 0.01:
		com = moment / mass
	var inertia := 1.0 + com.length() * 0.012
	var lateral := 1.0 + absf(com.y) * 0.008
	var turn := float(hull.turn) * (float(hull.mass) / mass) / inertia + float(effects.turn)
	var keel := float(hull.mass) * 1.12
	if mass > keel:
		turn *= keel / mass
	var strafe_stat := float(hull.strafe) + float(effects.strafe)
	var power := float(hull.power)
	var draw := float(hull.power_draw) + float(effects.power_draw)
	var cargo := int(hull.cargo) + int(round(float(effects.cargo)))
	var signature := float(hull.signature) + float(bolted.signature)
	var sensor := float(hull.sensor) + float(effects.sensor)
	var gun: Dictionary = hull.gun.duplicate(true)
	gun.damage = float(gun.damage) + float(effects.gun_damage)
	gun.cap = float(gun.get("cap", 0.0))
	gun.therm = float(gun.get("therm", 0.0))
	gun.tracking = maxf(0.15, float(gun.get("tracking", 0.6)) + float(effects.tracking))
	gun.optimal = float(gun.get("optimal", float(gun.get("range", 400.0)) * 0.7))
	gun.falloff = float(gun.get("falloff", float(gun.get("range", 400.0)) * 0.4))
	gun.arc = float(gun.get("arc", 0.0))
	gun.kind = str(gun.get("kind", "nose"))
	var radius := float(hull.radius) + float(bolted.radius)
	var crew_budget := 0
	if ship.has("crew"):
		crew_budget = ship.crew.size()
	var crew_used := int(round(float(bolted.crew)))
	var armor := clampf(float(effects.armor), 0.0, 0.7)
	return {
		"mass": mass,
		"base_mass": float(hull.mass),
		"thrust": thrust,
		"ttw": thrust / mass,
		"com": com,
		"turn": turn,
		"accel": thrust / mass * ACCEL_SCALE / lateral,
		"strafe_accel": strafe_stat / mass * STRAFE_SCALE / lateral,
		"damp": DAMP,
		"vmax": VMAX,
		"power": power,
		"power_draw": draw,
		"power_spare": power - draw,
		"cargo_cap": cargo,
		"signature": signature,
		"signature_word": signature_word(signature),
		"sensor": sensor,
		"gun": gun,
		"hp_max": int(hull.hp),
		"keel": keel,
		"keel_warn": mass > keel,
		"yaw_deg": rad_to_deg(turn),
		"hit_radius": radius,
		"crew_budget": crew_budget,
		"crew_used": crew_used,
		"crew_over": crew_used > crew_budget,
		"armor": armor,
		"shield_max": float(hull.get("shield", 0.0)) + float(effects.shield),
		"shield_regen": float(hull.get("shield_regen", 0.0)),
		"armor_max": float(hull.get("armor_hp", 0.0)) + float(effects.armor_hp),
		"cap_max": float(hull.get("capacitor", 0.0)) + float(effects.capacitor),
		"cap_regen": float(hull.get("cap_regen", 0.0)) + float(effects.cap_regen),
		"cooling": float(hull.get("cooling", 8.0)) + float(effects.cooling),
		"scan_res": float(hull.get("scan_res", 300.0)) + float(effects.scan_res),
	}


static func lock_time(scan_res: float, target_signature: float) -> float:
	return clampf(LOCK_K / maxf(1.0, scan_res * maxf(0.05, target_signature)), 0.6, 6.0)


static func mounts(defs: Dictionary, ship: Dictionary) -> Array:
	var rows: Array = []
	for module_id in working_ids(ship, ship.get("modules", [])):
		var mod: Dictionary = defs.modules.get(module_id, {})
		if not mod.has("weapon"):
			continue
		var gun: Dictionary = (mod.weapon as Dictionary).duplicate(true)
		gun.id = str(module_id)
		gun.socket = str(gun.get("socket", module_id))
		gun.name = str(mod.get("name", module_id))
		rows.append(gun)
	return rows


static func weapon_line(gun: Dictionary) -> String:
	var family := str(gun.get("family", ""))
	if family == "missile":
		var speed := float(gun.get("speed", 210.0))
		if speed > 320.0:
			speed = 220.0
		var flight := float(gun.get("range", 400.0)) / maxf(40.0, speed)
		return "flight %.1f s, blast %.0f" % [flight, float(gun.get("blast", 40.0))]
	if family == "pd":
		return "flak %d m" % int(gun.get("range", 200.0))
	if family == "laser":
		return "optimal %d m, cap %.0f" % [int(gun.get("optimal", 400.0)), float(gun.get("cap", 0.0))]
	return "optimal %d m" % int(gun.get("optimal", 400.0))


static func signature_word(signature: float) -> String:
	if signature < 0.45:
		return "quiet"
	if signature < 0.82:
		return "readable"
	return "loud"


static func cargo_used(ship: Dictionary) -> int:
	var used := 0
	for key in ship.cargo.keys():
		used += int(ship.cargo[key])
	return used


static func free_slots(defs: Dictionary, ship: Dictionary) -> Array:
	var slots: Array = ship.slots.duplicate()
	for module_id in ship.modules:
		var used := str(defs.modules[module_id].get("slot", "Utility"))
		var index := slots.find(used)
		if index >= 0:
			slots.remove_at(index)
	return slots


static func try_install(defs: Dictionary, ship: Dictionary, module_id: String) -> Dictionary:
	if module_id == "" or not ship.yard.has(module_id):
		return {"ok": false, "reason": "The yard has no such part."}
	if ship.modules.has(module_id):
		return {"ok": false, "reason": "Already bolted to the ship."}
	var mod: Variant = defs.modules.get(module_id)
	if mod == null:
		return {"ok": false, "reason": "No drawing for that part."}
	var before := stats(defs, ship)
	var hypothetical := ship.duplicate(true)
	hypothetical.modules = ship.modules.duplicate()
	hypothetical.modules.append(module_id)
	var after := stats(defs, hypothetical)
	ship.yard.erase(module_id)
	ship.modules.append(module_id)
	var extra := ""
	if after.keel_warn:
		extra += " The ship complains under the new mass."
	if after.power_spare < -0.01:
		extra += " Reactor overloaded."
	if after.crew_over:
		extra += " Crew budget is past the names on the board."
	if mod.has("weapon"):
		var piece: Dictionary = mod.weapon
		extra += " Signature %.2f → %.2f. %s." % [before.signature, after.signature, weapon_line(piece)]
	var reason := "%s bolted. Mass %.0f → %.0f. Yaw %.0f°/s → %.0f°/s. Thrust-to-weight %.2f → %.2f.%s" % [
		mod.name, before.mass, after.mass, before.yaw_deg, after.yaw_deg, before.ttw, after.ttw, extra
	]
	return {"ok": true, "reason": reason}


static func try_remove(defs: Dictionary, ship: Dictionary, module_id: String) -> Dictionary:
	if not ship.modules.has(module_id):
		return {"ok": false, "reason": "That part is not on the ship."}
	var mod: Variant = defs.modules.get(module_id)
	if mod == null:
		return {"ok": false, "reason": "No drawing for that part."}
	var before := stats(defs, ship)
	ship.modules.erase(module_id)
	if not ship.yard.has(module_id):
		ship.yard.append(module_id)
	var after := stats(defs, ship)
	var reason := "%s pulled. Mass %.0f → %.0f. Yaw %.0f°/s → %.0f°/s. Thrust-to-weight %.2f → %.2f." % [
		mod.name, before.mass, after.mass, before.yaw_deg, after.yaw_deg, before.ttw, after.ttw
	]
	return {"ok": true, "reason": reason}
