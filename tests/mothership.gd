extends SceneTree

var defs: Dictionary = {}
var fails := 0


func _init() -> void:
	defs = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": Serde.load_json("res://data/system.json"),
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
	}
	_tiers()
	_orders()
	_base()
	_mend()
	if fails == 0:
		print("MOTHERSHIP PASS")
	else:
		print("MOTHERSHIP FAIL %d" % fails)
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
	sim.quest_flags.moor_latch = 0.0
	return sim


func _craft(sim: SectorSim, uid: String):
	for item in sim.craft:
		if str(item.uid) == uid:
			return item
	return null


func _tiers() -> void:
	var sim := make("kestrel")
	check(CraftOrders.tier(sim, "mothership") == "base", "the mothership is the base")
	check(CraftOrders.tier(sim, "dart_drone") == "fleet", "a Dart is a fleet ship")
	check(CraftOrders.tier(sim, "fighter") == "fleet", "a fighter is a fleet ship")
	check(CraftOrders.tier(sim, "survey_probe") == "boat", "a probe is a boat")
	check(CraftOrders.tier(sim, "harvest_drone") == "boat", "a miner is a boat")
	check(CraftOrders.tier(sim, "repair_drone") == "boat", "a welder is a boat")
	check(float(sim.defs.craft.fighter.gun.damage) == 6.0, "the fighter gun is unchanged")


func _orders() -> void:
	var sim := make("kestrel")
	var fighter = _craft(sim, "fighter_1")
	var probe = _craft(sim, "survey_probe_1")
	check(CraftOrders.fleet(sim, "focus") == "Lock a ship first.", "focus waits for a lock")
	check(str(fighter.state) == "docked", "a refused focus leaves the fighter aboard")
	check(CraftOrders.fleet(sim, "screen") == "", "the wing takes a screen")
	check(str(fighter.order) == "screen", "screen holds the station")
	check(str(fighter.state) == "escort", "screen puts the fighter out")
	check(str(probe.state) == "docked", "screen leaves the probe on the keel")
	var skiff: Dictionary = sim._blank_ship("skiff", "Red Keel", "agent:red_keel:wing", "npc", "red_keel")
	skiff.pos = sim.player.pos + Vector2(400, 0)
	skiff.alive = true
	sim.actors.append(skiff)
	sim.player.lock_id = str(skiff.agent_id)
	sim.player.lock_ok = true
	check(CraftOrders.fleet(sim, "focus") == "", "focus takes the lock")
	check(str(fighter.order) == "attack", "focus is an attack order")
	check(str(fighter.target) == str(skiff.agent_id), "focus aims the locked ship")
	check(str(probe.state) == "docked", "focus leaves the probe on the keel")
	check(float(fighter.gun.damage) == 6.0, "focus does not retune the gun")


func _base() -> void:
	var sim := make("kestrel")
	var fighter = _craft(sim, "fighter_1")
	var probe = _craft(sim, "survey_probe_1")
	check(CraftOrders.berth(sim) == "Call the mothership first.", "berth waits for the base")
	check(CraftOrders.call_base(sim) == "", "the mothership answers")
	check(bool(sim.base.get("anchored", false)), "the mothership holds station")
	check(CraftOrders.call_base(sim) == "The mothership is already holding station.", "a second call leaves it there")
	check(_craft(sim, "repair_drone_1") != null, "calling the base racks a welder")
	check(str(_craft(sim, "repair_drone_1").home) == "keel", "the welder stays on the keel")
	check(CraftOrders.berth(sim) == "Bring the keel alongside the mothership.", "berth wants the keel alongside")
	sim.player.moored = false
	sim.player.pos = sim.base.pos
	sim.player.vel = Vector2.ZERO
	check(CraftOrders.berth(sim) == "", "the keel berths")
	check(bool(sim.player.moored), "the keel is stored on the mothership")
	check(bool(sim.quest_flags.berthed_base), "the berth is the base, not the pad")
	check(str(fighter.home) == "base", "the fighter is stored on the mothership")
	check(str(probe.get("home", "keel")) == "keel", "the probe stays on the keel")
	sim.quest_flags.moor_latch = 0.0
	sim.tick(0.1, {"thrust": 1.0, "rot": 0.0, "strafe": 0.0, "retro": 0.0})
	var said := false
	for line in sim.lines:
		if "mothership holds station" in str(line.text):
			said = true
	check(said, "cast off leaves the mothership on station")
	check(not bool(sim.player.moored), "the keel is flying again")
	sim.player.pos = sim.base.pos + Vector2(2200, 0)
	sim.player.vel = Vector2.ZERO
	check(CraftOrders.launch(sim, "fighter") == "", "the stored fighter launches")
	check(fighter.pos.distance_to(sim.base.pos) < 160.0, "the fighter leaves the mothership")
	check(fighter.pos.distance_to(sim.player.pos) > 1000.0, "the fighter does not launch from the keel")
	fighter.pos = sim.base.pos + Vector2(0, 500)
	fighter.state = "returning"
	fighter.order = "return"
	for _i in 40:
		sim.tick(0.2, {})
		if str(fighter.state) == "docked":
			break
	check(str(fighter.state) == "docked", "the fighter comes back to the bay")
	check(fighter.pos.distance_to(sim.base.pos) < 80.0, "the bay is on the mothership")
	check(fighter.pos.distance_to(sim.player.pos) > 500.0, "the fighter does not dock on the distant keel")
	var blob := sim.to_dict()
	var copy := SectorSim.new(defs)
	copy.from_dict(blob)
	check(copy.base.pos.distance_to(sim.base.pos) < 1.0, "reload keeps the mothership")
	check(str(_craft(copy, "fighter_1").home) == "base", "reload keeps the wing in the bay")
	check(str(_craft(copy, "survey_probe_1").get("home", "keel")) == "keel", "reload keeps the probe on the keel")


func _mend() -> void:
	var sim := make("kestrel")
	check(CraftOrders.call_base(sim) == "", "the welder comes with the base")
	var fighter = _craft(sim, "fighter_1")
	check(CraftOrders.fleet(sim, "form") == "", "the wing forms for the weld")
	fighter.hp = 4.0
	check(CraftOrders.mend(sim) == "", "the welder launches")
	var welder = _craft(sim, "repair_drone_1")
	check(str(welder.target) == str(fighter.uid), "the welder aims the hurt fighter")
	check(str(welder.order) == "mend", "mend is a weld order")
	var healed := false
	for _i in 120:
		sim.tick(0.05, {})
		if float(fighter.hp) >= 16.0:
			healed = true
			break
	check(healed, "the welder puts plate back on the fighter")
	check(float(fighter.gun.damage) == 6.0, "a weld does not retune the gun")
