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
	_probe_and_harvest()
	_mast()
	_closed_pocket()
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


func _probe_and_harvest() -> void:
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.hold_npc = true
	check(str(sim.defs.system.id) == "HC-V1-R1-S1", "survey happens in Helion Dock")
	var launched := CraftOrders.launch(sim, "survey_probe")
	check(launched == "", "probe launches")
	var guard := 0
	while not sim.dossier_complete("aegis_prime") and guard < 800:
		sim.tick(0.05, {})
		guard += 1
	check(sim.dossier_complete("aegis_prime"), "Aegis Prime dossier seals (%d)" % guard)
	check("Helion Compact Guard" in str(sim.scans["aegis_prime"].layers.legal.text), "legal layer names the Guard")
	check("Not a claim" in str(sim.scans["aegis_prime"].layers.legal.text), "the city is not a homestead")
	sim.player.pos = sim.planet("aegis_prime").pos + Vector2(420, 0)
	var before := int(sim.player.cargo.get("ring_ice", 0))
	var dropped := CraftOrders.launch(sim, "harvest_drone")
	check(dropped == "", "harvest drone drops")
	guard = 0
	while int(sim.player.cargo.get("ring_ice", 0)) == before and guard < 800:
		sim.tick(0.05, {})
		guard += 1
	check(int(sim.player.cargo.get("ring_ice", 0)) == before + 1, "ring ice comes aboard")
	check(int(sim.deposits.aegis_prime) == 3, "the ring seam depletes")


func _mast() -> void:
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	var bare := Silhouette.extent(Silhouette.parts("vesper", []))
	var result: Dictionary = sim.install("sensor_mast")
	check(bool(result.ok), "survey mast bolts")
	var mast := Silhouette.extent(Silhouette.parts("vesper", ["mast"]))
	check(mast.x > bare.x + 15.0, "mast lengthens the Needle")
	check(sim.player.modules.has("sensor_mast"), "the log can see the mast")


func _closed_pocket() -> void:
	var sim := SectorSim.new(defs)
	sim.new_game("kestrel")
	sim.hold_npc = true
	var launched := CraftOrders.launch(sim, "away_shuttle")
	check(launched == "", "shuttle launches")
	var guard := 0
	while guard < 800 and not _said(sim, "closed"):
		sim.tick(0.05, {})
		guard += 1
	check(not bool(sim.claim.surveyed), "the shuttle does not open The Unlet")
	check(_said(sim, "closed"), "the shuttle reports the mark is closed")


func _said(sim, needle: String) -> bool:
	for line in sim.lines:
		if needle in str(line.text).to_lower():
			return true
	return false
