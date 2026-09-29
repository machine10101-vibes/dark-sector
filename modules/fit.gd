class_name Fit
extends RefCounted

const ACCEL_SCALE := 82.0
const STRAFE_SCALE := 52.0
const DAMP := 0.1
const VMAX := 340.0

const EFFECT_KEYS := [
	"mass", "power_draw", "cargo", "sensor", "signature",
	"gun_damage", "thrust", "strafe", "turn", "radius",
]


static func effects_sum(defs: Dictionary, module_ids: Array) -> Dictionary:
	var total := {}
	for key in EFFECT_KEYS:
		total[key] = 0.0
	for module_id in module_ids:
		var mod: Dictionary = defs.modules.get(module_id, {})
		var effects: Dictionary = mod.get("effects", {})
		for key in EFFECT_KEYS:
			total[key] += float(effects.get(key, 0.0))
	return total


static func stats(defs: Dictionary, ship: Dictionary) -> Dictionary:
	var hull: Dictionary = defs.ships[ship.class_id]
	var effects := effects_sum(defs, ship.get("modules", []))
	var mass := float(hull.mass) + float(effects.mass)
	var thrust := float(hull.thrust) + float(effects.thrust)
	var turn := float(hull.turn) * (float(hull.mass) / mass) + float(effects.turn)
	var strafe_stat := float(hull.strafe) + float(effects.strafe)
	var power := float(hull.power)
	var draw := float(hull.power_draw) + float(effects.power_draw)
	var cargo := int(hull.cargo) + int(round(float(effects.cargo)))
	var signature := float(hull.signature) + float(effects.signature)
	var sensor := float(hull.sensor) + float(effects.sensor)
	var gun: Dictionary = hull.gun.duplicate(true)
	gun.damage = float(gun.damage) + float(effects.gun_damage)
	var keel := float(hull.mass) * 1.12
	var radius := float(hull.radius) + float(effects.radius)
	return {
		"mass": mass,
		"base_mass": float(hull.mass),
		"thrust": thrust,
		"turn": turn,
		"accel": thrust / mass * ACCEL_SCALE,
		"strafe_accel": strafe_stat / mass * STRAFE_SCALE,
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
	}


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
		return {"ok": false, "reason": "Already bolted to the keel."}
	var mod: Variant = defs.modules.get(module_id)
	if mod == null:
		return {"ok": false, "reason": "No drawing for that part."}
	var slot := str(mod.get("slot", "Utility"))
	if free_slots(defs, ship).find(slot) < 0:
		return {"ok": false, "reason": "No free %s hardpoint on this keel." % slot}
	var before := stats(defs, ship)
	var hypothetical := ship.duplicate(true)
	hypothetical.modules = ship.modules.duplicate()
	hypothetical.modules.append(module_id)
	var after := stats(defs, hypothetical)
	if after.power_spare < -0.01:
		return {
			"ok": false,
			"reason": "Reactor spare is %.0f. That part wants more than the bus can feed." % before.power_spare,
		}
	ship.yard.erase(module_id)
	ship.modules.append(module_id)
	var keel_line := ""
	if after.keel_warn:
		keel_line = " The keel complains under the new mass."
	var reason := "%s bolted. Yaw %.0f°/s → %.0f°/s. Signature %s → %s.%s" % [
		mod.name, before.yaw_deg, after.yaw_deg, before.signature_word, after.signature_word, keel_line
	]
	return {"ok": true, "reason": reason}
