extends SceneTree

var defs: Dictionary = {}
var fails := 0


func _init() -> void:
	var helion: Dictionary = Serde.load_json("res://data/system.json")
	var soil: Dictionary = Serde.load_json("res://data/first_soil.json")
	defs = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": helion,
		"systems": {
			str(helion.id): helion,
			str(soil.id): soil,
		},
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
	}
	_data()
	_shakedown("vesper", true)
	_shakedown("anvil", true)
	_shakedown("kestrel", false)
	_choice_lasts()
	_contracts()
	_kine_fail()
	_save()
	if fails == 0:
		print("SLICE6 PASS")
	else:
		print("SLICE6 FAIL %d" % fails)
	quit(fails)


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func make(class_id: String) -> SectorSim:
	var sim := SectorSim.new(defs)
	sim.new_game(class_id)
	sim.hold_npc = true
	return sim


func _data() -> void:
	var quest: Dictionary = defs.quests.authored_shakedown_01
	check(str(quest.type) == "authored", "shakedown is an authored quest object")
	check(str(quest.giver) == "helion_compact", "shakedown has a giver")
	check(quest.location_ids.has("quiet_hollow"), "shakedown names Quiet Hollow")
	check(quest.success_mutations.has("blueprint"), "success mutations are on the quest")
	check(quest.failure_mutations.has("rumor_shakedown_fail"), "failure mutations are on the quest")
	check(quest.beats.size() == 7, "shakedown has seven beats")


func _shakedown(class_id: String, legal: bool) -> void:
	var sim := make(class_id)
	var stayed: Vector2 = sim.player.pos
	QuestBoard.mark(sim)
	check(sim.player.pos.distance_to(stayed) < 0.1, "%s mark does not move the keel" % class_id)
	check(str(sim.nav_mark.get("label", "")) != "", "%s mark names a place" % class_id)
	sim.player.pos += Vector2(80, 0)
	QuestBoard.pulse(sim, 0.1)
	check(str(sim.quest_flags.shakedown_beat) == "scan", "%s undock advances the arc" % class_id)
	for layer in CraftOrders.LAYERS:
		sim.reveal_layer("aegis_prime", layer)
	QuestBoard.pulse(sim, 0.1)
	check(str(sim.quest_flags.shakedown_beat) == "harvest", "%s scan is the next beat" % class_id)
	if class_id == "vesper":
		check("scan quality" in str(sim.quest_flags.get("origin_note", "")), "Vesper hears the survey office")
	if legal:
		check(sim.try_extract("aegis_ring") == "ok", "%s can cut the ice ring" % class_id)
	else:
		sim.player.cargo["raw_mass"] = 2
		check(sim.try_extract("seized_hold") == "ok", "Beak can cut the seized hold")
	QuestBoard.pulse(sim, 0.1)
	check(str(sim.quest_flags.harvest_choice) == ("legal" if legal else "illegal"), "%s harvest choice is stored" % class_id)
	check(sim.install("sensor_mast").ok, "%s bolts a module" % class_id)
	QuestBoard.pulse(sim, 0.1)
	check(str(sim.quest_flags.shakedown_beat) == "pirate", "%s module beat follows the cut" % class_id)
	var pirate: Dictionary = {}
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			pirate = actor
			break
	sim.player.pos = pirate.pos + Vector2(180, 0)
	QuestBoard.pulse(sim, 0.1)
	sim.player.pos = Vector2(9000, 9000)
	QuestBoard.pulse(sim, 0.1)
	check(str(sim.quest_flags.shakedown_beat) == "claim", "%s leaves the pirate contact alive" % class_id)
	if class_id == "kestrel":
		check("patrol lead" in str(sim.quest_flags.get("origin_note", "")), "Kestrel hears the patrol lead")
	var gate: Dictionary = sim.gates[0]
	sim.player.pos = gate.pos
	check(sim.try_lane() == "", "%s takes the lane" % class_id)
	sim.player.pos = sim.pocket_pos
	check(Homestead.try_plant(sim) == "", "%s plants on Quiet Hollow" % class_id)
	QuestBoard.pulse(sim, 0.1)
	check(bool(sim.quest_flags.get("rumor_homestead", false)), "%s unlocks homestead contracts" % class_id)
	sim.claim.plot.water = 100.0
	sim.tick(10.0, {})
	check(Homestead.feed(sim) == "", "%s feeds the kine" % class_id)
	sim.tick(11.0, {})
	check(str(sim.claim.plot.state) == "ripe", "%s glasswheat ripens" % class_id)
	check(Homestead.tend(sim) == "", "%s cuts the glasswheat" % class_id)
	sim.tick(0.4, {})
	check(str(sim.quest_flags.shakedown_beat) == "done", "%s finishes shakedown" % class_id)
	check(bool(sim.claim.pen.alive), "%s hold-kine is alive" % class_id)
	check(str(sim.quest_flags.blueprint) == "gun_sponson", "%s blueprint is the turret, not the mast already bolted" % class_id)
	check(str(sim.quest_flags.npc_name) == "Ivo Ram", "%s Clerk Ivo Ram is on the log" % class_id)
	check(str(sim.quest_flags.npc_memory) == ("legal" if legal else "illegal"), "%s Ram remembers the cut" % class_id)
	if class_id == "anvil":
		check("grain numbers" in str(sim.quest_flags.get("origin_note", "")), "Anvil hears the factor")
	if legal:
		check(bool(sim.quest_flags.repair_discount), "%s keeps the repair waiver" % class_id)
		check(int(sim.quest_flags.compact_standing) > 0, "%s Compact standing is up" % class_id)
	else:
		check(bool(sim.quest_flags.warrant), "the warrant outlives the arc")


func _choice_lasts() -> void:
	var legal := _finished("anvil", true)
	legal.player.hp = 20.0
	legal.player.cargo["raw_mass"] = 2
	legal.player.pos = legal.beacon_pos
	check(legal.try_repair() == "", "waived repair still welds")
	check(int(legal.player.cargo.get("raw_mass", 0)) == 2, "legal standing still waives the mass after the quest")
	var illegal := _finished("kestrel", false)
	var heat0 := float(illegal.heat.get("helion_compact", 0.0))
	var back: Dictionary = {}
	for row in illegal.gates:
		back = row
	illegal.player.pos = back.pos
	check(illegal.try_lane() == "", "the warrant rides back into Helion Dock")
	check(bool(illegal.quest_flags.warrant), "the warrant is still on the slate")
	check(not bool(illegal.quest_flags.inspect_pending), "the inspection was the next entry")
	check(float(illegal.heat.get("helion_compact", 0.0)) > heat0, "inspection raises heat")


func _contracts() -> void:
	var pirates := make("vesper")
	pirates.contracts = []
	var cull := QuestBoard.refresh(pirates)
	check(cull == "systemic_cull", "a living pirate pack offers a cull contract")
	var lost := make("vesper")
	lost.contracts = []
	lost.craft[0].state = "lost"
	lost.craft[0].pos = lost.player.pos
	var recover := QuestBoard.refresh(lost)
	check(recover == "systemic_recover", "a lost craft offers a recover contract")
	check(QuestBoard.accept(lost) == "", "the recover contract can be taken")
	QuestBoard.pulse(lost, 0.2)
	check(str(lost.contracts[0].state) == "done", "standing on the wreck parts finishes recover")
	check(int(lost.player.cargo.get("salvage_parts", 0)) > 0, "recover puts wreck parts in the hold")
	var survey := make("vesper")
	survey.contracts = []
	survey.quest_flags.did_cull = true
	survey.quest_flags.did_recover = true
	var offered := QuestBoard.refresh(survey)
	check(offered == "systemic_survey", "an unknown layer offers a survey contract")
	QuestBoard.accept(survey)
	survey.reveal_layer("aegis_prime", "orbit")
	QuestBoard.pulse(survey, 0.2)
	check(bool(survey.quest_flags.get("rumor_homestead", false)) == false, "survey does not pretend a claim rumor")
	check(survey.quest_flags.rumors.size() > 0, "survey success writes a rumor")
	check(int(survey.quest_flags.compact_standing) > 0, "survey success raises standing")
	var lapse := make("vesper")
	lapse.contracts = []
	lapse.quest_flags.did_cull = true
	lapse.quest_flags.did_recover = true
	QuestBoard.refresh(lapse)
	QuestBoard.accept(lapse)
	lapse.contracts[0].age = 250.0
	QuestBoard.pulse(lapse, 0.2)
	check(str(lapse.contracts[0].state) == "failed", "a survey timer can fail")
	check(bool(lapse.quest_flags.patrol_reinforced), "a failed survey calls another cutter")
	lapse.actors = []
	lapse._spawn_factions()
	var cutters := 0
	for actor in lapse.actors:
		if str(actor.team) == "helion_compact":
			cutters += 1
	check(cutters == int(lapse.defs.system.pdo.count) + 1, "the extra cutter is on the lane")
	var defend := _to_claim("vesper")
	defend.contracts = []
	defend.quest_flags.did_recover = true
	defend.quest_flags.did_cull = true
	var held := QuestBoard.refresh(defend)
	check(held == "systemic_defend", "a planted claim offers a defend contract")
	QuestBoard.accept(defend)
	defend.contracts[0].pocket_time = 47.5
	defend.player.pos = defend.pocket_pos
	QuestBoard.pulse(defend, 1.0)
	check(str(defend.contracts[0].state) == "done", "staying through the raid timer holds the hollow")
	var deliver := _to_claim("anvil")
	deliver.contracts = []
	deliver.quest_flags.did_recover = true
	deliver.quest_flags.did_cull = true
	deliver.quest_flags.did_defend = true
	deliver.player.cargo["food_mass"] = 1
	var haul := QuestBoard.refresh(deliver)
	check(haul == "systemic_deliver", "food at the claim offers a delivery")
	QuestBoard.accept(deliver)
	var road: Dictionary = deliver.gates[0]
	deliver.player.pos = road.pos
	check(deliver.try_lane() == "", "the grain takes the road to Helion Dock")
	QuestBoard.pulse(deliver, 0.2)
	check(str(deliver.contracts[0].state) == "done", "delivery completes on the dock")
	check(int(deliver.market.glasswheat) == 2, "delivery changes the glasswheat price")
	check(int(deliver.player.cargo.get("food_mass", 0)) == 0, "the food mass is delivered")


func _kine_fail() -> void:
	var sim := _to_claim("vesper")
	var standing := int(sim.quest_flags.compact_standing)
	sim.claim.pen.alive = false
	QuestBoard.pulse(sim, 0.1)
	check(str(sim.quest_flags.shakedown_beat) == "failed", "a dead kine fails the garden beat")
	check(int(sim.quest_flags.compact_standing) < standing, "failure lowers Compact standing")
	check(sim.quest_flags.rumors.size() > 0, "failure writes a rumor")


func _save() -> void:
	var sim := _finished("vesper", true)
	sim.nav_mark = QuestBoard.focus(sim)
	var parsed = JSON.parse_string(JSON.stringify(sim.to_dict()))
	var copy := SectorSim.new(defs)
	copy.from_dict(parsed)
	check(str(copy.quest_flags.shakedown_beat) == "done", "reload keeps the shakedown")
	check(str(copy.quest_flags.harvest_choice) == "legal", "reload keeps the harvest flag")
	check(str(copy.quest_flags.npc_memory) == "legal", "reload keeps who remembers the cut")
	check(bool(copy.quest_flags.repair_discount), "reload keeps the repair waiver")
	check(int(copy.market.glasswheat) == 4, "reload keeps the glasswheat price")
	check(str(copy.nav_mark.get("label", "")) != "", "reload keeps the quest mark")


func _finished(class_id: String, legal: bool) -> SectorSim:
	var sim := make(class_id)
	sim.player.pos += Vector2(80, 0)
	QuestBoard.pulse(sim, 0.1)
	for layer in CraftOrders.LAYERS:
		sim.reveal_layer("aegis_prime", layer)
	QuestBoard.pulse(sim, 0.1)
	if legal:
		sim.try_extract("aegis_ring")
	else:
		sim.player.cargo["raw_mass"] = 2
		sim.try_extract("seized_hold")
	QuestBoard.pulse(sim, 0.1)
	sim.install("sensor_mast")
	QuestBoard.pulse(sim, 0.1)
	var pirate: Dictionary = {}
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			pirate = actor
			break
	sim.player.pos = pirate.pos + Vector2(180, 0)
	QuestBoard.pulse(sim, 0.1)
	sim.player.pos = Vector2(9000, 9000)
	QuestBoard.pulse(sim, 0.1)
	sim.player.pos = sim.gates[0].pos
	sim.try_lane()
	sim.player.pos = sim.pocket_pos
	Homestead.try_plant(sim)
	QuestBoard.pulse(sim, 0.1)
	sim.claim.plot.water = 100.0
	sim.tick(10.0, {})
	Homestead.feed(sim)
	sim.tick(11.0, {})
	Homestead.tend(sim)
	sim.tick(0.4, {})
	return sim


func _to_claim(class_id: String) -> SectorSim:
	var sim := make(class_id)
	sim.player.pos += Vector2(80, 0)
	QuestBoard.pulse(sim, 0.1)
	for layer in CraftOrders.LAYERS:
		sim.reveal_layer("aegis_prime", layer)
	QuestBoard.pulse(sim, 0.1)
	sim.try_extract("aegis_ring")
	QuestBoard.pulse(sim, 0.1)
	sim.install("sensor_mast")
	QuestBoard.pulse(sim, 0.1)
	var pirate: Dictionary = {}
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			pirate = actor
			break
	sim.player.pos = pirate.pos + Vector2(180, 0)
	QuestBoard.pulse(sim, 0.1)
	sim.player.pos = Vector2(9000, 9000)
	QuestBoard.pulse(sim, 0.1)
	sim.player.pos = sim.gates[0].pos
	sim.try_lane()
	sim.player.pos = sim.pocket_pos
	Homestead.try_plant(sim)
	QuestBoard.pulse(sim, 0.1)
	return sim
