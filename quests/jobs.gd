extends RefCounted

## Freelance postings. Separate from the shakedown contract list.


static func tap(sim) -> String:
	var open := _open(sim)
	if open.is_empty():
		return _offer(sim)
	if str(open.get("state", "")) == "offered":
		open.state = "active"
		sim.say("%s is taken. %s" % [str(open.title), str(open.summary)])
		return ""
	return "%s is already on the slate." % str(open.get("title", "That job"))


static func step(sim) -> void:
	for row in sim.jobs:
		var job: Dictionary = row
		if str(job.get("state", "")) != "active":
			continue
		if _done(sim, job) == false:
			continue
		job.state = "done"
		var jid := str(job.get("id", ""))
		sim.quest_flags["did_job_%s" % jid] = true
		for mutation in job.get("mutations", []):
			QuestBoard._apply(sim, str(mutation))
		sim.say("%s is on the slate." % str(job.get("title", jid)))


static func text(sim) -> String:
	var book = sim.defs.get("freelance", {})
	var lines: Array = ["Freelance board. Job offers the next posting, then takes it. The keel does not move."]
	if typeof(book) != TYPE_DICTIONARY or book.is_empty():
		lines.append("The board is blank.")
		return "\n".join(lines)
	for key in book.keys():
		var spec: Dictionary = book[key]
		var jid := str(spec.get("id", key))
		var state := "open"
		if bool(sim.quest_flags.get("did_job_%s" % jid, false)):
			state = "done"
		for row in sim.jobs:
			if str(row.get("id", "")) == jid:
				state = str(row.get("state", state))
		var need := str(spec.get("need_cargo", ""))
		var carry := ""
		if need != "":
			carry = " Carry %s." % need.replace("_", " ")
		lines.append("%s  [%s]\n%s%s\nWhere: %s." % [str(spec.get("title", jid)), state, str(spec.get("summary", "")), carry, str(spec.get("system_id", ""))])
	return "\n\n".join(lines)


static func _offer(sim) -> String:
	var book = sim.defs.get("freelance", {})
	if typeof(book) != TYPE_DICTIONARY or book.is_empty():
		return "The board is blank."
	for key in book.keys():
		var spec: Dictionary = book[key]
		var jid := str(spec.get("id", key))
		if bool(sim.quest_flags.get("did_job_%s" % jid, false)):
			continue
		if _has(sim, jid):
			continue
		sim.jobs.append({
			"id": jid,
			"title": str(spec.get("title", jid)),
			"summary": str(spec.get("summary", "")),
			"system_id": str(spec.get("system_id", "")),
			"need_cargo": str(spec.get("need_cargo", "")),
			"mutations": spec.get("mutations", []),
			"state": "offered",
		})
		sim.say("%s is on the jobs board." % str(spec.get("title", jid)))
		return ""
	return "No open posting."


static func _open(sim) -> Dictionary:
	for row in sim.jobs:
		var job: Dictionary = row
		var state := str(job.get("state", ""))
		if state == "offered" or state == "active":
			return job
	return {}


static func _has(sim, jid: String) -> bool:
	for row in sim.jobs:
		if str(row.get("id", "")) == jid:
			return true
	return false


static func _done(sim, job: Dictionary) -> bool:
	if str(sim.defs.system.id) != str(job.get("system_id", "")):
		return false
	var need := str(job.get("need_cargo", ""))
	if need == "":
		return true
	return int(sim.player.cargo.get(need, 0)) > 0
