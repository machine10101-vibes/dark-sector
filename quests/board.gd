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


static func mark(sim) -> String:
	var focus := focus(sim)
	sim.nav_mark = focus
	sim.say("Mark on %s. The keel stays where it is." % str(focus.get("label", "the mark")))
	return ""


static func on_arrive(sim) -> void:
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
		return _contract("cull", "helion_compact", "Cull or drive off the pack", "Kill a Red Keel skiff or leave them behind.", ["HC-V1-R1-S1", "red_keel"], "red_keel", sim.pack_pos.x, sim.pack_pos.y, str(sim.defs.system.id))
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
	var streams_doc = sim.defs.get("streams", {})
	if typeof(streams_doc) != TYPE_DICTIONARY:
		return {}
	var list: Array = streams_doc.get("streams", [])
	if list.is_empty():
		return {}
	for key in book.keys():
		var spec: Dictionary = book[key]
		var tid := str(spec.get("id", key))
		if bool(sim.quest_flags.get("did_%s" % tid, false)):
			continue
		if str(spec.get("uses", "")) != "streams":
			continue
		var pick: Dictionary = list[int(abs(hash(tid))) % list.size()]
		var made := _contract(tid, "rimward_charter", str(spec.get("title", tid)), str(spec.get("summary", "")), [str(pick.get("system_id", "")), str(pick.get("id", ""))], str(pick.get("id", "")), 0.0, 0.0, str(pick.get("system_id", "")))
		made.success_mutations = spec.get("success_mutations", [])
		made.failure_mutations = spec.get("failure_mutations", [])
		made.template = tid
		return made
	return {}


static func _template_done(sim, contract: Dictionary) -> bool:
	var template := str(contract.get("template", ""))
	var book = sim.defs.get("templates", {})
	if typeof(book) != TYPE_DICTIONARY or not book.has(template):
		return false
	var spec: Dictionary = book[template]
	if str(spec.get("uses", "")) != "streams":
		return false
	return str(sim.defs.system.id) == str(contract.get("system_id", "")) and int(sim.player.cargo.get("salvage_parts", 0)) > 0


static func _data_hooks(sim) -> void:
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
			for mutation in quest.get("mutations", []):
				_apply(sim, str(mutation))
			sim.say("%s is on the slate." % str(quest.get("title", qid)))


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
	var template := str(contract.get("template", ""))
	sim.quest_flags["did_%s" % template] = true
	if template == "deliver":
		sim.spend_cargo("food_mass", 1)
	for mutation in contract.get("success_mutations", []):
		_apply(sim, str(mutation))
	sim.say("%s is done. The sector keeps the change." % str(contract.title))


static func _fail_contract(sim, contract: Dictionary) -> void:
	contract.state = "failed"
	var template := str(contract.get("template", ""))
	sim.quest_flags["did_%s" % template] = true
	for mutation in contract.get("failure_mutations", []):
		_apply(sim, str(mutation))
	sim.say("%s failed. The slate kept a mark." % str(contract.title))


static func _finish_shakedown(sim) -> void:
	sim.quest_flags.shakedown_beat = "done"
	sim.quest_flags.authored_shakedown_01 = "done"
	var quest: Dictionary = sim.defs.quests.get("authored_shakedown_01", {})
	for mutation in quest.get("success_mutations", []):
		_apply(sim, str(mutation))
	var part := str(sim.quest_flags.get("blueprint", "a blueprint"))
	var nice := part
	if sim.defs.modules.has(part):
		nice = str(sim.defs.modules[part].name)
	sim.say("Shakedown is filed. Clerk Ivo Ram leaves a blueprint for the %s." % nice)


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
		"glasswheat_dearer":
			sim.market.glasswheat = int(sim.market.get("glasswheat", 4)) + 2
		"salvage_grant":
			sim._add_cargo("salvage_parts", 1)
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
	return _point(sim, str(contract.get("system_id", sim.defs.system.id)), str(contract.get("template", "system")), str(contract.get("target", "")), str(contract.get("title", "contract")))


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
	if kind == "patrol" and target_id == "red_keel":
		return sim.pack_pos
	if kind == "patrol":
		for actor in sim.actors:
			if str(actor.team) == "helion_compact" and bool(actor.alive):
				return actor.pos
		return sim.beacon_pos
	if kind == "body":
		var node = sim.survey_node(target_id)
		if node != null:
			return node.pos
		var body = sim.planet(target_id)
		if body != null:
			return body.pos
	if kind == "keel":
		return sim.player.pos
	return sim.beacon_pos


static func _gate_toward(sim, system_id: String) -> Dictionary:
	for gate in sim.gates:
		var row: Dictionary = gate
		if str(row.get("to", "")) == system_id:
			return row
	return {}
