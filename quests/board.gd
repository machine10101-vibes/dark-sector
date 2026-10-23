class_name QuestBoard
extends RefCounted

const REWARDS := ["sensor_mast", "gun_sponson", "farm_cassette"]


static func pulse(sim, dt: float) -> void:
	if sim.player.is_empty():
		return
	_shakedown(sim)
	_shorts(sim)
	_data_hooks(sim)
	_contracts(sim, dt)
	var waited := float(sim.quest_flags.get("offer_t", 0.0)) + dt
	sim.quest_flags.offer_t = waited
	if waited > 2.0 and not _open_contract(sim):
		sim.quest_flags.offer_t = 0.0
		refresh(sim)


static func refresh(sim) -> String:
	if _open_contract(sim):
		return ""
	var made: Dictionary = _from_world(sim)
	if made.is_empty():
		return ""
	sim.contracts.append(made)
	sim.say("%s is on the log. O takes it. Y marks it. The keel stays." % str(made.title))
	return str(made.id)


static func accept(sim) -> String:
	for row in sim.contracts:
		var contract: Dictionary = row
		if str(contract.get("state", "")) != "offered":
			continue
		contract.state = "active"
		contract.age = 0.0
		contract.pocket_time = 0.0
		contract.origin_system = str(sim.defs.system.id)
		sim.say("%s is taken. The world will keep the result." % str(contract.title))
		return ""
	return "No contract is offered."


static func try_take(sim) -> String:
	var note := accept(sim)
	if note == "":
		return ""
	if not DockBoard.at_pad(sim):
		return note
	for job in ["scan", "haul", "salvage", "escort"]:
		if DockBoard.state(sim, "dock_%s" % job) == "open":
			return DockBoard.take(sim, job)
	return note


static func mark(sim) -> String:
	var focus := focus(sim)
	sim.nav_mark = focus
	sim.say("Mark on %s. The keel stays where it is." % str(focus.get("label", "the mark")))
	return ""


static func on_arrive(sim) -> void:
	_note_open(sim)
	if str(sim.defs.system.id) != "HC-V1-R1-S1":
		return
	if not bool(sim.quest_flags.get("inspect_pending", false)):
		return
	sim.quest_flags.inspect_pending = false
	var faction := "helion_compact"
	var heat_now := float(sim.heat.get(faction, 0.0)) + 12.0
	sim.heat[faction] = heat_now
	sim.hailed = true
	sim.banner = "Helion Compact: \"Warrant. Heave to for inspection.\""
	sim.banner_t = 0.0
	sim.say("The patrol inspects the hold. The warrant is still on the slate.")
	sim.sfx("hail")


static func focus(sim) -> Dictionary:
	var beat := str(sim.quest_flags.get("shakedown_beat", "undock"))
	if beat == "done" or beat == "failed":
		var job := _active_contract(sim)
		if not job.is_empty():
			return _contract_focus(sim, job)
		var hook: Dictionary = _near_hook(sim)
		if not hook.is_empty():
			return hook
		return _point(sim, str(sim.defs.system.id), "system", str(sim.defs.system.id), str(sim.defs.system.name))
	match beat:
		"undock":
			return _point(sim, "HC-V1-R1-S1", "system", "HC-V1-R1-S1", "Helion Dock")
		"scan":
			return _point(sim, "HC-V1-R1-S1", "body", "aegis_prime", "Aegis Prime")
		"harvest":
			return _point(sim, "HC-V1-R1-S1", "body", "aegis_ring", "Aegis ice ring")
		"module":
			return _point(sim, str(sim.defs.system.id), "keel", "bay", "the ship bay")
		"pirate":
			return _point(sim, "HC-V1-R1-S1", "patrol", "red_keel", "the Red Keel pack")
		"claim", "garden":
			return _point(sim, "HC-V1-R5-S1", "claim", "quiet_hollow", "Quiet Hollow")
		_:
			return _point(sim, str(sim.defs.system.id), "system", str(sim.defs.system.id), str(sim.defs.system.name))


static func cue_line(sim) -> String:
	if sim == null or sim.player.is_empty():
		return ""
	var slip := DockBoard.slip_line(sim)
	if slip != "":
		return slip
	var guided := _guide_cue(sim)
	if guided != "":
		return guided
	var beat := str(sim.quest_flags.get("shakedown_beat", "undock"))
	if beat != "" and beat != "done" and beat != "failed":
		return _beat_line(sim, beat)
	var job := _active_contract(sim)
	if not job.is_empty():
		var title := str(job.get("title", "Contract"))
		if str(job.get("state", "")) == "offered":
			return "OFFER  %s  ·  Take or Approach" % title
		if str(job.get("template", "")) == "defend":
			var held := float(job.get("pocket_time", 0.0))
			if _in_claim(sim):
				return "%s  ·  hold %.0f/48 in pocket" % [title, held]
			return "%s  ·  enter the pocket" % title
		var mark := _contract_focus(sim, job)
		var pos := Vector2(float(mark.get("x", 0.0)), float(mark.get("y", 0.0)))
		if pos == Vector2.ZERO:
			return title
		var gap: float = sim.player.pos.distance_to(pos)
		return "%s  ·  %d m" % [title, int(gap)]
	return _hook_line(sim)


static func cue_aim(sim) -> Vector2:
	if sim == null or sim.player.is_empty():
		return Vector2.ZERO
	var slip: Vector2 = DockBoard.cue_aim(sim)
	if slip.length() > 8.0:
		return slip
	var guided: Dictionary = _guide_mark(sim)
	if not guided.is_empty():
		return _beam(sim, guided)
	var beat := str(sim.quest_flags.get("shakedown_beat", ""))
	var mark: Dictionary = {}
	if beat != "" and beat != "done" and beat != "failed" and beat != "module" and beat != "garden":
		mark = focus(sim)
	else:
		var job := _active_contract(sim)
		if not job.is_empty():
			mark = _contract_focus(sim, job)
		else:
			mark = _near_hook(sim)
	if mark.is_empty():
		return Vector2.ZERO
	if str(mark.get("kind", "")) == "keel":
		return Vector2.ZERO
	var pos := Vector2(float(mark.get("x", 0.0)), float(mark.get("y", 0.0)))
	if pos == Vector2.ZERO:
		return Vector2.ZERO
	var beam: Vector2 = pos - sim.player.pos
	if beam.length() <= 8.0:
		return Vector2.ZERO
	return beam


static func shakedown_line(sim) -> String:
	var beat := str(sim.quest_flags.get("shakedown_beat", ""))
	if beat == "" or beat == "done" or beat == "failed":
		return ""
	return _beat_line(sim, beat)


static func _beat_line(sim, beat: String) -> String:
	var mark := focus(sim)
	var label := str(mark.get("label", "the mark"))
	var pos := Vector2(float(mark.get("x", 0.0)), float(mark.get("y", 0.0)))
	var gap := 0
	if pos != Vector2.ZERO:
		gap = int(sim.player.pos.distance_to(pos))
	match beat:
		"undock":
			if bool(sim.player.get("moored", false)):
				return "Cast off — leave the pad."
			return "Leave the pad — shakedown is live."
		"scan":
			return "Scan Aegis Prime — %d m." % gap
		"harvest":
			return "Cut the ice ring or Seized Hold — %d m." % gap
		"module":
			return "Bolt a module — Bolt on SHIP."
		"pirate":
			return "Meet the Red Keel — %d m." % gap
		"claim":
			var out := CraftOrders.out_name(sim)
			if out != "" and str(sim.defs.system.id) == "HC-V1-R1-S1":
				return "Return %s — Lane waits." % out
			if str(sim.defs.system.id) != "HC-V1-R5-S1":
				return "Lane to Quiet Hollow — %s." % label
			if int(sim.player.cargo.get("claim_core", 0)) < 1:
				return "Make a Claim Core — four raw mass."
			return "Plant the core on Quiet Hollow."
		"garden":
			if not bool(sim.quest_flags.get("wheat_cut", false)):
				return "Tend glasswheat — Tend on LAW."
			return "Feed the kine — Feed on LAW."
		_:
			return ""


static func try_bolt(sim) -> String:
	if sim == null or sim.player.is_empty():
		return "No keel to bolt."
	if sim.in_combat():
		return "The bay is shut. Break off before you touch a bolt."
	var yard: Array = sim.player.get("yard", [])
	var order: Array = []
	if yard.has("sensor_mast"):
		order.append("sensor_mast")
	for mid in yard:
		var module_id := str(mid)
		if module_id == "sensor_mast":
			continue
		order.append(module_id)
	for module_id in order:
		if sim.player.modules.has(module_id):
			continue
		if not sim.defs.modules.has(module_id):
			continue
		sim.install(module_id)
		return ""
	if DockBoard.at_pad(sim):
		var cheapest := ""
		var cheapest_price := 9999
		for kit_id in DockBoard.KIT.keys():
			var row: Dictionary = DockBoard.KIT[kit_id]
			if row.has("round"):
				continue
			if sim.player.modules.has(kit_id) or DockBoard.paid_mount(sim, kit_id):
				continue
			var price := int(row.price)
			if price < cheapest_price:
				cheapest_price = price
				cheapest = str(kit_id)
		if cheapest != "":
			var note := DockBoard.buy_kit(sim, cheapest)
			if note != "" and DockBoard.can_afford(sim, cheapest):
				note = DockBoard.fabricate(sim, cheapest)
			if note != "":
				return note
			sim.install(cheapest)
			return ""
	return "No spare in the yard. Buy a kit at the Helion pad."


static func try_approach(sim) -> String:
	if sim == null or sim.player.is_empty():
		return "No keel to move."
	var slip_aim: Vector2 = DockBoard.cue_aim(sim)
	if slip_aim.length() > 8.0:
		var dest: Vector2 = sim.player.pos + slip_aim
		var label := DockBoard.slip_line(sim)
		if label == "":
			label = "the dock mark"
		HelmCombat.set_order(sim, sim.player, {
			"kind": "approach",
			"x": dest.x,
			"y": dest.y,
			"label": label,
		})
		return ""
	var beat := str(sim.quest_flags.get("shakedown_beat", "undock"))
	if beat == "undock" and bool(sim.player.get("moored", false)):
		return "Cast off — leave the pad."
	if beat == "done" or beat == "failed":
		var job := _active_contract(sim)
		if not job.is_empty() and str(job.get("state", "")) == "offered":
			accept(sim)
	var guided: Dictionary = _guide_mark(sim)
	if not guided.is_empty():
		return _fly_mark(sim, guided)
	if beat == "module":
		return "Bolt a module from the SHIP row."
	var mark: Dictionary = focus(sim)
	var pos := Vector2(float(mark.get("x", 0.0)), float(mark.get("y", 0.0)))
	if pos == Vector2.ZERO:
		return "No job mark to approach."
	if beat == "garden" and pos.distance_to(sim.player.pos) <= 80.0:
		return "Tend glasswheat and keep the kine."
	if pos.distance_to(sim.player.pos) <= 8.0:
		return "Already on the mark."
	HelmCombat.set_order(sim, sim.player, {
		"kind": "approach",
		"x": pos.x,
		"y": pos.y,
		"label": str(mark.get("label", "the mark")),
	})
	return ""


static func track(sim, quest_id: String) -> String:
	if sim == null or sim.player.is_empty():
		return "No keel on the slate."
	var current := str(sim.quest_flags.get("tracked_quest", ""))
	if quest_id == "" or quest_id == current:
		sim.quest_flags.tracked_quest = ""
		sim.say("Guide cleared. The helm follows the live job.")
		return ""
	if not _can_track(sim, quest_id):
		return "That job is not on the slate."
	sim.quest_flags.tracked_quest = quest_id
	var card := guide_card(sim, quest_id)
	var mark := _mark_for(sim, quest_id)
	if not mark.is_empty():
		sim.nav_mark = mark
	sim.say("Tracking %s. %s" % [str(card.get("title", quest_id)), str(card.get("step", "the next step"))])
	return ""


static func guide_card(sim, quest_id: String) -> Dictionary:
	if sim == null or sim.player.is_empty() or quest_id == "":
		return {}
	var tracking := str(sim.quest_flags.get("tracked_quest", "")) == quest_id
	if quest_id == "authored_shakedown_01":
		var beat := str(sim.quest_flags.get("shakedown_beat", "undock"))
		var mark := focus(sim)
		var step := "Shakedown is filed."
		if beat != "done" and beat != "failed":
			step = _beat_line(sim, beat)
		elif beat == "failed":
			step = "Shakedown failed. The slate kept it."
		return {
			"id": quest_id,
			"title": "Shakedown",
			"step": step,
			"start": "Cast off from Helion Dock.",
			"detail": "Follow the beat the helm names.",
			"finish": "Tend the garden and feed the kine.",
			"reward": "A blueprint from Clerk Ivo Ram.",
			"fail": "The hold-kine dies before the cut.",
			"where": str(mark.get("label", "Helion")),
			"x": float(mark.get("x", 0.0)),
			"y": float(mark.get("y", 0.0)),
			"tracking": tracking,
		}
	if sim.defs.quests.has(quest_id):
		var quest: Dictionary = sim.defs.quests[quest_id]
		var summary := str(quest.get("summary", ""))
		var quest_mark := _mark_for(sim, quest_id)
		var filed := str(sim.quest_flags.get(quest_id, "")) == "done"
		var quest_step := "Filed on the slate."
		if not filed:
			quest_step = _step_line(sim, quest, quest_mark)
		var reward := _clause(summary, "Reward:")
		if reward == "":
			reward = _reward_line(quest.get("mutations", []))
		var fail := _clause(summary, "Fail:")
		if fail == "":
			fail = "There is no timer. The job stays open until you finish it."
		var detail := _clause(summary, "Do:")
		if detail == "":
			detail = summary
		return {
			"id": quest_id,
			"title": str(quest.get("title", quest_id)),
			"step": quest_step,
			"start": _clause(summary, "Start:"),
			"detail": detail,
			"finish": _clause(summary, "Finish:"),
			"reward": reward,
			"fail": fail,
			"where": str(quest_mark.get("label", str(quest.get("title", quest_id)))),
			"x": float(quest_mark.get("x", 0.0)),
			"y": float(quest_mark.get("y", 0.0)),
			"tracking": tracking,
		}
	for row in sim.contracts:
		var contract: Dictionary = row
		if str(contract.get("id", "")) != quest_id:
			continue
		var job_mark := _contract_focus(sim, contract)
		var job_state := str(contract.get("state", ""))
		var job_step := "Filed on the slate."
		if job_state == "offered":
			job_step = "Take the offer. Approach accepts it."
		elif job_state == "active":
			job_step = _mark_step(sim, job_mark)
			if str(contract.get("template", "")) == "defend":
				job_step = "Hold the pocket. %s" % job_step
		elif job_state == "failed":
			job_step = "The contract failed. The slate kept a mark."
		return {
			"id": quest_id,
			"title": str(contract.get("title", "Contract")),
			"step": job_step,
			"start": "The sector offered this contract.",
			"detail": str(contract.get("summary", "")),
			"finish": "Finish the contract. The sector keeps the change.",
			"reward": _reward_line(contract.get("success_mutations", [])),
			"fail": "The timer can fail it, and a ruptured hollow fails a defend.",
			"where": str(job_mark.get("label", str(contract.get("title", "Contract")))),
			"x": float(job_mark.get("x", 0.0)),
			"y": float(job_mark.get("y", 0.0)),
			"tracking": tracking,
		}
	return {}


static func _guide_cue(sim) -> String:
	var qid := str(sim.quest_flags.get("tracked_quest", ""))
	if qid == "":
		return ""
	if not _can_track(sim, qid):
		sim.quest_flags.tracked_quest = ""
		return ""
	var card := guide_card(sim, qid)
	if card.is_empty():
		return ""
	return "TRACK  %s  ·  %s" % [str(card.get("title", qid)), str(card.get("step", ""))]


static func _guide_mark(sim) -> Dictionary:
	if DockBoard.slip_line(sim) != "":
		return {}
	var qid := str(sim.quest_flags.get("tracked_quest", ""))
	if qid == "":
		return {}
	if not _can_track(sim, qid):
		sim.quest_flags.tracked_quest = ""
		return {}
	return _mark_for(sim, qid)


static func _can_track(sim, quest_id: String) -> bool:
	if quest_id == "authored_shakedown_01":
		var beat := str(sim.quest_flags.get("shakedown_beat", ""))
		return beat != "" and beat != "done" and beat != "failed"
	if str(sim.quest_flags.get(quest_id, "")) == "done" or str(sim.quest_flags.get(quest_id, "")) == "failed":
		return false
	if sim.defs.quests.has(quest_id):
		var quest: Dictionary = sim.defs.quests[quest_id]
		var ship := str(quest.get("ship", ""))
		if ship != "" and ship != str(sim.player.class_id):
			return false
		if hook_open(sim, quest, quest_id):
			return true
		return str(sim.quest_flags.get(quest_id, "")) == "open"
	for row in sim.contracts:
		var contract: Dictionary = row
		if str(contract.get("id", "")) != quest_id:
			continue
		var state := str(contract.get("state", ""))
		return state == "offered" or state == "active"
	return false


static func _mark_for(sim, quest_id: String) -> Dictionary:
	if quest_id == "authored_shakedown_01":
		return focus(sim)
	if sim.defs.quests.has(quest_id):
		var quest: Dictionary = sim.defs.quests[quest_id]
		var title := str(quest.get("title", quest_id))
		var body := str(quest.get("body", ""))
		if body != "":
			var system_id := str(quest.get("system_id", ""))
			var label := _body_label(sim, system_id, body, title)
			var here := system_id == "" or str(sim.defs.system.id) == system_id
			if here:
				var pending := _open_prelude(sim, quest, quest_id)
				if not pending.is_empty():
					return _prelude_point(sim, pending)
			return _point(sim, system_id, "body", body, label)
		if quest.has("route"):
			var route: Array = quest.route
			var step := int(sim.quest_flags.get("%s_step" % quest_id, 0))
			if step < 0:
				step = 0
			if step >= route.size():
				step = route.size() - 1
			if step < 0:
				return {}
			var next_id := str(route[step])
			var marks: Array = quest.get("marks", [])
			if step < marks.size() and str(marks[step]) != "":
				var mark_id := str(marks[step])
				var label := _body_label(sim, next_id, mark_id, title)
				return _point(sim, next_id, "body", mark_id, label)
			var sys_name := next_id
			var chart: Dictionary = sim.defs.get("systems", {})
			if chart.has(next_id):
				sys_name = str(chart[next_id].get("name", next_id))
			return _point(sim, next_id, "system", next_id, sys_name)
	for row in sim.contracts:
		var contract: Dictionary = row
		if str(contract.get("id", "")) == quest_id:
			return _contract_focus(sim, contract)
	return {}


static func _body_label(sim, system_id: String, body_id: String, fallback: String) -> String:
	if str(sim.defs.system.id) == system_id:
		var rock = sim.planet(body_id)
		if rock != null:
			return str(rock.name)
	var chart: Dictionary = sim.defs.get("systems", {})
	if chart.has(system_id):
		var spec: Dictionary = chart[system_id]
		for key in ["planets", "bodies"]:
			for raw in spec.get(key, []):
				if typeof(raw) != TYPE_DICTIONARY:
					continue
				var body: Dictionary = raw
				if str(body.get("id", "")) == body_id:
					return str(body.get("name", fallback))
	return fallback


static func _step_line(sim, quest: Dictionary, mark: Dictionary) -> String:
	var line := _mark_step(sim, mark)
	if not quest.has("route"):
		return line
	var route: Array = quest.route
	var qid := str(quest.get("id", ""))
	var step := int(sim.quest_flags.get("%s_step" % qid, 0))
	var need := str(quest.get("need_cargo", ""))
	var last := step >= route.size() - 1
	var here := step >= 0 and step < route.size() and str(sim.defs.system.id) == str(route[step])
	if need != "" and last and here and int(sim.player.cargo.get(need, 0)) < 1:
		return "%s  ·  bring %s" % [line, need.replace("_", " ")]
	return line


static func _mark_step(sim, mark: Dictionary) -> String:
	var label := str(mark.get("label", "the mark"))
	var pos := Vector2(float(mark.get("x", 0.0)), float(mark.get("y", 0.0)))
	if pos == Vector2.ZERO:
		return label
	return "%s  ·  %d m" % [label, int(sim.player.pos.distance_to(pos))]


static func _beam(sim, mark: Dictionary) -> Vector2:
	if str(mark.get("kind", "")) == "keel":
		return Vector2.ZERO
	var pos := Vector2(float(mark.get("x", 0.0)), float(mark.get("y", 0.0)))
	if pos == Vector2.ZERO:
		return Vector2.ZERO
	var beam: Vector2 = pos - sim.player.pos
	if beam.length() <= 8.0:
		return Vector2.ZERO
	return beam


static func _fly_mark(sim, mark: Dictionary) -> String:
	var pos := Vector2(float(mark.get("x", 0.0)), float(mark.get("y", 0.0)))
	if pos == Vector2.ZERO:
		return "No job mark to approach."
	if pos.distance_to(sim.player.pos) <= 8.0:
		return "Already on the mark."
	HelmCombat.set_order(sim, sim.player, {
		"kind": "approach",
		"x": pos.x,
		"y": pos.y,
		"label": str(mark.get("label", "the mark")),
	})
	return ""


static func _note_open(sim) -> void:
	var quests = sim.defs.get("quests", {})
	if typeof(quests) != TYPE_DICTIONARY:
		return
	for key in quests.keys():
		var quest = quests[key]
		if typeof(quest) != TYPE_DICTIONARY:
			continue
		var qid := str(quest.get("id", key))
		var cur := str(sim.quest_flags.get(qid, ""))
		if cur == "done" or cur == "failed":
			continue
		var ship := str(quest.get("ship", ""))
		if ship != "" and ship != str(sim.player.class_id):
			continue
		if not hook_open(sim, quest, qid):
			continue
		if cur == "" or cur == "dormant":
			sim.quest_flags[qid] = "open"


static func _release_track(sim, quest_id: String) -> bool:
	if str(sim.quest_flags.get("tracked_quest", "")) != quest_id:
		return false
	sim.quest_flags.tracked_quest = ""
	return true


static func _clause(summary: String, label: String) -> String:
	var at := summary.find(label)
	if at < 0:
		return ""
	var from := at + label.length()
	var end := summary.length()
	for other in ["Start:", "Do:", "Finish:", "Reward:", "Fail:"]:
		if other == label:
			continue
		var next := summary.find(other, from)
		if next >= 0 and next < end:
			end = next
	return summary.substr(from, end - from).strip_edges()


static func _reward_line(mutations) -> String:
	if typeof(mutations) != TYPE_ARRAY:
		return ""
	var bits: PackedStringArray = PackedStringArray()
	for item in mutations:
		var text := str(item)
		if text.begins_with("rumor_"):
			bits.append("a rumor on the slate")
		elif text.ends_with("_standing_up"):
			bits.append("%s standing" % text.trim_suffix("_standing_up").replace("_", " "))
		elif text.begins_with("heat_"):
			bits.append("%s heat" % text.trim_prefix("heat_").replace("_", " "))
		elif text == "salvage_grant":
			bits.append("one crate of salvage")
		elif text == "blueprint":
			bits.append("a blueprint")
	if bits.is_empty():
		return ""
	return ", ".join(bits)


static func hook_open(sim, quest: Dictionary, quest_id: String) -> bool:
	if sim == null or sim.player.is_empty():
		return false
	if str(sim.quest_flags.get(quest_id, "")) == "done":
		return false
	var body := str(quest.get("body", ""))
	if body != "":
		var system_id := str(quest.get("system_id", ""))
		return system_id == "" or str(sim.defs.system.id) == system_id
	if quest.has("route"):
		var route: Array = quest.route
		return route.has(str(sim.defs.system.id))
	return false


static func _hook_line(sim) -> String:
	var hook: Dictionary = _near_hook(sim)
	if hook.is_empty():
		return ""
	var label := str(hook.get("label", ""))
	var pos := Vector2(float(hook.get("x", 0.0)), float(hook.get("y", 0.0)))
	if pos == Vector2.ZERO:
		return "Visit  %s" % label
	var gap: float = sim.player.pos.distance_to(pos)
	return "Visit  %s  ·  %d m" % [label, int(gap)]


static func _near_hook(sim) -> Dictionary:
	var quests = sim.defs.get("quests", {})
	if typeof(quests) != TYPE_DICTIONARY:
		return {}
	for key in quests.keys():
		var quest = quests[key]
		if typeof(quest) != TYPE_DICTIONARY:
			continue
		var qid := str(quest.get("id", key))
		if not hook_open(sim, quest, qid):
			continue
		var body := str(quest.get("body", ""))
		if body != "":
			var rock = sim.planet(body)
			if rock == null:
				continue
			return _point(sim, str(sim.defs.system.id), "body", body, str(quest.get("title", qid)))
		if quest.has("route"):
			var route: Array = quest.route
			var step := int(sim.quest_flags.get("%s_step" % qid, 0))
			if step < 0:
				step = 0
			if step >= route.size():
				continue
			var next_id := str(route[step])
			var title := str(quest.get("title", qid))
			var marks: Array = quest.get("marks", [])
			if next_id == str(sim.defs.system.id) and step < marks.size() and str(marks[step]) != "":
				return _point(sim, next_id, "body", str(marks[step]), title)
			return _point(sim, next_id, "system", next_id, title)
	return {}


static func live_summary(sim) -> String:
	var beat := str(sim.quest_flags.get("shakedown_beat", "undock"))
	var choice := str(sim.quest_flags.get("harvest_choice", ""))
	var npc := str(sim.quest_flags.get("npc_name", ""))
	var memory := str(sim.quest_flags.get("npc_memory", ""))
	var price := 4
	if sim.market is Dictionary:
		price = int(sim.market.get("glasswheat", 4))
	var where := str(focus(sim).get("label", ""))
	var head := "Shakedown. Next: %s. Mark: %s. Glasswheat price %d." % [beat, where, price]
	if choice != "":
		head += " Harvest on the slate: %s." % choice
	if npc != "":
		head += " %s remembers the %s cut." % [npc, memory]
	if bool(sim.quest_flags.get("warrant", false)):
		head += " A warrant is still open."
	if bool(sim.quest_flags.get("repair_discount", false)):
		head += " Dock repair is waived."
	if bool(sim.quest_flags.get("rumor_homestead", false)):
		head += " First Soil is offering homestead contracts."
	return head


static func _shakedown(sim) -> void:
	var beat := str(sim.quest_flags.get("shakedown_beat", ""))
	if beat == "" or beat == "done" or beat == "failed":
		return
	if beat == "garden" and sim.claim.has("pen"):
		var pen: Dictionary = sim.claim.pen
		if not bool(pen.get("alive", false)):
			_fail_shakedown(sim)
			return
	match beat:
		"undock":
			if _moved(sim):
				_advance(sim, "scan", "Undocked. Scan Aegis Prime with a probe.")
		"scan":
			if sim.dossier_complete("aegis_prime"):
				_apply(sim, "origin_vesper")
				_advance(sim, "harvest", "Aegis Prime is on the dossier. Cut the ice ring, or cut Seized Hold.")
		"harvest":
			var choice := _harvest_choice(sim)
			if choice != "":
				sim.quest_flags.harvest_choice = choice
				_apply(sim, "harvest_choice")
				if sim.projectiles.is_empty():
					sim.pdo_alert = false
				_advance(sim, "module", "The cut is remembered. Bolt one module. The silhouette has to change.")
		"module":
			var mods: Array = sim.player.get("modules", [])
			if mods.size() > 0:
				_advance(sim, "pirate", "The keel is no longer stock. Meet the Red Keel and leave alive.")
		"pirate":
			if _pirate_resolved(sim):
				_apply(sim, "origin_kestrel")
				_advance(sim, "claim", "You are still flying. First Soil will take a Claim Core.")
		"claim":
			if bool(sim.claim.get("owned", false)) and str(sim.claim.get("system_id", "")) == "HC-V1-R5-S1" and bool(sim.claim.get("core", false)):
				_apply(sim, "rumor_homestead")
				sim.quest_flags.food_at_claim = _food_total(sim)
				_advance(sim, "garden", "The core is in Quiet Hollow. Cut glasswheat and keep the hold-kine alive.")
		"garden":
			if not bool(sim.quest_flags.get("wheat_cut", false)):
				if _food_total(sim) > int(sim.quest_flags.get("food_at_claim", 0)):
					sim.quest_flags.wheat_cut = true
					_apply(sim, "origin_anvil")
				return
			if sim.claim.has("pen") and bool(sim.claim.pen.get("alive", false)):
				_finish_shakedown(sim)


static func _contracts(sim, dt: float) -> void:
	for row in sim.contracts:
		var contract: Dictionary = row
		if str(contract.get("state", "")) != "active":
			continue
		contract.age = float(contract.get("age", 0.0)) + dt
		var template := str(contract.get("template", ""))
		if template == "defend" and _in_claim(sim):
			contract.pocket_time = float(contract.get("pocket_time", 0.0)) + dt
		if _contract_failed(sim, contract):
			_fail_contract(sim, contract)
		elif _contract_done(sim, contract):
			_succeed_contract(sim, contract)


static func _from_world(sim) -> Dictionary:
	for item in sim.craft:
		if str(item.state) == "lost" and not bool(sim.quest_flags.get("did_recover", false)):
			return _contract("recover", "helion_compact", "Recover the lost craft", "A probe or drone is gone. Bring wreck parts off its last position.", ["HC-V1-R1-S1", str(item.uid)], str(item.uid), float(item.pos.x), float(item.pos.y), str(sim.defs.system.id))
	if bool(sim.quest_flags.get("rumor_homestead", false)) and bool(sim.claim.get("owned", false)) and not bool(sim.claim.get("frozen", false)):
		if str(sim.defs.system.id) == "HC-V1-R5-S1" and _food_total(sim) > 0 and not bool(sim.quest_flags.get("did_deliver", false)):
			return _contract("deliver", "homestead", "Deliver glasswheat", "Move food mass from the claim to Helion Dock.", ["HC-V1-R5-S1", "HC-V1-R1-S1", "quiet_hollow"], "food_mass", 0.0, 0.0, "HC-V1-R5-S1")
		if str(sim.defs.system.id) == "HC-V1-R5-S1" and not bool(sim.quest_flags.get("did_defend", false)):
			return _contract("defend", "homestead", "Hold the hollow", "Stay in the claim pocket through a raid timer.", ["HC-V1-R5-S1", "quiet_hollow"], "quiet_hollow", float(sim.claim.get("x", sim.pocket_pos.x)), float(sim.claim.get("y", sim.pocket_pos.y)), "HC-V1-R5-S1")
	if _living_pirates(sim) > 0 and not bool(sim.quest_flags.get("did_cull", false)):
		var pack := "the pack"
		var named := str(sim.gang_name)
		if named != "":
			pack = named
		return _contract("cull", "helion_compact", "Cull or drive off %s" % pack, "Kill a %s skiff or leave them behind." % pack, ["HC-V1-R1-S1", "red_keel"], "red_keel", sim.pack_pos.x, sim.pack_pos.y, str(sim.defs.system.id))
	var unknown := _unknown_body(sim)
	if unknown != "" and not bool(sim.quest_flags.get("did_survey", false)):
		var node = sim.survey_node(unknown)
		var label := unknown
		var x := 0.0
		var y := 0.0
		if node != null:
			label = str(node.name)
			x = float(node.pos.x)
			y = float(node.pos.y)
		return _contract("survey", "helion_compact", "Survey %s" % label, "A layer on %s is still unknown. Seal it." % label, [str(sim.defs.system.id), unknown], unknown, x, y, str(sim.defs.system.id))
	return _density_offer(sim)


static func _density_offer(sim) -> Dictionary:
	if not bool(sim.quest_flags.get("did_survey", false)):
		return {}
	var chart: Dictionary = sim.defs.get("systems", {})
	if not bool(sim.quest_flags.get("did_ledger", false)) and chart.has("HC-V1-R1-S5"):
		return _contract("ledger", "helion_compact", "Scan Ledger", "Seal a layer on Bonded Loft. The bond is the job.", ["HC-V1-R1-S5", "bonded_loft"], "bonded_loft", 0.0, 0.0, "HC-V1-R1-S5")
	if not bool(sim.quest_flags.get("did_towline", false)) and chart.has("HC-V1-R2-S2"):
		return _contract("towline", "rimward_charter", "Escort Towline", "Take the keel to Towline and stay on the tug road.", ["HC-V1-R2-S2", "tug_yard"], "tug_yard", 0.0, 0.0, "HC-V1-R2-S2")
	if not bool(sim.quest_flags.get("did_gyre", false)) and chart.has("HC-V1-R6-S1"):
		return _contract("gyre", "red_keel", "Salvage Gyre", "Bring keel salvage out of the Swallow.", ["HC-V1-R6-S1", "the_swallow"], "the_swallow", 0.0, 0.0, "HC-V1-R6-S1")
	if not bool(sim.quest_flags.get("did_lantern", false)) and chart.has("HC-V1-R1-S2"):
		return _contract("lantern", "helion_compact", "Deliver to Brass Lantern", "Carry food mass to Brass Lantern.", ["HC-V1-R1-S2", "lamp_yard"], "food_mass", 0.0, 0.0, "HC-V1-R1-S2")
	if not bool(sim.quest_flags.get("did_defend", false)) and chart.has("HC-V1-R5-S1"):
		return _contract("defend", "homestead", "Defend First Soil", "Hold a garden pocket through the raid timer.", ["HC-V1-R5-S1", "quiet_hollow"], "quiet_hollow", 0.0, 0.0, "HC-V1-R5-S1")
	return _template_offer(sim)


static func _template_offer(sim) -> Dictionary:
	if not sim.defs.has("templates"):
		return {}
	var book = sim.defs.get("templates", {})
	if typeof(book) != TYPE_DICTIONARY or book.is_empty():
		return {}
	var streams: Array = []
	var streams_doc = sim.defs.get("streams", {})
	if typeof(streams_doc) == TYPE_DICTIONARY and typeof(streams_doc.get("streams", [])) == TYPE_ARRAY:
		streams = streams_doc.get("streams", [])
	var trash: Array = []
	var origins_doc = sim.defs.get("trash_origins", {})
	if typeof(origins_doc) == TYPE_DICTIONARY and typeof(origins_doc.get("origins", [])) == TYPE_ARRAY:
		trash = origins_doc.get("origins", [])
	var keys: Array = book.keys()
	if keys.has("meteor_window"):
		keys.erase("meteor_window")
		keys.push_front("meteor_window")
	for key in keys:
		var spec: Dictionary = book[key]
		var tid := str(spec.get("id", key))
		if bool(sim.quest_flags.get("did_%s" % tid, false)):
			continue
		var uses := str(spec.get("uses", ""))
		var list: Array = []
		if uses == "streams":
			list = streams
		elif uses == "trash":
			list = trash
		else:
			continue
		if list.is_empty():
			continue
		var pick: Dictionary = list[int(abs(hash(tid))) % list.size()]
		var made := _contract(tid, "rimward_charter", str(spec.get("title", tid)), str(spec.get("summary", "")), [str(pick.get("system_id", "")), str(pick.get("id", ""))], str(pick.get("id", "")), 0.0, 0.0, str(pick.get("system_id", "")))
		made.success_mutations = spec.get("success_mutations", [])
		made.failure_mutations = spec.get("failure_mutations", [])
		made.template = tid
		made.need_cargo = str(spec.get("need_cargo", "salvage_parts"))
		return made
	return {}


static func _template_done(sim, contract: Dictionary) -> bool:
	var template := str(contract.get("template", ""))
	var book = sim.defs.get("templates", {})
	if typeof(book) != TYPE_DICTIONARY or not book.has(template):
		return false
	var spec: Dictionary = book[template]
	var uses := str(spec.get("uses", ""))
	if uses != "streams" and uses != "trash":
		return false
	var need := str(spec.get("need_cargo", "salvage_parts"))
	return str(sim.defs.system.id) == str(contract.get("system_id", "")) and int(sim.player.cargo.get(need, 0)) > 0


static func _prelude_rows(quest: Dictionary) -> Array:
	var raw = quest.get("prelude", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw


static func _prelude_flag(quest_id: String, step_id: String) -> String:
	return "%s_%s" % [quest_id, step_id]


static func _prelude_clear(sim, quest: Dictionary, quest_id: String) -> bool:
	for raw in _prelude_rows(quest):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = raw
		var flag := _prelude_flag(quest_id, str(step.get("id", "")))
		if not bool(sim.quest_flags.get(flag, false)):
			return false
	return true


static func _open_prelude(sim, quest: Dictionary, quest_id: String) -> Dictionary:
	for raw in _prelude_rows(quest):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = raw
		var flag := _prelude_flag(quest_id, str(step.get("id", "")))
		if not bool(sim.quest_flags.get(flag, false)):
			return step
	return {}


static func _prelude_met(sim, step: Dictionary) -> bool:
	var reach: float = float(step.get("range", 0.0))
	var kind := str(step.get("kind", "alongside"))
	if kind == "sight":
		var role := str(step.get("role", ""))
		for actor in sim.actors:
			if not bool(actor.get("alive", false)):
				continue
			if str(actor.ai.get("role", "")) != role:
				continue
			if sim.player.pos.distance_to(actor.home) <= reach:
				return true
		return false
	var action := str(step.get("action", ""))
	for actor in sim.actors:
		if not bool(actor.get("alive", false)):
			continue
		if str(actor.ai.get("action", "")) != action:
			continue
		if sim.player.pos.distance_to(actor.pos) <= reach:
			return true
	return false


static func _advance_prelude(sim, quest: Dictionary, quest_id: String) -> void:
	var system_id := str(quest.get("system_id", ""))
	if system_id != "" and str(sim.defs.system.id) != system_id:
		return
	for raw in _prelude_rows(quest):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = raw
		var flag := _prelude_flag(quest_id, str(step.get("id", "")))
		if bool(sim.quest_flags.get(flag, false)):
			continue
		if not _prelude_met(sim, step):
			return
		sim.quest_flags[flag] = true
		sim.say("%s: %s." % [str(quest.get("title", quest_id)), str(step.get("label", "the step"))])
		return


static func _prelude_point(sim, step: Dictionary) -> Dictionary:
	var kind := str(step.get("kind", "alongside"))
	var label := str(step.get("label", "the step"))
	var pos := Vector2.ZERO
	if kind == "sight":
		var role := str(step.get("role", ""))
		for actor in sim.actors:
			if not bool(actor.get("alive", false)):
				continue
			if str(actor.ai.get("role", "")) != role:
				continue
			pos = actor.home
			break
	else:
		var action := str(step.get("action", ""))
		for actor in sim.actors:
			if not bool(actor.get("alive", false)):
				continue
			if str(actor.ai.get("action", "")) != action:
				continue
			pos = actor.pos
			break
	return {
		"system_id": str(sim.defs.system.id),
		"target_system": str(sim.defs.system.id),
		"kind": "prelude",
		"target_id": str(step.get("id", "")),
		"label": label,
		"x": pos.x,
		"y": pos.y,
	}


static func _data_hooks(sim) -> void:
	_note_open(sim)
	var quests = sim.defs.get("quests", {})
	if typeof(quests) != TYPE_DICTIONARY:
		return
	for key in quests.keys():
		var quest = quests[key]
		if typeof(quest) != TYPE_DICTIONARY:
			continue
		if not quest.has("route") and str(quest.get("body", "")) == "":
			continue
		var qid := str(quest.get("id", key))
		if str(sim.quest_flags.get(qid, "")) == "done":
			continue
		var hit := false
		if str(quest.get("body", "")) != "":
			var system_id := str(quest.get("system_id", ""))
			if system_id == "" or str(sim.defs.system.id) == system_id:
				_advance_prelude(sim, quest, qid)
				if _prelude_clear(sim, quest, qid):
					var rock = sim.planet(str(quest.body))
					if rock != null and sim.player.pos.distance_to(rock.pos) < float(rock.radius) + 240.0:
						hit = true
		if quest.has("route") and not hit:
			var route: Array = quest.route
			var step := int(sim.quest_flags.get("%s_step" % qid, 0))
			if step < route.size() and str(sim.defs.system.id) == str(route[step]):
				var need := str(quest.get("need_cargo", ""))
				var last := step == route.size() - 1
				if need != "" and last and int(sim.player.cargo.get(need, 0)) < 1:
					pass
				else:
					sim.quest_flags["%s_step" % qid] = step + 1
					sim.say("%s: %s." % [str(quest.get("title", qid)), str(sim.defs.system.name)])
					if step + 1 >= route.size():
						hit = true
		if hit:
			sim.quest_flags[qid] = "done"
			var was_tracked := _release_track(sim, qid)
			for mutation in quest.get("mutations", []):
				_apply(sim, str(mutation))
			sim.say("%s is on the slate." % str(quest.get("title", qid)))
			if was_tracked:
				sim.say("The guide is clear.")


static func _apply_open(sim, mutation: String) -> void:
	var text := mutation.to_lower()
	if text.contains("xp"):
		return
	if mutation.begins_with("rumor_"):
		_rumor(sim, mutation.replace("_", " "))
		sim.quest_flags[mutation] = true
		return
	if mutation.ends_with("_standing_up"):
		var fac := mutation.substr(0, mutation.length() - 12)
		var flag := "%s_standing" % fac
		sim.quest_flags[flag] = int(sim.quest_flags.get(flag, 0)) + 1
		return
	if mutation.begins_with("heat_"):
		var faction := mutation.substr(5)
		sim.heat[faction] = float(sim.heat.get(faction, 0.0)) + 8.0
		return
	if mutation == "claim_law_red":
		sim.quest_flags.claim_law = "red"


static func _shorts(sim) -> void:
	if str(sim.quest_flags.get("authored_aegis_01", "")) != "done":
		if str(sim.defs.system.id) == "HC-V1-R1-S1" and sim.dossier_complete("aegis_prime") and sim.player.pos.distance_to(sim.beacon_pos) < 180.0:
			sim.quest_flags.authored_aegis_01 = "done"
			_apply(sim, "dock_fee")
			_apply(sim, "rumor_inspection")
			sim.say("Aegis Prime inspection is on the slate.")
	if str(sim.quest_flags.get("authored_tallyrock_01", "")) != "done" and str(sim.defs.system.id) == "HC-V1-R2-S1":
		var rock = sim.planet("tallyrock")
		if rock != null and sim.player.pos.distance_to(rock.pos) < float(rock.radius) + 240.0:
			sim.quest_flags.authored_tallyrock_01 = "done"
			_apply(sim, "glasswheat_dearer")
			_apply(sim, "rumor_fine_print")
			sim.say("Tallyrock's fine print is on the slate.")
	if str(sim.quest_flags.get("authored_blight_01", "")) != "done":
		var failed: bool = sim.claim.has("plot") and str(sim.claim.plot.get("state", "")) == "failed" and str(sim.claim.get("system_id", "")) == "HC-V1-R5-S1"
		var stolen: bool = sim.claim.has("pen") and bool(sim.claim.pen.get("stolen", false))
		if failed or stolen:
			sim.quest_flags.authored_blight_01 = "done"
			_apply(sim, "rumor_blight")
			if failed:
				sim.market.glasswheat = int(sim.market.get("glasswheat", 4)) + 1
			sim.say("Green Wound kept a mark. Blight or a stolen kine.")
	if str(sim.quest_flags.get("authored_swallow_01", "")) != "done" and str(sim.defs.system.id) == "HC-V1-R6-S1" and int(sim.player.cargo.get("salvage_parts", 0)) > 0:
		sim.quest_flags.authored_swallow_01 = "done"
		_apply(sim, "rumor_swallow")
		_apply(sim, "salvage_grant")
		sim.say("The Swallow recovery is on the slate.")


static func _contract(template: String, giver: String, title: String, summary: String, locations: Array, target: String, x: float, y: float, system_id: String) -> Dictionary:
	var success: Array = []
	var failure: Array = []
	var limit := 240.0
	match template:
		"survey":
			success = ["rumor_survey", "compact_standing_up"]
			failure = ["rumor_survey_fail", "patrol_reinforced"]
		"cull":
			success = ["rumor_cull", "compact_standing_up"]
			failure = ["rumor_cull_fail", "compact_standing_down"]
		"deliver":
			success = ["rumor_deliver", "glasswheat_cheaper"]
			failure = ["rumor_deliver_fail", "glasswheat_dearer"]
			limit = 360.0
		"recover":
			success = ["rumor_recover", "salvage_grant"]
			failure = ["rumor_recover_fail", "compact_standing_down"]
		"defend":
			success = ["rumor_defend", "compact_standing_up"]
			failure = ["rumor_defend_fail", "compact_standing_down"]
			limit = 90.0
		"ledger":
			success = ["rumor_ledger"]
			failure = ["rumor_ledger_fail", "warrant"]
			limit = 360.0
		"towline":
			success = ["rumor_towline", "charter_standing_up"]
			failure = ["rumor_towline_fail"]
			limit = 360.0
		"gyre":
			success = ["rumor_gyre", "salvage_grant"]
			failure = ["rumor_gyre_fail"]
			limit = 360.0
		"lantern":
			success = ["rumor_lantern", "glasswheat_cheaper"]
			failure = ["rumor_lantern_fail", "glasswheat_dearer"]
			limit = 360.0
	return {
		"id": "systemic_%s" % template,
		"type": "systemic",
		"kind": "systemic",
		"template": template,
		"giver": giver,
		"prerequisites": [],
		"location_ids": locations,
		"timers": {"limit": limit},
		"age": 0.0,
		"pocket_time": 0.0,
		"success_mutations": success,
		"failure_mutations": failure,
		"title": title,
		"summary": summary,
		"state": "offered",
		"target": target,
		"x": x,
		"y": y,
		"system_id": system_id,
	}


static func _contract_done(sim, contract: Dictionary) -> bool:
	var template := str(contract.get("template", ""))
	var target := str(contract.get("target", ""))
	match template:
		"survey":
			return _body_known(sim, target)
		"cull":
			return _pirate_resolved(sim)
		"deliver":
			return str(contract.get("origin_system", "")) == "HC-V1-R5-S1" and str(sim.defs.system.id) == "HC-V1-R1-S1" and int(sim.player.cargo.get("food_mass", 0)) > 0
		"recover":
			if str(sim.defs.system.id) != str(contract.get("system_id", "")):
				return false
			var spot := Vector2(float(contract.get("x", 0.0)), float(contract.get("y", 0.0)))
			return sim.player.pos.distance_to(spot) < 140.0
		"defend":
			return float(contract.get("pocket_time", 0.0)) >= 48.0 and not bool(sim.claim.get("ruptured", false))
		"ledger":
			return str(sim.defs.system.id) == "HC-V1-R1-S5" and _body_known(sim, target)
		"towline":
			return str(sim.defs.system.id) == "HC-V1-R2-S2"
		"gyre":
			return str(sim.defs.system.id) == "HC-V1-R6-S1" and int(sim.player.cargo.get("salvage_parts", 0)) > 0
		"lantern":
			return str(sim.defs.system.id) == "HC-V1-R1-S2" and int(sim.player.cargo.get("food_mass", 0)) > 0
		_:
			return _template_done(sim, contract)


static func _contract_failed(sim, contract: Dictionary) -> bool:
	var limit := float(contract.get("timers", {}).get("limit", 240.0))
	if str(contract.get("template", "")) == "defend" and bool(sim.claim.get("ruptured", false)):
		return true
	return float(contract.get("age", 0.0)) > limit


static func _succeed_contract(sim, contract: Dictionary) -> void:
	contract.state = "done"
	var was_tracked := _release_track(sim, str(contract.get("id", "")))
	var template := str(contract.get("template", ""))
	sim.quest_flags["did_%s" % template] = true
	if template == "deliver":
		sim.spend_cargo("food_mass", 1)
	for mutation in contract.get("success_mutations", []):
		_apply(sim, str(mutation))
	sim.say("%s is done. The sector keeps the change." % str(contract.title))
	if was_tracked:
		sim.say("The guide is clear.")


static func _fail_contract(sim, contract: Dictionary) -> void:
	contract.state = "failed"
	var was_tracked := _release_track(sim, str(contract.get("id", "")))
	var template := str(contract.get("template", ""))
	sim.quest_flags["did_%s" % template] = true
	for mutation in contract.get("failure_mutations", []):
		_apply(sim, str(mutation))
	sim.say("%s failed. The slate kept a mark." % str(contract.title))
	if was_tracked:
		sim.say("The guide is clear.")


static func _finish_shakedown(sim) -> void:
	sim.quest_flags.shakedown_beat = "done"
	sim.quest_flags.authored_shakedown_01 = "done"
	var shakedown_tracked := _release_track(sim, "authored_shakedown_01")
	var quest: Dictionary = sim.defs.quests.get("authored_shakedown_01", {})
	for mutation in quest.get("success_mutations", []):
		_apply(sim, str(mutation))
	var part := str(sim.quest_flags.get("blueprint", "a blueprint"))
	var nice := part
	if sim.defs.modules.has(part):
		nice = str(sim.defs.modules[part].name)
	sim.say("Shakedown is filed. Clerk Ivo Ram leaves a blueprint for the %s." % nice)
	if shakedown_tracked:
		sim.say("The guide is clear.")


static func _fail_shakedown(sim) -> void:
	if str(sim.quest_flags.get("shakedown_beat", "")) == "failed":
		return
	sim.quest_flags.shakedown_beat = "failed"
	sim.quest_flags.authored_shakedown_01 = "failed"
	var quest: Dictionary = sim.defs.quests.get("authored_shakedown_01", {})
	for mutation in quest.get("failure_mutations", []):
		_apply(sim, str(mutation))
	sim.say("The hold-kine is dead before the cut. Shakedown fails. The slate keeps it.")


static func _advance(sim, nxt: String, line: String) -> void:
	sim.quest_flags.shakedown_beat = nxt
	sim.say(line)


static func _apply(sim, mutation: String) -> void:
	var once := mutation != "harvest_choice" and mutation != "origin_vesper" and mutation != "origin_anvil" and mutation != "origin_kestrel" and mutation != "compact_standing_up" and mutation != "compact_standing_down" and mutation != "charter_standing_up" and mutation != "glasswheat_cheaper" and mutation != "glasswheat_dearer" and mutation != "salvage_grant"
	var key := "applied_%s" % mutation
	if once:
		if bool(sim.quest_flags.get(key, false)):
			return
		sim.quest_flags[key] = true
	match mutation:
		"harvest_choice":
			if str(sim.quest_flags.get("harvest_choice", "")) == "legal":
				_apply(sim, "compact_standing_up")
				_apply(sim, "repair_discount")
			else:
				_apply(sim, "warrant")
				_apply(sim, "inspect_pending")
				_apply(sim, "compact_standing_down")
		"compact_standing_up":
			sim.quest_flags.compact_standing = int(sim.quest_flags.get("compact_standing", 0)) + 1
		"compact_standing_down":
			sim.quest_flags.compact_standing = int(sim.quest_flags.get("compact_standing", 0)) - 1
		"charter_standing_up":
			sim.quest_flags.charter_standing = int(sim.quest_flags.get("charter_standing", 0)) + 1
		"repair_discount":
			sim.quest_flags.repair_discount = true
		"warrant":
			sim.quest_flags.warrant = true
		"inspect_pending":
			sim.quest_flags.inspect_pending = true
		"rumor_homestead":
			sim.quest_flags.rumor_homestead = true
			_rumor(sim, "First Soil will take homestead contracts.")
		"blueprint":
			var pick := _reward_module(sim)
			sim.quest_flags.blueprint = pick
			var yard: Array = sim.player.yard
			if not yard.has(pick):
				yard.append(pick)
		"npc_memory":
			sim.quest_flags.npc_name = "Ivo Ram"
			sim.quest_flags.npc_memory = str(sim.quest_flags.get("harvest_choice", "unset"))
		"origin_vesper":
			if str(sim.player.class_id) == "vesper":
				sim.quest_flags.origin_note = "The Compact survey office notices the scan quality."
				sim.say(str(sim.quest_flags.origin_note))
		"origin_anvil":
			if str(sim.player.class_id) == "anvil":
				sim.quest_flags.origin_note = "A Charter-adjacent factor wants the grain numbers."
				sim.say(str(sim.quest_flags.origin_note))
		"origin_kestrel":
			if str(sim.player.class_id) == "kestrel":
				sim.quest_flags.origin_note = "The patrol lead comments on the pirate contact."
				sim.say(str(sim.quest_flags.origin_note))
		"rumor_ledger":
			_rumor(sim, "Ledger's bond loft has a sealed layer.")
		"rumor_ledger_fail":
			_rumor(sim, "The Ledger survey lapsed. A warrant is warmer.")
		"rumor_towline":
			_rumor(sim, "Towline paid the escort. The Charter remembers.")
		"rumor_towline_fail":
			_rumor(sim, "The Towline escort never arrived.")
		"rumor_gyre":
			_rumor(sim, "The Swallow gave up salvage.")
		"rumor_gyre_fail":
			_rumor(sim, "A Gyre salvage contract came home empty.")
		"rumor_lantern":
			_rumor(sim, "Brass Lantern bought the grain. The price eased.")
		"rumor_lantern_fail":
			_rumor(sim, "Brass Lantern missed the delivery. Grain is dearer.")
		"rumor_inspection":
			_rumor(sim, "Aegis Prime logged an inspection.")
		"rumor_fine_print":
			_rumor(sim, "Tallyrock's fine print moved the grain futures.")
		"rumor_blight":
			_rumor(sim, "Green Wound has blight, or the kine were taken.")
		"rumor_swallow":
			_rumor(sim, "A lost craft came out of the Swallow.")
		"dock_fee":
			sim.market["dock_fee"] = int(sim.market.get("dock_fee", 2)) + 1
			sim.quest_flags.world_dock_fee = true
		"rumor_survey":
			_rumor(sim, "The survey office has a new sealed layer.")
		"rumor_survey_fail":
			_rumor(sim, "A survey contract lapsed.")
		"patrol_reinforced":
			sim.quest_flags.patrol_reinforced = true
		"rumor_cull":
			_rumor(sim, "The Red Keel pack was met and did not keep the lane.")
		"rumor_cull_fail":
			_rumor(sim, "The pack was left to sit.")
		"rumor_deliver":
			_rumor(sim, "Glasswheat reached Helion Dock.")
		"rumor_deliver_fail":
			_rumor(sim, "A grain delivery never arrived.")
		"glasswheat_cheaper":
			sim.market.glasswheat = maxi(1, int(sim.market.get("glasswheat", 4)) - 2)
			sim.quest_flags.world_glasswheat = "cheaper"
		"glasswheat_dearer":
			sim.market.glasswheat = int(sim.market.get("glasswheat", 4)) + 2
			sim.quest_flags.world_glasswheat = "dearer"
		"salvage_grant":
			sim._add_cargo("salvage_parts", 1)
			sim.quest_flags.world_salvage = true
		"rumor_recover":
			_rumor(sim, "Wreck parts came back aboard.")
		"rumor_recover_fail":
			_rumor(sim, "A lost craft was left on the board.")
		"rumor_defend":
			_rumor(sim, "Quiet Hollow held through the raid timer.")
		"rumor_defend_fail":
			_rumor(sim, "The hollow was not held.")
		"rumor_shakedown_fail":
			_rumor(sim, "Shakedown failed on the pen.")
		_:
			_apply_open(sim, mutation)


static func _rumor(sim, line: String) -> void:
	if not sim.quest_flags.has("rumors"):
		sim.quest_flags.rumors = []
	var rumors: Array = sim.quest_flags.rumors
	rumors.append(line)


static func _reward_module(sim) -> String:
	var mods: Array = sim.player.get("modules", [])
	for module_id in REWARDS:
		if not mods.has(module_id):
			return module_id
	return "sensor_mast"


static func _moved(sim) -> bool:
	var origin := Vector2(float(sim.quest_flags.get("dock_x", sim.player.pos.x)), float(sim.quest_flags.get("dock_y", sim.player.pos.y)))
	if sim.player.pos.distance_to(origin) > 40.0:
		return true
	return sim.player.vel.length() > 12.0


static func _harvest_choice(sim) -> String:
	var mem: Array = sim.memory.get("helion_compact", [])
	var legal := -1
	var illegal := -1
	for i in mem.size():
		var tag := str(mem[i])
		if tag == "lease_cut" and legal < 0:
			legal = i
		if tag == "harvested_protected" and illegal < 0:
			illegal = i
	if legal < 0 and illegal < 0:
		return ""
	if illegal < 0 or (legal >= 0 and legal < illegal):
		return "legal"
	return "illegal"


static func _pirate_resolved(sim) -> bool:
	var near := false
	var dead := 0
	var close_living := 0
	for actor in sim.actors:
		if str(actor.team) != "red_keel":
			continue
		if not bool(actor.alive):
			dead += 1
			continue
		if sim.player.pos.distance_to(actor.pos) < 680.0:
			near = true
			close_living += 1
		elif sim.player.pos.distance_to(actor.pos) < 1100.0:
			close_living += 1
	if near:
		sim.quest_flags.pirate_touched = true
	if not bool(sim.quest_flags.get("pirate_touched", false)):
		return false
	if not bool(sim.player.alive):
		return false
	if dead > 0:
		return true
	return close_living == 0


static func _living_pirates(sim) -> int:
	var n := 0
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			n += 1
	return n


static func _unknown_body(sim) -> String:
	for row in sim.nodes:
		var node_id := str(row.id)
		if not sim.dossier_complete(node_id):
			return node_id
	return ""


static func _body_known(sim, node_id: String) -> bool:
	if sim.dossier_complete(node_id):
		return true
	if not sim.scans.has(node_id):
		return false
	var dossier: Dictionary = sim.scans[node_id]
	var layers: Dictionary = dossier.get("layers", {})
	for key in layers.keys():
		if bool(layers[key].get("known", false)):
			return true
	return false


static func _food_total(sim) -> int:
	var crate := 0
	if sim.claim.has("crate"):
		crate = int(sim.claim.crate.get("food", 0))
	return int(sim.player.cargo.get("food_mass", 0)) + crate


static func _in_claim(sim) -> bool:
	if not bool(sim.claim.get("owned", false)):
		return false
	if str(sim.claim.get("system_id", "")) != str(sim.defs.system.id):
		return false
	return sim.player.pos.distance_to(sim.pocket_pos) <= float(sim.defs.system.pocket.get("radius", 0.0))


static func _open_contract(sim) -> bool:
	for row in sim.contracts:
		var state := str(row.get("state", ""))
		if state == "offered" or state == "active":
			return true
	return false


static func _active_contract(sim) -> Dictionary:
	for row in sim.contracts:
		var contract: Dictionary = row
		var state := str(contract.get("state", ""))
		if state == "offered" or state == "active":
			return contract
	return {}


static func _contract_focus(sim, contract: Dictionary) -> Dictionary:
	var template := str(contract.get("template", ""))
	var target := str(contract.get("target", ""))
	var title := str(contract.get("title", "contract"))
	var system_id := str(contract.get("system_id", sim.defs.system.id))
	var stored := Vector2(float(contract.get("x", 0.0)), float(contract.get("y", 0.0)))
	var food := int(sim.player.cargo.get("food_mass", 0))
	match template:
		"cull":
			return _point(sim, str(sim.defs.system.id), "patrol", "red_keel", title)
		"recover":
			var spot := stored
			for item in sim.craft:
				if str(item.uid) == target:
					spot = item.pos
					break
			return _mark_at(sim, system_id, "wreck", target, title, spot)
		"survey", "ledger":
			return _point(sim, system_id, "body", target, title)
		"deliver":
			if food > 0:
				return _point(sim, "HC-V1-R1-S1", "pad", "helion_dock", "Helion Dock")
			return _point(sim, "HC-V1-R5-S1", "claim", "quiet_hollow", "Quiet Hollow")
		"defend":
			return _point(sim, "HC-V1-R5-S1", "claim", "quiet_hollow", title)
		"lantern":
			if food > 0:
				return _point(sim, "HC-V1-R1-S2", "body", "lamp_yard", title)
			return _point(sim, "HC-V1-R5-S1", "claim", "quiet_hollow", title)
		"towline":
			return _point(sim, "HC-V1-R2-S2", "body", target, title)
		"gyre":
			return _point(sim, "HC-V1-R6-S1", "body", target, title)
		"meteor_window", "choir_ash_window":
			var rain: Vector2 = sim.stream_origin
			if rain == Vector2.ZERO:
				rain = stored
			return _mark_at(sim, system_id, "stream", target, title, rain)
		"unpaid_tow":
			var dump: Vector2 = sim.trash_pos
			if dump == Vector2.ZERO:
				dump = stored
			return _mark_at(sim, system_id, "trash", target, title, dump)
		_:
			if stored != Vector2.ZERO and str(sim.defs.system.id) == system_id:
				return _mark_at(sim, system_id, template, target, title, stored)
			return _point(sim, system_id, "body", target, title)


static func _mark_at(sim, system_id: String, kind: String, target_id: String, label: String, pos: Vector2) -> Dictionary:
	if str(sim.defs.system.id) != system_id:
		return _point(sim, system_id, kind, target_id, label)
	if pos == Vector2.ZERO:
		pos = _local_pos(sim, kind, target_id)
	return {
		"system_id": str(sim.defs.system.id),
		"target_system": system_id,
		"kind": kind,
		"target_id": target_id,
		"label": label,
		"x": pos.x,
		"y": pos.y,
	}


static func _point(sim, system_id: String, kind: String, target_id: String, label: String) -> Dictionary:
	var here := str(sim.defs.system.id) == system_id
	var pos := Vector2.ZERO
	var draw_system := system_id
	var draw_label := label
	if not here:
		var gate := _gate_toward(sim, system_id)
		if not gate.is_empty():
			pos = gate.pos
			draw_system = str(sim.defs.system.id)
			draw_label = "%s, via %s" % [label, str(gate.get("name", "the lane"))]
			kind = "system"
			target_id = str(gate.get("id", target_id))
	else:
		pos = _local_pos(sim, kind, target_id)
	return {
		"system_id": draw_system,
		"target_system": system_id,
		"kind": kind,
		"target_id": target_id,
		"label": draw_label,
		"x": pos.x,
		"y": pos.y,
	}


static func _local_pos(sim, kind: String, target_id: String) -> Vector2:
	if kind == "claim":
		if bool(sim.claim.get("owned", false)) and str(sim.claim.get("system_id", "")) == str(sim.defs.system.id):
			return Vector2(float(sim.claim.get("x", sim.pocket_pos.x)), float(sim.claim.get("y", sim.pocket_pos.y)))
		return sim.pocket_pos
	if kind == "pad":
		return sim.beacon_pos
	if kind == "patrol" and target_id == "red_keel":
		return sim.pack_pos
	if kind == "cull":
		return sim.pack_pos
	if kind == "patrol":
		for actor in sim.actors:
			if str(actor.team) == "helion_compact" and bool(actor.alive):
				return actor.pos
		return sim.beacon_pos
	if kind == "stream":
		if sim.stream_origin != Vector2.ZERO:
			return sim.stream_origin
	if kind == "trash":
		if sim.trash_pos != Vector2.ZERO:
			return sim.trash_pos
	if kind == "wreck":
		for item in sim.craft:
			if str(item.uid) == target_id:
				return item.pos
		for wreck in sim.wrecks:
			if str(wreck.get("id", "")) == target_id:
				return wreck.pos
	if kind == "body" or kind == "survey" or kind == "ledger" or kind == "gyre" or kind == "towline" or kind == "lantern":
		var node = sim.survey_node(target_id)
		if node != null:
			return node.pos
		var body = sim.planet(target_id)
		if body != null:
			return body.pos
	if kind == "keel":
		return sim.player.pos
	var named = sim.survey_node(target_id)
	if named != null:
		return named.pos
	var rock = sim.planet(target_id)
	if rock != null:
		return rock.pos
	return sim.beacon_pos


static func _gate_toward(sim, system_id: String) -> Dictionary:
	for gate in sim.gates:
		var row: Dictionary = gate
		if str(row.get("to", "")) == system_id:
			return row
	return {}
