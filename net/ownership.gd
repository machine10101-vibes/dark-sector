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
	var faction_id := str(sim.defs.system.pdo.get("faction", "vellum_compact"))
	var seen := false
	for actor in sim.actors:
		if not bool(actor.get("alive", false)):
			continue
		if str(actor.team) != faction_id:
			continue
		if actor.pos.distance_to(pos) < 1100.0:
			seen = true
			break
	if not seen:
		return
	if bool(sim.pdo_alert):
		return
	add_heat(sim, faction_id, 12.0, "fired_in_sight", sim.player.agent_id)
	sim.say("The patrol saw the first shot.")
