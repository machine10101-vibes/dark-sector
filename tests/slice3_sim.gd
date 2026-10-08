extends SceneTree

var defs: Dictionary = {}
var fails := 0

const MODULES := ["cargo_blister", "gun_sponson", "sensor_mast", "farm_cassette", "armor_belt"]


func _init() -> void:
	defs = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": Serde.load_json("res://data/system.json"),
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
	}
	_data()
	_silhouette()
	_handling()
	_turn_thrusters()
	_armor_and_craft()
	_save()
	if fails == 0:
		print("SLICE3 PASS")
	else:
		print("SLICE3 FAIL %d" % fails)
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
	for module_id in MODULES:
		var mod: Dictionary = defs.modules[module_id]
		check(mod.has("family") and mod.has("size") and mod.has("mass"), "%s has family, size, mass" % module_id)
		check(mod.has("power") and mod.has("crew") and mod.has("attach") and mod.has("footprint"), "%s has power, crew, attach, footprint" % module_id)
		check(mod.layer.size() > 0, "%s has a polygon layer" % module_id)
	check(str(defs.modules.sensor_mast.favored) == "vesper", "mast is Vesper-favored")
	check(str(defs.modules.farm_cassette.favored) == "anvil", "farm cassette is Anvil-favored")
	check(str(defs.modules.armor_belt.favored) == "kestrel", "armor belt is Kestrel-favored")
	check(str(defs.modules.cargo_blister.favored) == "", "cargo blister fits every keel")
	check(str(defs.modules.gun_sponson.favored) == "", "cheek gun fits every keel")


func _silhouette() -> void:
	var favored := {"vesper": "sensor_mast", "anvil": "cargo_blister", "kestrel": "armor_belt"}
	for class_id in ["vesper", "anvil", "kestrel"]:
		var bare: Dictionary = Silhouette.parts(class_id, [])
		var bare_ext: Vector2 = Silhouette.extent(bare)
		for module_id in MODULES:
			var layers: Array = Silhouette.layers_of(defs, [module_id])
			var worn: Dictionary = Silhouette.parts(class_id, [], layers)
			var worn_ext: Vector2 = Silhouette.extent(worn)
			check(worn.hull.size() == bare.hull.size(), "%s hull planform stays under %s" % [class_id, module_id])
			check(worn_ext.x > bare_ext.x + 0.5 or worn_ext.y > bare_ext.y + 0.5, "%s %s changes the top-down extent" % [class_id, module_id])
		var pick: Array = Silhouette.layers_of(defs, [str(favored[class_id])])
		var marked: Dictionary = Silhouette.parts(class_id, [], pick)
		check(marked.extras.size() > 0, "%s favored module draws on the hull" % class_id)
	var needle: Vector2 = Silhouette.extent(Silhouette.parts("vesper", [], Silhouette.layers_of(defs, ["sensor_mast"])))
	var barn: Vector2 = Silhouette.extent(Silhouette.parts("anvil", [], Silhouette.layers_of(defs, ["cargo_blister"])))
	var beak: Vector2 = Silhouette.extent(Silhouette.parts("kestrel", [], Silhouette.layers_of(defs, ["armor_belt"])))
	check(needle.x > barn.x and barn.y > needle.y * 0.5, "mast Needle stays long, blister Barn stays wide")
	check(absf(beak.y - needle.y) > 4.0, "belted Beak is not the Needle")


func _handling() -> void:
	var sim := make("vesper")
	var stock := Fit.stats(defs, sim.player)
	var stock_speed := _thrust_speed(sim)
	var stock_yaw := _yaw_travel(sim)
	var racks := sim.craft.size()
	for module_id in MODULES:
		var result: Dictionary = sim.install(module_id)
		check(bool(result.ok), "Vesper bolts %s" % module_id)
	check(sim.craft.size() == racks, "modules do not delete the hangar")
	var heavy := Fit.stats(defs, sim.player)
	check(heavy.mass > stock.mass + 40.0, "the full layout is heavier")
	check(heavy.accel < stock.accel * 0.7, "heavy accel is worse")
	check(heavy.turn < stock.turn * 0.7, "heavy turn is worse")
	check(heavy.ttw < stock.ttw * 0.7, "thrust-to-weight falls")
	check(heavy.power_spare < 0.0, "overload is allowed on the reactor")
	check(bool(heavy.crew_over), "overload is allowed on the crew budget")
	check(heavy.com.length() > 1.0, "center of mass leaves the spine")
	var heavy_speed := _thrust_speed(sim)
	var heavy_yaw := _yaw_travel(sim)
	check(heavy_speed < stock_speed * 0.75, "the heavy keel builds less speed (%.0f vs %.0f)" % [heavy_speed, stock_speed])
	check(heavy_yaw < stock_yaw * 0.8, "the heavy keel yaws less (%.2f vs %.2f)" % [heavy_yaw, stock_yaw])
	sim.pdo_alert = true
	var blocked: Dictionary = sim.uninstall("cargo_blister")
	check(not bool(blocked.ok), "the bay stays shut in a fight")
	check(sim.player.modules.has("cargo_blister"), "a shut bay does not pull the blister")
	sim.pdo_alert = false
	for module_id in MODULES:
		var pulled: Dictionary = sim.uninstall(module_id)
		check(bool(pulled.ok), "Vesper pulls %s" % module_id)
	var restored := Fit.stats(defs, sim.player)
	check(absf(restored.mass - stock.mass) < 0.1, "pulling the parts restores the mass")
	check(absf(restored.turn - stock.turn) < 0.02, "pulling the parts restores the turn")
	var bare: Vector2 = Silhouette.extent(Silhouette.parts("vesper", []))
	var again: Vector2 = Silhouette.extent(Silhouette.parts("vesper", [], Silhouette.layers_of(defs, sim.player.modules)))
	check(absf(again.x - bare.x) < 0.1 and absf(again.y - bare.y) < 0.1, "pulling the parts restores the silhouette")
	var back_speed := _thrust_speed(sim)
	check(absf(back_speed - stock_speed) < 2.0, "pulling the parts restores the drift")


func _turn_thrusters() -> void:
	for class_id in ["vesper", "anvil", "kestrel", "lumen", "casque", "alidade"]:
		var sim := make(class_id)
		var bare: Dictionary = Fit.stats(defs, sim.player)
		var bare_rest := _yaw_over(sim, 0.4, 0.0)
		var bare_fast := _yaw_over(sim, 0.35, 260.0)
		check(sim.install("turn_thrusters").ok, "%s bolts the turn thrusters" % class_id)
		var worn: Dictionary = Fit.stats(defs, sim.player)
		check(float(worn.turn) > float(bare.turn) * 1.15, "%s yaws harder with the thrusters (%.2f vs %.2f)" % [class_id, worn.turn, bare.turn])
		var worn_rest := _yaw_over(sim, 0.4, 0.0)
		var worn_fast := _yaw_over(sim, 0.35, 260.0)
		check(worn_rest > bare_rest * 1.12, "%s turns farther at rest (%.2f vs %.2f)" % [class_id, worn_rest, bare_rest])
		check(worn_fast > bare_fast * 1.25, "%s holds a sharper turn at speed (%.2f vs %.2f)" % [class_id, worn_fast, bare_fast])
		check(float(worn.turn_grip) > 0.5, "%s keeps the nose through a fast turn" % class_id)


func _yaw_over(sim: SectorSim, dt: float, speed: float) -> float:
	sim.player.moored = false
	sim.player.rot = 0.0
	sim.player.vel = Vector2(speed, 0.0)
	sim.tick(dt, {"thrust": 0.0, "retro": 0.0, "rot": 1.0, "strafe": 0.0, "fire": false})
	return absf(sim.player.rot)


func _armor_and_craft() -> void:
	var sim := make("kestrel")
	var dmg := float(Fit.stats(defs, sim.player).gun.damage)
	sim.player.hp = 80.0
	sim.player.shield = 0.0
	sim.player.armor_hp = 0.0
	sim.damage_unit(sim.player, dmg, "starter")
	var bare_loss := 80.0 - float(sim.player.hp)
	check(sim.install("armor_belt").ok, "Beak wears the armor belt")
	sim.player.hp = 80.0
	sim.player.shield = 0.0
	sim.player.armor_hp = 0.0
	sim.damage_unit(sim.player, dmg, "starter")
	var belted_loss := 80.0 - float(sim.player.hp)
	check(belted_loss < bare_loss - 0.5, "the belt takes less from the starter gun (%.1f vs %.1f)" % [belted_loss, bare_loss])
	var anvil := make("anvil")
	check(anvil.install("farm_cassette").ok, "Barn wears the farm cassette")
	check(anvil.install("cargo_blister").ok, "Barn wears the cargo blister")
	var probe := ""
	for item in anvil.craft:
		if str(item.def_id) == "survey_probe":
			probe = str(item.uid)
	check(probe != "", "the probe is still racked after the bolts")
	check(CraftOrders.order(anvil, probe, "scan", "aegis_prime") == "", "probe still accepts a scan")
	var guard := 0
	while not anvil.dossier_complete("aegis_prime") and guard < 900:
		anvil.tick(0.05, {})
		guard += 1
	check(anvil.dossier_complete("aegis_prime"), "probe still seals Aegis Prime (%d)" % guard)
	var drone := ""
	for item in anvil.craft:
		if str(item.def_id) == "harvest_drone":
			drone = str(item.uid)
	anvil.player.pos = anvil.survey_node("aegis_ring").pos + Vector2(180, 40)
	check(CraftOrders.order(anvil, "survey_probe_1", "scan", "aegis_ring") == "" or anvil.dossier_complete("aegis_ring"), "ring scan can be ordered")
	guard = 0
	while not anvil.dossier_complete("aegis_ring") and guard < 900:
		anvil.tick(0.05, {})
		guard += 1
	check(anvil.dossier_complete("aegis_ring"), "probe still seals the ice ring")
	var before := int(anvil.player.cargo.get("raw_mass", 0))
	check(CraftOrders.order(anvil, drone, "launch", "aegis_ring") == "", "drone still launches")
	guard = 0
	while int(anvil.player.cargo.get("raw_mass", 0)) == before and guard < 900:
		anvil.tick(0.05, {})
		guard += 1
	check(int(anvil.player.cargo.get("raw_mass", 0)) == before + 1, "drone still returns raw mass")


func _save() -> void:
	var sim := make("vesper")
	check(sim.install("cargo_blister").ok, "blister bolts before the log")
	check(sim.install("sensor_mast").ok, "mast bolts before the log")
	sim.player.cargo["raw_mass"] = 3
	sim.heat.helion_compact = 14.0
	var probe = sim.craft[0]
	probe.state = "lost"
	probe.hp = 0.0
	var worn: Vector2 = Silhouette.extent(Silhouette.parts("vesper", [], Silhouette.layers_of(defs, sim.player.modules)))
	var data := sim.to_dict()
	var copy := SectorSim.new(defs)
	copy.from_dict(data)
	check(copy.player.modules.has("cargo_blister") and copy.player.modules.has("sensor_mast"), "reload keeps the bolted parts")
	var again: Vector2 = Silhouette.extent(Silhouette.parts("vesper", [], Silhouette.layers_of(defs, copy.player.modules)))
	check(absf(again.x - worn.x) < 0.1 and absf(again.y - worn.y) < 0.1, "reload keeps the silhouette")
	var stats := Fit.stats(defs, copy.player)
	check(stats.cargo_cap > int(defs.ships.vesper.cargo), "reload keeps the hold bonus")
	check(stats.sensor > float(defs.ships.vesper.sensor), "reload keeps the mast sensor")
	check(int(copy.player.cargo.get("raw_mass", 0)) == 3, "reload keeps the cargo")
	check(float(copy.heat.helion_compact) == 14.0, "reload keeps the heat")
	check(str(copy.craft[0].state) == "lost", "reload keeps the lost craft")


func _thrust_speed(sim: SectorSim) -> float:
	sim.player.pos = Vector2(4200, 2600)
	sim.player.vel = Vector2.ZERO
	sim.player.rot = 0.0
	sim.tick(0.6, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	return sim.player.vel.length()


func _yaw_travel(sim: SectorSim) -> float:
	sim.player.rot = 0.0
	sim.tick(0.45, {"thrust": 0.0, "retro": 0.0, "rot": 1.0, "strafe": 0.0, "fire": false})
	return absf(sim.player.rot)
