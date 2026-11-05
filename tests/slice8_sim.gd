extends SceneTree

var defs: Dictionary = {}
var fails := 0

const WANTED := [
	"HC-V1-R1-S2", "HC-V1-R1-S3", "HC-V1-R1-S4", "HC-V1-R1-S5", "HC-V1-R1-S6",
	"HC-V1-R2-S1", "HC-V1-R2-S2", "HC-V1-R2-S3",
	"HC-V1-R5-S2", "HC-V1-R5-S4", "HC-V1-R5-S6",
	"HC-V1-R6-S1",
]
const MUST_MODULES := [
	"keel_stretch", "extra_hold", "radiator_fans", "battery_pack",
	"heavy_turret", "missile_rack", "point_defense",
	"probe_rack", "fighter_rack", "lighter_dock",
	"hydro_stack", "seed_vault", "greenhouse_ring",
	"claim_beacon", "perimeter_stakes",
]


func _init() -> void:
	var helion: Dictionary = Serde.load_json("res://data/system.json")
	var soil: Dictionary = Serde.load_json("res://data/first_soil.json")
	var chart := {
		str(helion.id): helion,
		str(soil.id): soil,
	}
	var density: Dictionary = Serde.load_json("res://data/density.json")
	for spec in density.get("systems", []):
		var built: Dictionary = Chart.expand(spec)
		chart[str(built.id)] = built
	defs = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": helion,
		"systems": chart,
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
	}
	_catalog()
	_chart()
	_spine()
	_life()
	_craft()
	_contracts()
	_shorts()
	_save()
	_contest()
	if fails == 0:
		print("SLICE8 PASS")
	else:
		print("SLICE8 FAIL %d" % fails)
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


func ride(sim: SectorSim, gate_id: String) -> String:
	for row in sim.gates:
		var gate: Dictionary = row
		if str(gate.get("id", "")) == gate_id:
			sim.player.pos = gate.pos
			return sim.try_lane()
	return "missing gate"


func _catalog() -> void:
	var count := int(defs.modules.size())
	check(count >= 25 and count <= 40, "the module catalog is in the density band")
	for module_id in MUST_MODULES:
		check(defs.modules.has(module_id), "%s is in the catalog" % module_id)
		var layer: Array = defs.modules[module_id].get("layer", [])
		check(layer.size() > 0, "%s changes the silhouette" % module_id)
	var slim := make("vesper")
	var wide := make("vesper")
	check(slim.install("keel_stretch").ok, "a keel stretch bolts")
	check(wide.install("greenhouse_ring").ok, "a greenhouse ring bolts")
	var slim_geom := Silhouette.parts("vesper", Silhouette.shapes_of(defs, slim.player.modules), Silhouette.layers_of(defs, slim.player.modules))
	var wide_geom := Silhouette.parts("vesper", Silhouette.shapes_of(defs, wide.player.modules), Silhouette.layers_of(defs, wide.player.modules))
	check(Silhouette.extent(slim_geom) != Silhouette.extent(wide_geom), "two fits on the same starter do not share an outline")
	var pig := make("vesper")
	var bare: Dictionary = Fit.stats(defs, pig.player)
	check(pig.install("keel_stretch").ok and pig.install("extra_hold").ok, "the pig takes keel and hold")
	check(pig.install("missile_rack").ok and pig.install("heavy_turret").ok, "the pig takes rack and turret")
	var fat: Dictionary = Fit.stats(defs, pig.player)
	check(float(fat.power_spare) < 0.0, "the pig overloads the reactor")
	check(float(fat.yaw_deg) < float(bare.yaw_deg), "the pig yaws worse than the bare keel")
	check(bool(fat.keel_warn), "the keel complains about the pig")


func _chart() -> void:
	var compositions: Array = []
	var origins: Array = []
	for system_id in WANTED:
		check(defs.systems.has(system_id), "%s is on the board" % system_id)
		var sim := make("vesper")
		sim._arrive(system_id, "")
		var system: Dictionary = sim.defs.system
		check(sim.planets.size() >= 2, "%s has two bodies" % system.name)
		var radii: Array = []
		var names: Array = []
		for body in sim.planets:
			radii.append(float(body.radius))
			names.append(str(body.name))
			check(not str(body.name).begins_with("Planet"), "%s is not a numbered planet" % body.name)
		check(radii[0] != radii[1] or str(names[0]) != str(names[1]), "%s bodies are not clones" % system.name)
		var has_band := int(system.belt.get("count", 0)) > 0
		for body in sim.planets:
			if bool(body.get("ring", false)):
				has_band = true
		check(has_band, "%s has a belt or a ring" % system.name)
		var origin := str(system.trash.get("origin", ""))
		var rain: Dictionary = system.get("stream", {})
		var has_junk := int(system.trash.get("count", 0)) > 0 and origin != ""
		var has_stream := str(rain.get("id", "")) != "" and float(rain.get("period", 0.0)) > 0.0
		check(has_junk or has_stream, "%s has junk with an origin or a timed stream" % system.name)
		if has_junk:
			check(not origins.has(origin), "%s trash origin is its own" % system.name)
			origins.append(origin)
			check(sim.trash.size() > 0, "%s trash is in the sky" % system.name)
			check(str(sim.trash[0].get("origin", "")) == origin, "%s junk remembers its origin" % system.name)
		if has_stream:
			check(sim.meteors.size() > 0, "%s stream is in the sky" % system.name)
			var before: Vector2 = sim.meteors[0].pos
			sim.tick(1.0, {})
			check(sim.meteors[0].pos.distance_to(before) > 1.0, "%s stream moves on its vector" % system.name)
		var composition := str(system.belt.get("composition", ""))
		if int(system.belt.get("count", 0)) > 0:
			check(composition != "" and composition != "asteroid belt", "%s belt names its mix" % system.name)
			check(not compositions.has(composition), "%s belt mix is not a copy" % system.name)
			compositions.append(composition)
			check(sim.asteroids.size() > 1, "%s belt has rocks" % system.name)
			check(sim.asteroids[0].verts.size() != sim.asteroids[1].verts.size() or float(sim.asteroids[0].size) != float(sim.asteroids[1].size), "%s rocks are not identical" % system.name)
		check(str(system.get("why_visit", "")).length() > 20, "%s says why to visit" % system.name)
		check(sim.nodes.size() >= 3, "%s has scan layers" % system.name)
		var lootable := false
		for row in sim.nodes:
			var layers: Dictionary = row.layers
			check(layers.has("orbit") and layers.has("legal"), "%s node %s has layers" % [system.name, row.name])
			if int(sim.deposits.get(row.id, 0)) > 0:
				lootable = true
		check(lootable, "%s is lootable" % system.name)
		check(sim.actors.size() > 0, "%s is lived in" % system.name)
	var core := make("vesper")
	core._arrive("HC-V1-R1-S2", "")
	var patrols := 0
	for actor in core.actors:
		if str(actor.team) == "helion_compact":
			patrols += 1
	check(patrols >= 1, "Compact patrols Brass Lantern")
	var lease := make("vesper")
	lease._arrive("HC-V1-R2-S1", "")
	var clerk := false
	for actor in lease.actors:
		if str(actor.name) == "Tally Clerk" or str(actor.name) == "Paper Vendor":
			clerk = true
	check(clerk, "Lease has a charter paper vendor")
	check(not bool(lease.defs.system.pocket.plantable), "Lease is not a garden pocket")
	var gyre := make("vesper")
	gyre._arrive("HC-V1-R6-S1", "")
	var peri := make("vesper")
	peri._arrive("HC-V1-R5-S6", "")
	check(_rogues(gyre) > 0 and _rogues(peri) > 0, "Gyre and Perimeter keep a rogue presence")
	check(Law.at(peri, peri.player.pos) == "red", "Perimeter law is red")
	check(bool(peri.defs.system.pocket.plantable), "Perimeter is still a garden pocket")


func _rogues(sim: SectorSim) -> int:
	var n := 0
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			n += 1
	return n


func _spine() -> void:
	var sim := make("anvil")
	check(float(sim.heat.helion_compact) == 0.0, "heat starts clean")
	sim.heat.helion_compact = 12.0
	check(ride(sim, "brass_lane") == "", "the spine leaves Helion Dock")
	check(str(sim.defs.system.name) == "Brass Lantern", "Brass Lantern is a system, not a disc")
	check(float(sim.heat.helion_compact) == 12.0, "heat survives the lane")
	check(ride(sim, "brass_to_lease") == "", "the spine reaches Lease")
	check(str(sim.defs.system.name) == "Lease", "Lease is flyable")
	check(ride(sim, "lease_to_towline") == "", "the spine reaches Towline")
	check(str(sim.defs.system.name) == "Towline", "Towline is flyable")
	check(ride(sim, "towline_to_soil") == "", "the spine reaches First Soil")
	check(str(sim.defs.system.id) == "HC-V1-R5-S1", "First Soil is still First Soil")
	check(ride(sim, "soil_to_perimeter") == "", "the spine reaches Perimeter")
	check(str(sim.defs.system.id) == "HC-V1-R5-S6", "Perimeter is the garden system")
	check(sim.nodes.size() >= 3 and sim.planets.size() >= 2, "Perimeter is not an empty disc")
	check(sim.visited.has("HC-V1-R1-S1") and sim.visited.has("HC-V1-R5-S6"), "the spine is remembered")
	var dock := make("vesper")
	check(Law.at(dock, dock.player.pos) == "green", "green grace country is still the dock orbit")
	dock.player.pos += Vector2(80, 0)
	dock.tick(0.2, {"thrust": 1.0})
	check(bool(dock.player.grace_armed) or float(dock.player.grace_t) > 0.0, "green grace still arms on Helion Dock")


func _life() -> void:
	var sim := _claim()
	check(Homestead.sow(sim, "voidbean") == "", "voidbean can be sown")
	sim.claim.plot.shade = 7.0
	sim.claim.plot.light = 1.0
	Homestead.step(sim, 0.2)
	check(str(sim.claim.plot.state) == "failed", "voidbean dies in open light")
	check(Homestead.sow(sim, "ember_kale") == "", "ember kale can be sown")
	sim.claim.plot.tend_age = 8.0
	Homestead.step(sim, 0.2)
	check(str(sim.claim.plot.state) == "failed", "ember kale dies without heat")
	check(Homestead.sow(sim, "ghost_gourd") == "", "ghost gourd can be sown")
	sim.player.pos = sim.pocket_pos + Vector2(800, 0)
	Homestead.step(sim, 9.0)
	check(str(sim.claim.plot.state) == "failed", "ghost gourd dies without a keeper")
	sim.player.pos = sim.pocket_pos
	check(Homestead.sow(sim, "voidbean") == "", "voidbean can be sown again")
	Homestead.tend(sim)
	sim.claim.plot.age = 20.0
	Homestead.step(sim, 0.2)
	check(str(sim.claim.plot.state) == "ripe", "shaded voidbean ripens")
	check(Homestead.tend(sim) == "", "voidbean can be cut")
	check(int(sim.player.cargo.get("voidbean", 0)) > 0, "voidbean yields into the hold")
	sim.player.cargo.food_mass = 2
	check(Homestead.stock(sim, "ash_hen") == "", "an ash hen can be stocked")
	check(Homestead.stock(sim, "rock_crab") == "", "a rock crab can be stocked")
	sim.claim.crate.food = 0
	sim.claim.stock[0].hunger = 9.0
	Homestead.step(sim, 0.2)
	check(bool(sim.claim.stock[0].alive) == false, "an ash hen starves without grit")
	sim.claim.plot.water = 0.0
	sim.claim.stock[1].hunger = 1.0
	Homestead.step(sim, 0.2)
	check(bool(sim.claim.stock[1].alive) == false, "a rock crab dies on a dry plot")
	sim.player.cargo.food_mass = 1
	check(Homestead.stock(sim, "ash_hen") == "", "another ash hen can be stocked")
	sim.claim.crate.food = 1
	sim.claim.stock[2].hunger = 5.0
	sim.claim.stock[2].yield = 9.5
	Homestead.step(sim, 0.6)
	check(int(sim.claim.crate.get("eggs", 0)) > 0 or float(sim.claim.stock[2].hunger) < 1.0, "an ash hen eats grit and can lay")


func _claim() -> SectorSim:
	var sim := make("anvil")
	check(ride(sim, "helion_lane") == "", "the homestead road still leaves the dock")
	sim.player.pos = sim.pocket_pos
	check(Homestead.try_plant(sim) == "", "First Soil still takes a core")
	return sim


func _craft() -> void:
	var parked := make("anvil")
	check("parked" in CraftOrders.launch(parked, "salvage_tender").to_lower(), "the tender stays parked away from a field")
	var beak := make("kestrel")
	check(CraftOrders.launch(beak, "fighter") == "", "the fighter launches onto the wing")
	var gyre := make("anvil")
	gyre._arrive("HC-V1-R6-S1", "")
	var field = gyre.survey_node("the_swallow")
	check(field != null, "the Swallow is a salvage field")
	gyre.player.pos = field.pos
	var launched := CraftOrders.launch(gyre, "salvage_tender")
	check(launched == "", "the tender launches on the Swallow")
	var worked := false
	for _i in 400:
		gyre.tick(0.05, {})
		if int(gyre.player.cargo.get("salvage_parts", 0)) > 0:
			worked = true
			break
	check(worked, "the tender brings salvage out of Gyre")
	var barn := _claim()
	check(bool(barn.claim.pen.alive) and not bool(barn.claim.pen.aboard), "the hold-kine starts in the pen")
	check(CraftOrders.launch(barn, "livestock_lighter") == "", "the lighter launches for the pen")
	var moved := false
	for _i in 300:
		barn.tick(0.05, {})
		if bool(barn.claim.pen.get("aboard", false)):
			moved = true
			break
	check(moved, "the lighter loads the hold-kine")


func _contracts() -> void:
	var sim := make("vesper")
	sim.quest_flags.did_survey = true
	sim.quest_flags.did_cull = true
	sim.quest_flags.did_recover = true
	sim.quest_flags.did_deliver = true
	sim.contracts = []
	var first := QuestBoard.refresh(sim)
	check(first == "systemic_ledger", "a contract sends you to Ledger")
	QuestBoard.accept(sim)
	sim._arrive("HC-V1-R1-S5", "")
	sim.reveal_layer("bonded_loft", "orbit")
	QuestBoard.pulse(sim, 0.2)
	check(str(sim.contracts[0].state) == "done", "scanning Ledger finishes the contract")
	sim.contracts = []
	var second := QuestBoard.refresh(sim)
	check(second == "systemic_towline", "the next contract leaves Ledger for Towline")
	QuestBoard.accept(sim)
	sim._arrive("HC-V1-R2-S2", "")
	QuestBoard.pulse(sim, 0.2)
	check(int(sim.quest_flags.get("charter_standing", 0)) > 0, "Towline raises charter standing")
	sim.contracts = []
	check(QuestBoard.refresh(sim) == "systemic_gyre", "a contract sends you to Gyre")
	QuestBoard.accept(sim)
	sim._arrive("HC-V1-R6-S1", "")
	sim.player.cargo.salvage_parts = 1
	QuestBoard.pulse(sim, 0.2)
	check(str(sim.contracts[0].state) == "done", "Gyre salvage finishes the contract")
	sim.contracts = []
	check(QuestBoard.refresh(sim) == "systemic_lantern", "a contract sends food to Brass Lantern")
	var price := int(sim.market.glasswheat)
	QuestBoard.accept(sim)
	sim._arrive("HC-V1-R1-S2", "")
	sim.player.cargo.food_mass = 1
	QuestBoard.pulse(sim, 0.2)
	check(int(sim.market.glasswheat) < price, "Brass Lantern moves the grain price")


func _shorts() -> void:
	var aegis := make("vesper")
	for layer in ["orbit", "atmosphere", "surface", "crust", "biosign", "ruins", "legal"]:
		aegis.reveal_layer("aegis_prime", layer)
	aegis.player.pos = aegis.beacon_pos
	QuestBoard.pulse(aegis, 0.2)
	check(str(aegis.quest_flags.get("authored_aegis_01", "")) == "done", "Aegis Prime inspection files")
	check(int(aegis.market.get("dock_fee", 0)) > 2, "the inspection raises the dock fee")
	var lease := make("vesper")
	var before := int(lease.market.glasswheat)
	lease._arrive("HC-V1-R2-S1", "")
	var rock = lease.planet("tallyrock")
	lease.player.pos = rock.pos
	QuestBoard.pulse(lease, 0.2)
	check(str(lease.quest_flags.get("authored_tallyrock_01", "")) == "done", "Tallyrock fine print files")
	check(int(lease.market.glasswheat) > before, "the fine print makes grain dearer")
	var wound := _claim()
	wound.claim.plot.water = 0.0
	Homestead.step(wound, 0.2)
	QuestBoard.pulse(wound, 0.2)
	check(str(wound.quest_flags.get("authored_blight_01", "")) == "done", "Green Wound blight files when the crop dies")
	var gyre := make("vesper")
	gyre._arrive("HC-V1-R6-S1", "")
	gyre.player.cargo.salvage_parts = 1
	QuestBoard.pulse(gyre, 0.2)
	check(str(gyre.quest_flags.get("authored_swallow_01", "")) == "done", "the Swallow recovery files")
	var rumors: Array = gyre.quest_flags.get("rumors", [])
	check(rumors.size() > 0, "the Swallow writes a rumor")


func _save() -> void:
	var sim := make("vesper")
	sim._arrive("HC-V1-R1-S5", "")
	sim.reveal_layer("bonded_loft", "legal")
	sim.market.voidbean = 9
	sim.quest_flags.rumor_ledger = true
	var data = JSON.parse_string(JSON.stringify(sim.to_dict()))
	var loaded := SectorSim.new(defs)
	loaded.from_dict(data)
	check(str(loaded.defs.system.id) == "HC-V1-R1-S5", "reload restores the system")
	check(loaded.visited.has("HC-V1-R1-S5"), "reload restores discoveries")
	check(loaded.scans.has("bonded_loft"), "reload restores a sealed layer")
	check(int(loaded.market.voidbean) == 9, "reload restores the market")
	check(bool(loaded.quest_flags.get("rumor_ledger", false)), "reload restores a flag")
	loaded._arrive("HC-V1-R5-S1", "")
	loaded.player.pos = loaded.pocket_pos
	Homestead.try_plant(loaded)
	var again = JSON.parse_string(JSON.stringify(loaded.to_dict()))
	var back := SectorSim.new(defs)
	back.from_dict(again)
	check(bool(back.claim.owned) and str(back.claim.system_id) == "HC-V1-R5-S1", "reload restores a First Soil claim")


func _contest() -> void:
	var sim := make("vesper")
	check(ride(sim, "helion_lane") == "", "both captains can still take the homestead road")
	sim.player.pos = sim.pocket_pos
	check(Homestead.try_plant(sim) == "", "the host plants Quiet Hollow")
	var guest: Dictionary = sim.admit("kestrel", "captain-guest")
	guest.pos = sim.pocket_pos
	check(Homestead.try_crack(sim, guest) == "", "the guest starts cracking the core")
	sim.claim.crack.t = 8.0
	sim.tick(0.2, {})
	check(str(sim.claim.agent_id) == str(guest.agent_id), "the guest takes the First Soil claim")
	check(sim.claim.locked_out.has(str(sim.player.agent_id)), "the host is locked out")
	check(bool(sim.player.alive), "the host keel was not the prize")
