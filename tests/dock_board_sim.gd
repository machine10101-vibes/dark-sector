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
	_scan()
	_haul()
	_pad_gate()
	_save()
	_return_and_pay()
	if fails == 0:
		print("DOCKBOARD PASS")
	else:
		print("DOCKBOARD FAIL %d" % fails)
	quit(fails)


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func make() -> SectorSim:
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.hold_npc = true
	return sim


func _scan() -> void:
	var sim := make()
	check(DockBoard.at_pad(sim), "a fresh needle is on the pad")
	check(DockBoard.take(sim, "scan") == "", "scan can be taken on the pad")
	check(DockBoard.state(sim, "dock_scan") == "active", "scan is active")
	check(DockBoard.purse(sim) == 0, "taking the scan does not pay yet")
	for layer in CraftOrders.LAYERS:
		sim.reveal_layer("aegis_prime", layer)
	DockBoard.pulse(sim, 0.2)
	check(DockBoard.state(sim, "dock_scan") == "done", "a sealed dossier on the pad files the scan")
	check(DockBoard.purse(sim) == DockBoard.SCAN_PAY, "scan pay lands in the purse")
	var said := false
	for line in sim.lines:
		if "Aegis scan filed" in str(line.text) and "Purse" in str(line.text):
			said = true
	check(said, "the log names the scan pay")
	check(DockBoard.take(sim, "scan") != "", "a filed scan cannot be taken again")


func _haul() -> void:
	var sim := make()
	var ring = sim.survey_node("aegis_ring")
	check(ring != null, "the ice ring is on the board")
	check(sim.player.pos.distance_to(ring.pos) > DockBoard.RING, "the pad is not already on the ring")
	check(DockBoard.take(sim, "haul") == "", "haul can be taken on the pad")
	check(int(sim.player.cargo.get(DockBoard.CRATE, 0)) == 1, "the crate is in the hold")
	sim.player.moored = false
	sim.player.pos = ring.pos
	DockBoard.pulse(sim, 0.2)
	check(bool(sim.quest_flags.get("dock_haul_ring", false)), "the ring marks the crate")
	check(DockBoard.purse(sim) == 0, "the ring does not pay by itself")
	sim.player.pos = sim.beacon_pos
	sim.player.moored = true
	DockBoard.pulse(sim, 0.2)
	check(DockBoard.state(sim, "dock_haul") == "done", "returning the crate files the haul")
	check(int(sim.player.cargo.get(DockBoard.CRATE, 0)) == 0, "the dock takes the crate back")
	check(DockBoard.purse(sim) == DockBoard.HAUL_PAY, "haul pay lands in the purse")
	var full := make()
	full.player.cargo["raw_mass"] = 6
	check(DockBoard.take(full, "haul") != "", "a full hold refuses the crate")
	check(DockBoard.state(full, "dock_haul") == "open", "a refused haul stays on the board")


func _pad_gate() -> void:
	var sim := make()
	sim.player.moored = false
	sim.player.pos = sim.beacon_pos + Vector2(800, 0)
	check(DockBoard.at_pad(sim) == false, "clear of the pad is not the board")
	check(DockBoard.take(sim, "scan") != "", "a job cannot be taken off the pad")
	check(DockBoard.state(sim, "dock_scan") == "open", "the slip stays open off the pad")


func _return_and_pay() -> void:
	var sim := make()
	var body = sim.planet("aegis_prime")
	check(DockBoard.take(sim, "scan") == "", "scan is taken before the trip")
	var outer := ScaleFrame.band_outer(sim, body)
	sim.player.pos = body.pos + Vector2(outer - 40.0, 0.0)
	sim.player.vel = Vector2(240.0, 0.0)
	sim.player.moored = false
	sim.tick(0.6, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(int(sim.layer) == ScaleFrame.CHART, "the trip leaves the band for the chart")
	check(sim.player.vel.length() > 40.0, "the chart still keeps speed")
	var parked: Vector2 = body.chart_km + Vector2(90000.0, 40000.0)
	sim.layer = ScaleFrame.CHART
	sim.body_id = ""
	sim.local_origin = parked
	sim.player.pos = body.pos
	check(Law.at(sim, sim.player.pos) != "green", "a chart position that only matches the pad disc is not green")
	var buoy: Vector2 = sim.dock_buoy_km()
	sim.local_origin = body.chart_km
	sim.player.pos = buoy - body.chart_km
	sim.player.vel = Vector2.ZERO
	check(Law.at(sim, sim.player.pos) == "green", "the Helion Dock buoy reads green")
	sim.tick(0.05, {})
	check(bool(sim.player.moored), "touching the buoy moors from a stop, any heading")
	check(int(sim.layer) == ScaleFrame.BAND, "the buoy puts the keel on the Helion band")
	check(DockBoard.at_pad(sim), "Board is live after the buoy")
	for layer in CraftOrders.LAYERS:
		sim.reveal_layer("aegis_prime", layer)
	sim.tick(0.05, {})
	check(DockBoard.purse(sim) == DockBoard.SCAN_PAY, "a sealed dossier on the returned pad pays 80")
	check(DockBoard.take(sim, "haul") == "", "haul can be taken once the pad has the keel")
	var ring = sim.survey_node("aegis_ring")
	sim.player.moored = false
	sim.quest_flags.moor_latch = 0.0
	sim.player.pos = ring.pos
	DockBoard.pulse(sim, 0.2)
	check(bool(sim.quest_flags.get("dock_haul_ring", false)), "the ring still marks the crate off the pad")
	sim.player.pos = body.pos + Vector2(outer - 40.0, 0.0)
	sim.player.vel = Vector2(400.0, 0.0)
	sim.layer = ScaleFrame.BAND
	sim.body_id = str(body.id)
	sim.tick(0.5, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(int(sim.layer) == ScaleFrame.CHART, "the haul leaves the band again")
	sim.local_origin = body.chart_km
	sim.player.pos = Vector2(ScaleFrame.soi_km(body) - 50.0, 0.0)
	sim.player.vel = Vector2(-640.0, 0.0)
	sim.layer = ScaleFrame.CHART
	sim.body_id = ""
	sim.tick(0.05, {})
	check(int(sim.layer) == ScaleFrame.APPROACH, "flying into the well starts the dock approach")
	sim.tick(0.45, {})
	check(bool(sim.player.moored) and DockBoard.at_pad(sim), "the haul returns to a moored pad")
	check(int(sim.player.cargo.get(DockBoard.CRATE, 0)) == 0, "the dock clears the crate")
	check(DockBoard.purse(sim) == DockBoard.SCAN_PAY + DockBoard.HAUL_PAY, "the haul adds 120 on the pad")
	var held := {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false}
	sim.tick(0.2, held)
	check(bool(sim.player.moored), "a held thrust stays moored until it is released")
	sim.tick(0.1, {"thrust": 0.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	sim.tick(0.25, held)
	check(bool(sim.player.moored) == false, "a fresh thrust casts off again")
	sim.player.pos = sim.beacon_pos + Vector2(700.0, 0.0)
	sim.player.vel = Vector2.ZERO
	sim.layer = ScaleFrame.BAND
	sim.tick(0.05, {})
	check(bool(sim.player.moored) == false, "seven hundred meters of dark band is not the pad")
	sim.player.pos = sim.beacon_pos + Vector2(40.0, 30.0)
	sim.player.vel = Vector2(40.0, -10.0)
	sim.tick(0.05, {})
	check(bool(sim.player.moored) and DockBoard.at_pad(sim), "fifty meters from the buoy moors from any heading")


func _save() -> void:
	var sim := make()
	DockBoard.take(sim, "scan")
	sim.quest_flags.purse = 40
	var copy := SectorSim.new(defs)
	copy.from_dict(sim.to_dict())
	check(DockBoard.state(copy, "dock_scan") == "active", "a save keeps the open scan")
	check(DockBoard.purse(copy) == 40, "a save keeps the purse")
