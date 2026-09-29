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
		var summary := str(quest.summary)
		var where := ""
		var link := ""
		if quest_id == "authored_shakedown_01":
			summary = QuestBoard.live_summary(sim)
			var focus: Dictionary = QuestBoard.focus(sim)
			where = str(focus.get("label", ""))
			link = str(focus.get("kind", ""))
			state = str(sim.quest_flags.get("shakedown_beat", state))
		out.append({
			"id": quest_id,
			"title": quest.title,
			"kind": str(quest.get("type", quest.get("kind", ""))),
			"state": state,
			"summary": summary,
			"where": where,
			"link": link,
			"giver": str(quest.get("giver", "")),
		})
	for row in sim.contracts:
		var contract: Dictionary = row
		out.append({
			"id": str(contract.get("id", "")),
			"title": str(contract.get("title", "Contract")),
			"kind": str(contract.get("type", "systemic")),
			"state": str(contract.get("state", "offered")),
			"summary": str(contract.get("summary", "")),
			"where": str(contract.get("target", "")),
			"link": str(contract.get("template", "")),
			"giver": str(contract.get("giver", "")),
		})
	if bool(sim.quest_flags.get("hollow_latch_surveyed", false)):
		out.append({
			"id": "hollow_latch_surveyed",
			"title": "Latch walked",
			"kind": "systemic",
			"state": "done",
			"summary": "Boots on Hollow Latch. The pocket is confirmed for a Claim Core. Nothing has been planted, and the ship is unchanged by the walk except the flag.",
			"where": "",
			"link": "",
			"giver": "",
		})
	return out
