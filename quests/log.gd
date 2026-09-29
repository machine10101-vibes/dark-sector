class_name QuestLog
extends RefCounted


static func entries(defs: Dictionary, sim) -> Array:
	var out: Array = []
	var class_id := str(sim.player.class_id)
	for quest_id in defs.quests.keys():
		var quest: Dictionary = defs.quests[quest_id]
		if str(quest.get("ship", "")) != "" and str(quest.ship) != class_id:
			continue
		var state := str(sim.quest_flags.get(quest_id, quest.get("state", "dormant")))
		out.append({
			"id": quest_id,
			"title": quest.title,
			"kind": quest.kind,
			"state": state,
			"summary": quest.summary,
		})
	if bool(sim.quest_flags.get("hollow_latch_surveyed", false)):
		out.append({
			"id": "hollow_latch_surveyed",
			"title": "Latch walked",
			"kind": "systemic",
			"state": "done",
			"summary": "Boots on Hollow Latch. The pocket is confirmed for a Claim Core. Nothing has been planted, and the ship is unchanged by the walk except the flag.",
		})
	return out
