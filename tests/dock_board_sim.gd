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


func _save() -> void:
	var sim := make()
	DockBoard.take(sim, "scan")
	sim.quest_flags.purse = 40
	var copy := SectorSim.new(defs)
	copy.from_dict(sim.to_dict())
	check(DockBoard.state(copy, "dock_scan") == "active", "a save keeps the open scan")
	check(DockBoard.purse(copy) == 40, "a save keeps the purse")
