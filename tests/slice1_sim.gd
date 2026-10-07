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
		"claim": Serde.load_json("res://data/claim.json"),
		"harvest": Serde.load_json("res://data/harvest.json"),
	}
	_geometry()
	_keels()
	_vesper_loop()
	_anvil_salvage()
	_kestrel_shuttle()
	_rules()
	if fails == 0:
		print("SLICE1 PASS")
	else:
		print("SLICE1 FAIL %d" % fails)
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


func _geometry() -> void:
	var bare := Silhouette.extent(Silhouette.parts("vesper", []))
	var mast := Silhouette.extent(Silhouette.parts("vesper", ["mast"]))
	check(mast.x > bare.x + 15.0, "survey mast lengthens the Needle")
	var barn := Silhouette.extent(Silhouette.parts("anvil", []))
	var blister := Silhouette.extent(Silhouette.parts("anvil", ["blister"]))
	check(blister.y > barn.y + 8.0, "cargo blister widens the Barn")
	var beak := Silhouette.extent(Silhouette.parts("kestrel", []))
	var sponson := Silhouette.extent(Silhouette.parts("kestrel", ["sponson"]))
	check(sponson.y > beak.y + 6.0, "sponson widens the Beak")


func _keels() -> void:
	var vesper := Fit.stats(defs, {"class_id": "vesper", "modules": []})
	var anvil := Fit.stats(defs, {"class_id": "anvil", "modules": []})
	var kestrel := Fit.stats(defs, {"class_id": "kestrel", "modules": []})
	check(vesper.accel > kestrel.accel and kestrel.accel > anvil.accel, "starters diverge in accel")
	check(vesper.signature_word == "quiet", "Needle launches quiet")
	check(anvil.cargo_cap > vesper.cargo_cap, "Barn holds more")
	var sim := make("vesper")
	check(sim.zone_at(sim.player.pos) == "pocket", "keel starts in Hollow Latch")
	check(sim.zone_at(sim.planet("vellum").pos) == "green", "Vellum is the green lane")
	check(sim.zone_at(sim.nest_pos) == "amber", "Red Keel nest is amber")
	check(sim.zone_at(sim.planet("cinder").pos) == "dark", "Cinder itself is unpatrolled dark")
	check(_count(sim, "survey_probe") == 2, "Needle carries two probes")
	check(_count(sim, "harvest_drone") == 1, "Needle carries a harvester")
	check(sim.player.controller == "human", "captain is a human-schema agent")
	check(str(sim.player.crew[0].name) == "Ilya Voss", "crew is aboard")
	var anvil_sim := make("anvil")
	check(_count(anvil_sim, "salvage_tender") == 1, "Barn carries a tender")
	var beak := make("kestrel")
	check(_count(beak, "fighter") == 1 and _count(beak, "away_shuttle") == 1, "Beak carries fighter and shuttle")
	check(CraftOrders.launch(beak, "harvest_drone") != "", "Beak has no harvester")


func _vesper_loop() -> void:
	var sim := make("vesper")
	var facing := Vector2.from_angle(sim.player.rot)
	sim.tick(0.45, {"thrust": 1.0})
	var speed: float = sim.player.vel.length()
	check(speed > 30.0, "thrust builds speed")
	check(sim.player.vel.normalized().dot(facing) > 0.85, "thrust follows facing")
	var coast: Vector2 = sim.player.vel
	sim.tick(0.45, {})
	check(sim.player.vel.length() > speed * 0.75, "keel coasts when thrust stops")
	sim.tick(0.4, {"rot": 1.0})
	check(absf(wrapf(sim.player.rot - facing.angle(), -PI, PI)) > 0.3, "yaw is independent of velocity")
	check(sim.player.vel.normalized().dot(coast.normalized()) > 0.7, "inertia keeps the vector")
	sim.player.pos = sim.planet("cinder").pos + Vector2(260, 40)
	sim.player.vel = Vector2.ZERO
	var launched := CraftOrders.launch(sim, "survey_probe")
	check(launched == "", "probe launches")
	var guard := 0
	while not sim.dossier_complete("cinder") and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	check(sim.dossier_complete("cinder"), "Cinder dossier seals (%d)" % guard)
	check("Unclaimed" in str(sim.scans["cinder"].layers.legal.text), "legal layer is real text")
	guard = 0
	while not _all_docked(sim, "survey_probe") and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	check(_all_docked(sim, "survey_probe"), "probe returns to the rack")
	var before := int(sim.player.cargo.get("cinder_ore", 0))
	check(CraftOrders.launch(sim, "harvest_drone") == "", "harvester launches")
	guard = 0
	while int(sim.player.cargo.get("cinder_ore", 0)) == before and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	check(int(sim.player.cargo.get("cinder_ore", 0)) == before + 1, "Cinder-ore comes home")
	check(int(sim.deposits.cinder) == 3, "seam depletes")
	var yaw_before: float = Fit.stats(defs, sim.player).yaw_deg
	var installed := sim.install("sensor_mast")
	check(bool(installed.ok), "mast bolts on")
	check(sim.player.modules.has("sensor_mast"), "layout records the mast")
	check(Fit.stats(defs, sim.player).yaw_deg < yaw_before, "mast makes yaw heavier")
	check(sim.player.yard.is_empty(), "yard spent the part")
	var rejected := sim.install("sensor_mast")
	check(not bool(rejected.ok), "a second mast is refused")
	sim.defs.modules["too_hot"] = {
		"id": "too_hot",
		"name": "Overdraw",
		"slot": "S",
		"shape": "sponson",
		"effects": {"power_draw": 99, "mass": 1},
	}
	sim.player.yard.append("too_hot")
	var hot := sim.install("too_hot")
	check(not bool(hot.ok), "reactor spare blocks a hungry part")
	check(not sim.player.modules.has("too_hot"), "rejected part stays off the keel")
	var heat_before := float(sim.heat.vellum_compact)
	sim.player.fire_cd = 0.0
	sim.tick(0.05, {"fire": true})
	check(is_equal_approx(float(sim.heat.vellum_compact), heat_before), "shots in the Latch are not green-lane crimes")
	_roundtrip(sim)


func _anvil_salvage() -> void:
	var sim := make("anvil")
	var before_cap: int = Fit.stats(defs, sim.player).cargo_cap
	var installed := sim.install("cargo_blister")
	check(bool(installed.ok), "blister bolts on")
	check(Fit.stats(defs, sim.player).cargo_cap > before_cap, "blister adds hold")
	check(Fit.stats(defs, sim.player).keel_warn, "blister makes the keel complain")
	var pirate: Dictionary = _pirate(sim)
	var hp: float = float(pirate.hp)
	sim.damage_unit(pirate, 5.0, sim.player.agent_id)
	check(is_equal_approx(float(pirate.hp), hp - 5.0), "pirate uses the same HP path")
	sim.damage_unit(sim.player, 5.0, pirate.agent_id)
	check(float(sim.player.hp) < float(sim.player.max_hp), "captain uses the same HP path")
	pirate.hp = 1
	sim.damage_unit(pirate, 8.0, sim.player.agent_id)
	check(not bool(pirate.alive), "pirate becomes a wreck")
	check(sim.wrecks.size() == 1, "wreck remains in the sector")
	check(str(sim.wrecks[0].controller) == "npc", "wreck keeps controller")
	check(str(sim.wrecks[0].agent_id).begins_with("agent:red_keel"), "wreck keeps agent id")
	check(sim.memory.red_keel.has("killed_a_skiff"), "Red Keel remembers")
	sim.player.pos = sim.wrecks[0].pos + Vector2(70, 0)
	check(CraftOrders.launch(sim, "salvage_tender") == "", "tender launches")
	var guard := 0
	while int(sim.player.cargo.get("salvage_parts", 0)) < 1 and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	check(int(sim.player.cargo.get("salvage_parts", 0)) >= 1, "tender brings salvage")
	check(bool(sim.wrecks[0].stripped), "wreck rights are spent once")


func _kestrel_shuttle() -> void:
	var sim := make("kestrel")
	var gun_before := float(Fit.stats(defs, sim.player).gun.damage)
	check(bool(sim.install("gun_sponson").ok), "sponson bolts on")
	check(float(Fit.stats(defs, sim.player).gun.damage) > gun_before, "sponson adds gun")
	check(CraftOrders.launch(sim, "away_shuttle") == "", "shuttle launches")
	var guard := 0
	while not bool(sim.quest_flags.get("hollow_latch_surveyed", false)) and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	check(bool(sim.claim.surveyed), "shuttle walks Hollow Latch")
	check(bool(sim.quest_flags.get("hollow_latch_surveyed", false)), "walk writes a quest flag")
	check(CraftOrders.launch(sim, "fighter") == "", "fighter launches")
	var fighter_pos: Vector2 = _craft(sim, "fighter").pos
	for _i in 40:
		sim.tick(0.05, {})
	check(_craft(sim, "fighter").pos.distance_to(sim.player.pos) > 40.0, "fighter leaves the throat")
	check(_craft(sim, "fighter").pos.distance_to(fighter_pos) > 20.0, "fighter actually moves")


func _rules() -> void:
	var sim := make("vesper")
	sim.player.pos = sim.planet("vellum").pos + Vector2(420, 0)
	sim.player.vel = Vector2.ZERO
	sim.player.fire_cd = 0.0
	check(sim.zone_at(sim.player.pos) == "green", "test shot is inside the green lane")
	sim.tick(0.05, {"fire": true})
	check(float(sim.heat.vellum_compact) >= 8.0, "green-lane gunfire writes Compact heat")
	check(sim.memory.vellum_compact.has("fired_in_green_lane"), "Compact memory records the shot")
	check(sim.pdo_alert, "patrol is alerted")
	for layer in ["orbit", "atmosphere", "surface", "crust", "biosign", "ruins", "legal"]:
		sim.reveal_layer("vellum", layer)
	sim.player.pos = sim.planet("vellum").pos + Vector2(280, 0)
	check(CraftOrders.launch(sim, "harvest_drone") == "", "harvester can still cut a protected crust")
	var guard := 0
	var heat_before := float(sim.heat.vellum_compact)
	while float(sim.heat.vellum_compact) < heat_before + 20.0 and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	check(sim.memory.vellum_compact.has("harvested_protected"), "protected extract writes heat")
	check(int(sim.player.cargo.get("vellum_rime", 0)) == 1, "rime still comes aboard")
	sim.player.pos = Vector2(0, 980)
	sim.player.rot = 0.0
	sim.player.vel = Vector2.ZERO
	var pirate: Dictionary = _pirate(sim)
	pirate.hp = 400.0
	pirate.max_hp = 400
	pirate.pos = sim.player.pos + Vector2(110, 0)
	pirate.vel = Vector2.ZERO
	for _i in 20:
		sim.tick(0.05, {"fire": true})
	check(float(pirate.hp) < 400.0, "fixed gun reaches a Red Keel skiff")
	sim.hold_npc = false
	var home: Vector2 = pirate.pos
	for _i in 80:
		sim.tick(0.05, {})
	check(pirate.alive, "skiff still in the fight")
	check(pirate.pos.distance_to(home) > 15.0 or pirate.thrusting, "skiff pilots itself")


func _roundtrip(sim: SectorSim) -> void:
	var path := "user://slice1_test_save.json"
	var raw := sim.to_dict()
	raw["camera_zoom"] = 0.42
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw, "\t"))
	file.close()
	var loaded = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	var copy := SectorSim.new(defs)
	copy.from_dict(loaded)
	check(int(copy.seed_value) == int(sim.seed_value), "galaxy seed survives")
	check(copy.player.modules.has("sensor_mast"), "module layout survives")
	check(int(copy.player.cargo.get("cinder_ore", 0)) == 1, "cargo survives")
	check(str(copy.player.crew[0].name) == "Ilya Voss", "crew survives")
	check(copy.dossier_complete("cinder"), "dossier survives")
	check(str(copy.quest_flags.get("origin_vesper", "")) == "dormant", "quest flag survives")
	check(str(copy.claim.pocket_id) == "hollow_latch", "claim slate survives")
	check(copy.player.pos.distance_to(sim.player.pos) < 1.0, "position survives")
	check(_count(copy, "survey_probe") == 2, "craft survive")


func _count(sim: SectorSim, def_id: String) -> int:
	var n := 0
	for item in sim.craft:
		if str(item.def_id) == def_id:
			n += 1
	return n


func _all_docked(sim: SectorSim, def_id: String) -> bool:
	var seen := 0
	for item in sim.craft:
		if str(item.def_id) != def_id:
			continue
		seen += 1
		if str(item.state) != "docked":
			return false
	return seen > 0


func _craft(sim: SectorSim, def_id: String) -> Dictionary:
	for item in sim.craft:
		if str(item.def_id) == def_id:
			return item
	return {}


func _pirate(sim: SectorSim) -> Dictionary:
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			return actor
	for actor in sim.actors:
		if str(actor.team) == "red_keel":
			return actor
	return {}
