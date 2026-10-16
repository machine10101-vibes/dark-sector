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
