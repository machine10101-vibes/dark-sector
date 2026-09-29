class_name Ownership
extends RefCounted

## Heat, wrecks, and claim slates use agent ids.
## `controller` is "npc" or "human". The same functions run for both.


static func add_heat(sim, faction_id: String, amount: float, reason: String, actor_agent: String) -> void:
	sim.heat[faction_id] = float(sim.heat.get(faction_id, 0.0)) + amount
	var memory: Array = sim.memory.get(faction_id, [])
	if not memory.has(reason):
		memory.append(reason)
	sim.memory[faction_id] = memory
	sim.heat_log.append({
		"faction": faction_id,
		"reason": reason,
		"agent": actor_agent,
		"amount": amount,
	})
	if sim.heat_log.size() > 32:
		sim.heat_log.pop_front()


static func on_captain_shot(sim, pos: Vector2) -> void:
	if sim.zone_at(pos) != "green":
		return
	var faction_id := str(sim.defs.system.pdo.get("faction", "vellum_compact"))
	var faction_name := str(sim.defs.factions[faction_id].name)
	add_heat(sim, faction_id, 8.0, "fired_in_green_lane", sim.player.agent_id)
	sim.pdo_alert = true
	if not sim.hailed:
		sim.hailed = true
		sim.banner = "%s: \"Guns in the green lane. Heave to, or we cut.\"" % faction_name
		sim.banner_t = 0.0
		sim.sfx("hail")
	else:
		sim.say("Compact slate marks another shot in the green lane.")
