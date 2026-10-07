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
	_racks()
	_fleet_orders()
	_escort_spread()
	_buy_wing()
	_scan_harvest_heat()
	_loss_and_save()
	_helm()
	if fails == 0:
		print("SLICE2 PASS")
	else:
		print("SLICE2 FAIL %d" % fails)
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


func _count(sim: SectorSim, def_id: String) -> int:
	var total := 0
	for item in sim.craft:
		if str(item.def_id) == def_id:
			total += 1
	return total


func _craft(sim: SectorSim, uid: String):
	for item in sim.craft:
		if str(item.uid) == uid:
			return item
	return null


func _racks() -> void:
	var vesper := make("vesper")
	check(_count(vesper, "survey_probe") == 2, "Vesper racks two survey probes")
	check(_count(vesper, "harvest_drone") == 1, "Vesper racks one harvest drone")
	var anvil := make("anvil")
	check(_count(anvil, "survey_probe") == 1, "Anvil racks one survey probe")
	check(_count(anvil, "harvest_drone") == 1, "Anvil racks one harvest drone")
	check(_count(anvil, "salvage_tender") == 1, "Anvil racks one salvage tender")
	check("parked" in CraftOrders.launch(anvil, "salvage_tender").to_lower(), "the tender stays parked")
	var kestrel := make("kestrel")
	check(_count(kestrel, "survey_probe") == 1, "Kestrel racks one survey probe")
	check(_count(kestrel, "fighter") == 1, "Kestrel racks one fighter")
	check(CraftOrders.launch(kestrel, "fighter") == "", "the fighter launches onto the wing")
	check(str(_craft(kestrel, "fighter_1").state) == "escort", "the fighter takes escort")
	check(not bool(vesper.defs.system.pocket.plantable), "the pocket stays closed")


func _fleet_orders() -> void:
	var kestrel := make("kestrel")
	var probe = _craft(kestrel, "survey_probe_1")
	var fighter = _craft(kestrel, "fighter_1")
	check(str(probe.state) == "docked", "the probe starts on the rack")
	check(CraftOrders.fleet(kestrel, "form") == "", "the wing forms")
	check(str(fighter.state) == "escort", "form puts the fighter on escort")
	check(str(fighter.order) == "escort", "form is an escort order")
	check(str(probe.state) == "docked", "forming the wing leaves the probe on the rack")
	check(CraftOrders.fleet(kestrel, "attack") == "", "the wing attacks")
	check(str(fighter.order) == "attack", "attack marks the wing")
	check(str(probe.state) == "docked", "attack leaves the probe on the rack")
	check(CraftOrders.order(kestrel, str(probe.uid), "orbit", "aegis_prime") == "", "a racked probe takes an orbit order")
	var flying: bool = str(probe.state) == "outbound" or str(probe.state) == "orbiting"
	check(flying, "the probe leaves the rack")
	check(CraftOrders.fleet(kestrel, "recall") == "", "recall brings the wing home")
	check(str(fighter.state) == "returning", "the fighter turns for the keel")
	check(str(probe.state) == "returning", "the probe turns for the keel")
	var vesper := make("vesper")
	check(CraftOrders.fleet(vesper, "form") == "No fighter is on the keel.", "a rack with no fighter has no wing")
	check(CraftOrders.fleet(vesper, "recall") == "Nothing is out to recall.", "nothing is out to recall")


func _escort_spread() -> void:
	var sim := make("kestrel")
	sim.time = 12.0
	var reach := float(Fit.stats(sim.defs, sim.player).hit_radius)
	var floor_dist := maxf(reach * 9.0, 280.0) * 1.8
	var seen: Array = []
	var index := 0
	for item in sim.craft:
		var pose: Dictionary = CraftOrders.escort_pose(sim, item, index)
		var at := Vector2(pose.pos)
		var dist := at.distance_to(sim.player.pos)
		check(dist > floor_dist, "%s keeps clear of the keel (%.0f)" % [item.name, dist])
		check(absf(wrapf(float(pose.rot) - sim.player.rot, -PI, PI)) > 0.15, "%s flies its own heading" % item.name)
		for other in seen:
			check(at.distance_to(other) > 120.0, "%s does not share a station" % item.name)
		seen.append(at)
		index += 1
	sim.time = 20.0
	var later: Dictionary = CraftOrders.escort_pose(sim, sim.craft[0], 0)
	check(Vector2(later.pos).distance_to(seen[0]) > 40.0, "an escort station moves on its own pattern")


func _buy_wing() -> void:
	var sim := make("vesper")
	sim.player.pos = sim.beacon_pos
	sim.player.moored = true
	sim.quest_flags.purse = DockBoard.FIGHTER_PRICE
	check(DockBoard.buy_fighter(sim) == "", "the pad sells a fighter")
	check(DockBoard.purse(sim) == 0, "a fighter spends the purse")
	check(_count(sim, "fighter") == 1, "Vesper racks the bought fighter")
	check(DockBoard.buy_fighter(sim) != "", "an empty purse cannot buy a second fighter")
	sim.quest_flags.purse = DockBoard.FIGHTER_PRICE * 3
	check(DockBoard.buy_fighter(sim) == "", "the pad sells a second fighter")
	check(CraftOrders.launch(sim, "fighter") == "", "the first fighter launches")
	var second = _craft(sim, "fighter_2")
	check(CraftOrders.order(sim, str(second.uid), "launch", "") == "", "the second fighter launches")
	for _i in 30:
		sim.tick(0.05, {})
	var lead = _craft(sim, "fighter_1")
	var wing = _craft(sim, "fighter_2")
	check(str(lead.state) == "escort" and str(wing.state) == "escort", "both fighters stay on escort")
	check(lead.pos.distance_to(wing.pos) > 80.0, "the wing flies two stations")
	check(lead.pos.distance_to(sim.player.pos) > 70.0, "a fighter follows off the hull")
	sim.player.pos += Vector2(0, 2200)
	sim.player.vel = Vector2.ZERO
	lead.pos = sim.player.pos + Vector2(-120, 180)
	wing.pos = sim.player.pos + Vector2(140, 220)
	var skiff: Dictionary = sim._blank_ship("skiff", "Red Keel", "agent:red_keel:test", "npc", "red_keel")
	skiff.pos = sim.player.pos + Vector2(0, 460)
	skiff.alive = true
	sim.actors.append(skiff)
	sim.player.lock_id = str(skiff.agent_id)
	sim.player.lock_ok = true
	check(CraftOrders.order(sim, str(lead.uid), "attack", "") == "", "the fighter takes the lock")
	check(str(lead.target) == str(skiff.agent_id), "the attack order marks the skiff")
	var fired := false
	for _i in 80:
		sim.tick(0.05, {})
		if sim.projectiles.size() > 0 or float(skiff.hp) < float(skiff.max_hp):
			fired = true
			break
	check(fired, "the fighter fires on the target")


func _scan_harvest_heat() -> void:
	var sim := make("vesper")
	check(sim.survey_node("aegis_prime") != null and sim.survey_node("aegis_ring") != null and sim.survey_node("seized_hold") != null, "the dock still has planet, ring, and seized hold")
	check(sim.survey_node("cinder_reach") != null and sim.survey_node("lease_gravel") != null, "the ore field and the gravel stream are scan nodes")
	var probe = _craft(sim, "survey_probe_1")
	check(CraftOrders.order(sim, str(probe.uid), "orbit", "aegis_prime") == "", "probe accepts an orbit order")
	for _i in 50:
		sim.tick(0.05, {})
	check(str(probe.state) == "orbiting", "probe holds orbit")
	check(not sim.dossier_complete("aegis_prime"), "orbit does not write the dossier")
	check(CraftOrders.order(sim, str(probe.uid), "scan", "aegis_prime") == "", "probe accepts a scan order")
	_seal(sim, "survey_probe_1", "aegis_prime")
	check("Helion Compact protected" in str(sim.scans.aegis_prime.layers.legal.text), "Aegis Prime legal title")
	_seal(sim, "survey_probe_1", "aegis_ring")
	check("Compact lease, limited harvest" in str(sim.scans.aegis_ring.layers.legal.text), "ice ring legal title")
	_seal(sim, "survey_probe_1", "seized_hold")
	check("Compact seized property" in str(sim.scans.seized_hold.layers.legal.text), "trash field legal title")
	var layers: Array = ["orbit", "atmosphere", "surface", "crust", "biosign", "ruins", "legal"]
	var aegis: Dictionary = sim.scans.aegis_prime.layers
	var sealed := true
	for key in layers:
		if not bool(aegis[key].known):
			sealed = false
	check(sealed, "Aegis Prime dossier has all seven layers")
	var heat0 := float(sim.heat.helion_compact)
	var mass0 := int(sim.player.cargo.get("raw_mass", 0))
	check(CraftOrders.order(sim, "harvest_drone_1", "launch", "aegis_ring") == "", "drone launches to the ice ring")
	var guard := 0
	while int(sim.player.cargo.get("raw_mass", 0)) == mass0 and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	check(int(sim.player.cargo.get("raw_mass", 0)) == mass0 + 1, "drone returns raw mass (%d)" % guard)
	check(str(_craft(sim, "harvest_drone_1").state) == "docked" or _wait_state(sim, "harvest_drone_1", "docked", 400), "drone is back in the rack")
	var lease := float(sim.heat.helion_compact) - heat0
	check(lease > 0.0 and lease <= 8.0, "small lease cut adds little heat (%.0f)" % lease)
	var heat1 := float(sim.heat.helion_compact)
	var mass1 := int(sim.player.cargo.get("raw_mass", 0))
	var seam := int(sim.deposits.get("aegis_prime", 0))
	check(CraftOrders.order(sim, "harvest_drone_1", "launch", "aegis_prime") == "", "drone launches to Aegis Prime")
	guard = 0
	while int(sim.deposits.get("aegis_prime", 0)) == seam and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	var yielded := int(sim.deposits.get("aegis_prime", 0)) == seam - 1
	var kept := int(sim.player.cargo.get("raw_mass", 0)) >= mass1
	check(yielded and (kept or sim.fined), "protected crust still yields mass")
	var illegal := float(sim.heat.helion_compact) - heat1
	check(illegal > lease, "protected harvest adds more heat than the lease (%.0f)" % illegal)
	var before_trash := float(sim.heat.helion_compact)
	check(sim.try_extract("seized_hold") == "ok", "seized hold can be cut")
	check(float(sim.heat.helion_compact) - before_trash >= 28.0, "seized property adds PDO heat")


func _seal(sim: SectorSim, uid: String, node_id: String) -> void:
	if str(_craft(sim, uid).state) != "docked":
		_wait_state(sim, uid, "docked", 900)
	check(CraftOrders.order(sim, uid, "scan", node_id) == "", "scan order for %s" % node_id)
	var guard := 0
	while not sim.dossier_complete(node_id) and guard < 900:
		var item = _craft(sim, uid)
		if str(item.state) == "lost":
			break
		sim.tick(0.05, {})
		guard += 1
	check(sim.dossier_complete(node_id), "%s dossier seals (%d)" % [node_id, guard])
	if sim.dossier_complete(node_id):
		_wait_state(sim, uid, "docked", 900)


func _loss_and_save() -> void:
	var sim := make("vesper")
	sim.player.cargo["raw_mass"] = 0
	var probe = _craft(sim, "survey_probe_2")
	probe.state = "outbound"
	probe.order = "orbit"
	probe.target = "aegis_prime"
	probe.pos = sim.planet("aegis_prime").pos
	sim.tick(0.05, {})
	check(str(probe.state) == "lost", "a probe dies in the planet")
	var other = _craft(sim, "survey_probe_1")
	check(str(other.state) == "docked", "the other probe is still aboard")
	var denied := CraftOrders.order(sim, str(probe.uid), "launch", "aegis_ring")
	check("lost" in denied.to_lower(), "a lost probe does not launch")
	var broke := CraftOrders.rebuild(sim, str(probe.uid))
	check("returned mass" in broke.to_lower(), "rebuild refuses an empty hold")
	sim._add_cargo("raw_mass", 1)
	check(CraftOrders.rebuild(sim, str(probe.uid)) == "", "rebuild spends returned mass")
	check(str(probe.state) == "docked", "rebuilt probe is in the rack")
	check(int(sim.player.cargo.get("raw_mass", 0)) == 0, "the mass was spent")
	probe.state = "lost"
	probe.hp = 0.0
	sim._add_cargo("raw_mass", 2)
	sim.heat.helion_compact = 34.0
	var data := sim.to_dict()
	var copy := SectorSim.new(defs)
	copy.from_dict(data)
	var loaded = _craft(copy, "survey_probe_2")
	check(str(loaded.state) == "lost", "reload keeps the lost probe")
	check(int(copy.player.cargo.get("raw_mass", 0)) == 2, "reload keeps the cargo")
	check(float(copy.heat.helion_compact) == 34.0, "reload keeps the heat")
	var star = _craft(copy, "survey_probe_1")
	star.state = "outbound"
	star.pos = Vector2(0, 12)
	copy.tick(0.05, {})
	check(str(star.state) == "lost", "a probe dies in the star")
	var patrol_pos := Vector2.ZERO
	for actor in copy.actors:
		if str(actor.team) == "helion_compact":
			patrol_pos = actor.pos
			break
	var drone = _craft(copy, "harvest_drone_1")
	drone.state = "outbound"
	drone.pos = patrol_pos
	copy.tick(0.05, {})
	check(str(drone.state) == "lost", "a drone dies on the patrol")


func _helm() -> void:
	var sim := make("anvil")
	var dock = sim.planet("aegis_prime")
	sim.player.rot = (sim.player.pos - dock.pos).angle()
	sim.tick(0.7, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(sim.player.vel.length() > 20.0, "helm thrust still builds speed")
	sim.tick(0.4, {"thrust": 0.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(sim.player.vel.length() > 10.0, "helm still coasts")


func _wait_state(sim: SectorSim, uid: String, state: String, limit: int) -> bool:
	var guard := 0
	while guard < limit:
		var item = _craft(sim, uid)
		if item == null:
			return false
		if str(item.state) == state:
			return true
		if str(item.state) == "lost":
			return false
		sim.tick(0.05, {})
		guard += 1
	return str(_craft(sim, uid).state) == state
