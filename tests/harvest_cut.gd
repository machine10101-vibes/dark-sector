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
	_probe()
	_marked()
	_plasma()
	_grt()
	if fails == 0:
		print("HARVEST CUT PASS")
	else:
		print("HARVEST CUT FAIL %d" % fails)
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


func _craft(sim: SectorSim, def_id: String):
	for item in sim.craft:
		if str(item.def_id) == def_id:
			return item
	return null


func _probe() -> void:
	var sim := make("kestrel")
	check(_craft(sim, "harvest_drone") == null, "the Beak racks no harvest drone")
	check(_craft(sim, "survey_probe") != null, "the Beak racks a survey probe")
	var ice = sim.survey_node("ice_spall")
	check(ice != null and int(sim.deposits.get("ice_spall", 0)) > 0, "ice spall is a live seam")
	if ice == null:
		return
	sim.player.moored = false
	sim.player.pos = ice.pos + Vector2(40, 0)
	var held := int(sim.player.cargo.get("ice_spall", 0))
	var left := int(sim.deposits.ice_spall)
	var note := HelmHarvest.send_craft(sim, "ice_spall")
	check(note == "", "a probe takes the harvest order")
	var probe = _craft(sim, "survey_probe")
	check(probe != null and str(probe.order) == "cut", "the probe order is cut")
	var guard := 0
	while int(sim.player.cargo.get("ice_spall", 0)) == held and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	check(int(sim.player.cargo.get("ice_spall", 0)) == held + 1, "the probe brings ice aboard (%d)" % guard)
	check(int(sim.deposits.ice_spall) == left - 1, "the ice seam loses one crate")
	check(sim.cuts.size() > 0 or guard > 0, "the cut leaves a harvest beam")


func _marked() -> void:
	var ice_home := make("kestrel")
	var ice = ice_home.survey_node("ice_spall")
	var slag = ice_home.survey_node("copper_slag")
	check(ice != null and slag != null, "ice and copper are on the board")
	if ice == null or slag == null:
		return
	ice_home.player.moored = false
	ice_home.player.pos = ice.pos + Vector2(30, 0)
	HelmHarvest.mark(ice_home, "copper_slag")
	check(HelmHarvest.marked(ice_home) != null and str(HelmHarvest.marked(ice_home).id) == "copper_slag", "the helm keeps the selected seam")
	check(HelmHarvest.send_craft(ice_home) == "", "Harvest sends the probe to the mark")
	var probe = _craft(ice_home, "survey_probe")
	check(probe != null and str(probe.target) == "copper_slag", "the probe flies to the selected copper")
	var near := make("kestrel")
	near.player.moored = false
	near.player.pos = ice.pos + Vector2(30, 0)
	check(HelmHarvest.send_craft(near) == "", "unmarked Harvest still finds a seam")
	var near_probe = _craft(near, "survey_probe")
	check(near_probe != null and str(near_probe.target) == "ice_spall", "unmarked Harvest takes the nearest seam")
	var aimed := make("kestrel")
	aimed.player.moored = false
	aimed.player.pos = ice.pos + Vector2(30, 0)
	aimed.player.order = {"kind": "approach", "x": slag.pos.x, "y": slag.pos.y, "label": str(slag.name)}
	check(HelmHarvest.send_craft(aimed) == "", "an approach mark sends the probe")
	var aimed_probe = _craft(aimed, "survey_probe")
	check(aimed_probe != null and str(aimed_probe.target) == "copper_slag", "the probe follows the approached seam")
	var ves := make("vesper")
	ves.player.moored = false
	ves.player.pos = ice.pos + Vector2(30, 0)
	HelmHarvest.mark(ves, "copper_slag")
	check(HelmHarvest.send_craft(ves) == "", "a harvest drone takes the selected seam")
	var drone = _craft(ves, "harvest_drone")
	check(drone != null and str(drone.target) == "copper_slag", "the drone flies to the selected copper")
	var scan_home := make("kestrel")
	scan_home.player.moored = false
	scan_home.player.pos = ice.pos + Vector2(30, 0)
	HelmHarvest.mark(scan_home, "copper_slag")
	check(CraftOrders.launch(scan_home, "survey_probe") == "", "Probe launches onto the selected seam")
	var scan_probe = _craft(scan_home, "survey_probe")
	check(scan_probe != null and str(scan_probe.target) == "copper_slag", "Probe and KEY_1 scan the mark")
	check(str(scan_probe.order) == "scan", "a marked Probe order is a scan")
	var aimed_scan := make("kestrel")
	aimed_scan.player.moored = false
	aimed_scan.player.pos = ice.pos + Vector2(30, 0)
	aimed_scan.player.order = {"kind": "approach", "x": slag.pos.x, "y": slag.pos.y, "label": str(slag.name)}
	check(CraftOrders.launch(aimed_scan, "survey_probe") == "", "an approach-only mark still launches Probe")
	var aimed_scan_probe = _craft(aimed_scan, "survey_probe")
	check(aimed_scan_probe != null and str(aimed_scan_probe.target) != "copper_slag", "Probe ignores an approach-only seam")
	var drone_home := make("vesper")
	drone_home.player.moored = false
	drone_home.player.pos = ice.pos + Vector2(30, 0)
	HelmHarvest.mark(drone_home, "copper_slag")
	check(CraftOrders.launch(drone_home, "harvest_drone") == "", "a drone launch takes the mark")
	var launched = _craft(drone_home, "harvest_drone")
	check(launched != null and str(launched.target) == "copper_slag", "the launched drone flies to the selected copper")


func _plasma() -> void:
	var sim := make("kestrel")
	var slag = sim.survey_node("copper_slag")
	check(slag != null, "copper slag is on the board")
	if slag == null:
		return
	sim.player.moored = false
	sim.player.pos = slag.pos + Vector2(2000, 0)
	var far := HelmHarvest.try_cut(sim, sim.player, "copper_slag")
	check(far != "", "plasma refuses a far seam")
	check(sim.cut_job.is_empty(), "a refused cut does not arm the torch")
	sim.player.pos = slag.pos + Vector2(40, 0)
	var held := int(sim.player.cargo.get("copper_slag", 0))
	var left := int(sim.deposits.copper_slag)
	check(HelmHarvest.try_cut(sim, sim.player, "copper_slag") == "", "plasma takes a close seam")
	check(not sim.cut_job.is_empty(), "the plasma job is live")
	var guard := 0
	while int(sim.player.cargo.get("copper_slag", 0)) == held and guard < 200:
		sim.tick(0.05, {})
		guard += 1
	check(int(sim.player.cargo.get("copper_slag", 0)) == held + 1, "the plasma cutter loads copper (%d)" % guard)
	check(int(sim.deposits.copper_slag) == left - 1, "the copper seam loses one crate")
	check(sim.cut_job.is_empty(), "the torch clears after the cut")
	var next = sim.survey_node("copper_slag")
	if next != null:
		sim.player.pos = next.pos + Vector2(24, 0)
	check(HelmHarvest.try_cut(sim, sim.player, "copper_slag") == "", "plasma can cut the reseated seam")
	sim.tick(0.05, {})
	check(sim.cuts.size() > 0, "the plasma beam is on the glass")


func _grt() -> void:
	var sim := make("vesper")
	check(DockBoard.at_pad(sim), "a fresh Needle is on the pad")
	check(DockBoard.purse(sim) == 0, "a fresh purse is empty GRT")
	var off := "The Helion market stands on the pad."
	sim.player.moored = false
	sim.player.pos = sim.beacon_pos + Vector2(900, 0)
	sim.player.cargo["nickel_cinder"] = 2
	check(DockBoard.sell_stock(sim, "nickel_cinder") == off, "an off-pad sell refuses")
	check(int(sim.player.cargo.nickel_cinder) == 2, "an off-pad sell leaves the nickel")
	sim.player.moored = true
	sim.player.pos = sim.beacon_pos
	check(DockBoard.sell_stock(sim, "nickel_cinder") == "", "the pad buys nickel")
	check(int(sim.player.cargo.nickel_cinder) == 1, "sell spends one nickel")
	check(DockBoard.purse(sim) == HelmHarvest.stock_price("nickel_cinder"), "nickel pays GRT")
	check(DockBoard.sell_stock(sim, "ice_spall").begins_with("No "), "empty ice does not sell")
	sim.player.cargo["ice_spall"] = 1
	var purse := DockBoard.purse(sim)
	check(DockBoard.sell_stock(sim, "ice_spall") == "", "the pad buys ice")
	check(DockBoard.purse(sim) == purse + HelmHarvest.stock_price("ice_spall"), "ice adds GRT")
	var copy := SectorSim.new(defs)
	copy.from_dict(sim.to_dict())
	check(DockBoard.purse(copy) == DockBoard.purse(sim), "a save keeps the GRT")
