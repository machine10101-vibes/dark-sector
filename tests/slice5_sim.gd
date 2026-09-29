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
	_chart()
	_lane()
	_plant_law()
	_garden()
	_kine()
	_haul()
	_raid()
	_save()
	if fails == 0:
		print("SLICE5 PASS")
	else:
		print("SLICE5 FAIL %d" % fails)
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


func _to_soil(sim: SectorSim) -> void:
	var gate: Dictionary = sim.gates[0]
	sim.player.pos = gate.pos
	check(sim.try_lane() == "", "the lane accepts the keel")


func _chart() -> void:
	check(str(defs.system.id) == "HC-V1-R1-S1", "the board still opens on Helion Dock")
	check(str(defs.systems["HC-V1-R5-S1"].name) == "First Soil", "First Soil keeps its name")
	var soil: Dictionary = defs.systems["HC-V1-R5-S1"]
	check(str(soil.star.class) == "G-warm", "First Soil has a G-warm star")
	check(str(soil.planets[0].name) == "Green Wound", "the flagship shard is Green Wound")
	check(int(soil.belt.count) > 0, "First Soil has a belt")
	check(bool(soil.pocket.plantable) and not bool(soil.pocket.exclusion), "Quiet Hollow is claimable and not excluded")
	check(not bool(defs.system.pocket.plantable), "The Unlet stays closed")


func _lane() -> void:
	var sim := make("vesper")
	check(int(sim.player.cargo.get("claim_core", 0)) == 1, "the hold starts with a Claim Core")
	var aegis = sim.planet("aegis_prime")
	var gate: Dictionary = sim.gates[0]
	var gate_d: float = gate.pos.distance_to(aegis.pos)
	check(gate_d > float(sim.defs.system.zones.green.radius), "the Helion buoy sits outside the green lane")
	var klass := str(sim.player.class_id)
	var hp: float = sim.player.hp
	_to_soil(sim)
	check(str(sim.defs.system.id) == "HC-V1-R5-S1", "the lane arrives at First Soil")
	check(str(sim.player.class_id) == klass, "the keel is the same ship")
	check(absf(float(sim.player.hp) - hp) < 0.1, "the jump does not scrap the hull")
	check(sim.planet("green_wound") != null, "Green Wound is in the system")
	check(sim.asteroids.size() > 0, "the garden belt is drawn as rocks")
	var back: Dictionary = {}
	for row in sim.gates:
		back = row
	sim.player.pos = back.pos
	check(sim.try_lane() == "", "the road runs back to Helion Dock")
	check(str(sim.defs.system.id) == "HC-V1-R1-S1", "the return lane is Helion Dock")


func _plant_law() -> void:
	var sim := make("kestrel")
	var refused := Homestead.try_plant(sim)
	check("Aegis Prime" in refused or "Helion Dock" in refused, "Helion Dock refuses a core")
	check(int(sim.player.cargo.get("claim_core", 0)) == 1, "a refused core stays in the hold")
	sim.player.pos = sim.planet("aegis_prime").pos
	var on_prime := Homestead.try_plant(sim)
	check("Compact" in on_prime, "Aegis Prime cites Compact law")
	check(not bool(sim.claim.owned), "no homestead anchors in Helion Dock")
	_to_soil(sim)
	sim.player.pos = sim.pocket_pos
	check(Homestead.try_plant(sim) == "", "Quiet Hollow takes the core")
	check(bool(sim.claim.owned) and bool(sim.claim.core), "the core is in the ground")
	check(str(sim.claim.system_id) == "HC-V1-R5-S1", "the homestead is tagged to First Soil")
	check(str(sim.claim.plot.state) == "growing", "glasswheat is sown with the core")
	check(bool(sim.claim.pen.alive), "a hold-kine starts in the pen")
	check(int(sim.player.cargo.get("claim_core", 0)) == 0, "planting spends the core")
	sim.player.cargo["raw_mass"] = 4
	check(Homestead.try_make_core(sim) == "", "a core can be made from harvested mass")
	check(int(sim.player.cargo.get("claim_core", 0)) == 1, "the fabricated core is aboard")


func _garden() -> void:
	var sim := _planted("vesper")
	sim.claim.plot.water = 100.0
	sim.tick(21.0, {})
	check(str(sim.claim.plot.state) == "ripe", "glasswheat ripens when it has water and time")
	check(Homestead.tend(sim) == "", "a ripe plot can be cut")
	check(int(sim.player.cargo.get("food_mass", 0)) > 0, "the cut yields food mass")
	var dry := _planted("vesper")
	dry.tick(9.0, {})
	check(str(dry.claim.plot.state) == "failed", "glasswheat fails when the water is neglected")
	var cut := _planted("vesper")
	cut.player.pos = Vector2(8000, 8000)
	check(Homestead.resolve_raid(cut) == "dome", "an undefended pass ruptures the dome")
	check(str(cut.claim.plot.state) == "failed", "a ruptured dome kills the crop")
	check(bool(cut.player.alive) and str(cut.player.class_id) == "vesper", "the raid does not delete the ship")


func _kine() -> void:
	var sim := _planted("anvil")
	sim.claim.pen.fodder = 0
	sim.tick(15.0, {})
	check(not bool(sim.claim.pen.alive), "a hold-kine dies if it is not fed")
	var fed := _planted("anvil")
	check(Homestead.feed(fed) == "", "starter fodder feeds the kine")
	fed.tick(4.0, {})
	check(bool(fed.claim.pen.alive), "a fed kine stays alive")
	check(float(fed.claim.pen.milk) > 1.0, "a fed kine makes milk analogue")


func _haul() -> void:
	var barn := _planted("anvil")
	check(Homestead.haul(barn) == "", "Anvil can carry a hold-kine without a cassette")
	check(bool(barn.claim.pen.aboard), "the kine is aboard the Barn")
	var needle := _planted("vesper")
	var blocked := Homestead.haul(needle)
	check("farm cassette" in blocked, "Needle cannot haul a kine bare")
	check(needle.install("farm_cassette").ok, "the farm cassette still bolts")
	check(Homestead.haul(needle) == "", "a farm cassette lets Needle carry the kine")
	var beak := _planted("kestrel")
	beak.player.cargo["raw_mass"] = 3
	check(Homestead.fit_pen(beak) == "", "mass fits a livestock pen")
	check(beak.player.modules.has("livestock_pen"), "the pen is on the keel")
	check(Homestead.haul(beak) == "", "the pen lets Beak carry the kine")


func _raid() -> void:
	var sim := _planted("vesper")
	sim.player.pos = sim.pocket_pos
	check(Homestead.resolve_raid(sim) == "held", "the keel in the pocket turns the miner")
	check(not bool(sim.claim.ruptured), "a defended dome stays sealed")
	check(Homestead.toggle_turret(sim) == "", "a turret can be parked")
	sim.player.pos = Vector2(9000, 9000)
	check(Homestead.resolve_raid(sim) == "held", "a parked turret holds the hollow")
	sim.claim.turret = false
	check(Homestead.resolve_raid(sim) == "dome", "absence lets the miner cut the dome")
	check(Homestead.resolve_raid(sim) == "kine", "a second pass can take the kine")
	check(Homestead.resolve_raid(sim) == "core", "losing the core freezes the homestead")
	check(bool(sim.claim.frozen) and not bool(sim.claim.core), "the core is gone and the claim is frozen")
	check(bool(sim.player.alive) and str(sim.player.class_id) == "vesper", "the frozen claim still has its ship")


func _save() -> void:
	var sim := _planted("anvil")
	sim.claim.plot.age = 4.5
	sim.claim.plot.water = 3.0
	sim.claim.pen.hunger = 2.0
	sim.claim.turret = true
	var data := sim.to_dict()
	var parsed = JSON.parse_string(JSON.stringify(data))
	var copy := SectorSim.new(defs)
	copy.from_dict(parsed)
	check(str(copy.defs.system.id) == "HC-V1-R5-S1", "reload returns to First Soil")
	check(bool(copy.claim.owned) and str(copy.claim.pocket_name) == "Quiet Hollow", "reload keeps the claim")
	check(absf(float(copy.claim.plot.age) - 4.5) < 0.05, "reload keeps the crop timer")
	check(absf(float(copy.claim.pen.hunger) - 2.0) < 0.05, "reload keeps the kine")
	check(bool(copy.claim.pen.alive) and bool(copy.claim.turret), "reload keeps the pen and the turret")
	check(str(copy.player.class_id) == "anvil", "reload keeps the ship")


func _planted(class_id: String) -> SectorSim:
	var sim := make(class_id)
	_to_soil(sim)
	sim.player.pos = sim.pocket_pos
	Homestead.try_plant(sim)
	return sim
