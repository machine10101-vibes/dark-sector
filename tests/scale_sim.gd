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
		"systems": {
			"HC-V1-R1-S1": Serde.load_json("res://data/system.json"),
		},
	}
	_sizes()
	_band_and_burn()
	_layers()
	_craft_trip()
	_site()
	_listen()
	if fails == 0:
		print("SCALE PASS")
	else:
		print("SCALE FAIL %d" % fails)
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


func _sizes() -> void:
	var soil: Dictionary = Serde.load_json("res://data/first_soil.json")
	var wound: Dictionary = soil.planets[0]
	var aegis: Dictionary = defs.system.planets[0]
	check(str(aegis.id) == "aegis_prime", "Aegis Prime keeps its id")
	check(ScaleFrame.radius_km(aegis) >= 1000.0, "Aegis Prime is planetary, thousands of km")
	check(ScaleFrame.across_km(wound) >= 80.0 and ScaleFrame.across_km(wound) <= 400.0, "Green Wound is 80–400 km across")
	var biomes: Array = ScaleFrame.biomes_of(wound)
	check(biomes.size() >= 3, "Green Wound has several biomes")
	var claims := 0
	var other := 0
	var span := 0.0
	for biome in biomes:
		var row: Dictionary = biome
		if bool(row.get("claim", false)):
			claims += 1
			span = float(row.span_m)
			check(bool(row.get("grow_light", false)), "the claim valley carries grow-lights")
		else:
			other += 1
	check(claims == 1, "the player claim is one valley")
	check(other >= 2, "unused land exists beyond the dome")
	check(span >= 200.0 and span <= 800.0, "the claim is 200–800 m across")
	check(ScaleFrame.ship_length_m(defs.ships.vesper) >= 40.0 and ScaleFrame.ship_length_m(defs.ships.vesper) <= 180.0, "Needle is 40–180 m")
	check(ScaleFrame.ship_length_m(defs.ships.anvil) <= 180.0, "Barn stays under 180 m")
	check(ScaleFrame.probe_length_m(defs.craft.survey_probe) >= 4.0 and ScaleFrame.probe_length_m(defs.craft.survey_probe) <= 14.0, "the probe is 4–14 m")
	check(ScaleFrame.LIMB_RADIUS / ScaleFrame.ship_length_m(defs.ships.vesper) > 40.0, "the limb dwarfs the hull")
	check(ScaleFrame.belt_is_volume(soil.belt), "the garden belt is a volume, not a handful of rocks")
	var ring: Dictionary = {}
	var trash: Dictionary = {}
	for node in defs.system.nodes:
		if str(node.id) == "aegis_ring":
			ring = node
		elif str(node.id) == "seized_hold":
			trash = node
	check(ScaleFrame.scale_of(ring).has("radius_km"), "the ice ring has a kilometer size")
	check(ScaleFrame.scale_of(trash).has("span_km"), "the trash field has a kilometer span")


func _band_and_burn() -> void:
	var sim := make("vesper")
	var frame: Dictionary = ScaleFrame.frame(sim)
	check(int(frame.layer) == ScaleFrame.BAND, "a new keel starts in the orbital band")
	check(str(frame.body_id) == "aegis_prime", "the band is Aegis Prime")
	check(str(frame.system_id) == "HC-V1-R1-S1", "the frame names Helion Dock")
	check(frame.has("local_origin") and frame.has("pos"), "the save frame has an origin and a local pos")
	check(sim.traffic.size() == 3, "Aegis carries civic, cargo, and PDO shells")
	var body = sim.planet("aegis_prime")
	var before: float = sim.player.pos.distance_to(body.pos)
	sim.player.rot = (body.pos - sim.player.pos).angle()
	sim.tick(3.0, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(int(sim.layer) == ScaleFrame.BAND, "burning in stays in the band")
	check(sim.player.pos.distance_to(body.pos) > float(body.radius) * 0.9, "burning in does not reach the city")
	check(sim.player.pos.distance_to(body.pos) <= before + 30.0, "the crust pushes the keel back out")
	var data := sim.to_dict()
	check(int(data.layer) == ScaleFrame.BAND, "the log stores the layer")
	check(str(data.body_id) == "aegis_prime", "the log stores the body")
	var copy := SectorSim.new(defs)
	copy.from_dict(data)
	check(copy.player.pos.distance_to(sim.player.pos) < 1.0, "reload keeps the local pos")
	check(int(copy.layer) == ScaleFrame.BAND, "reload keeps the band")


func _layers() -> void:
	var sim := make("vesper")
	var body = sim.planet("aegis_prime")
	var outer := ScaleFrame.band_outer(sim, body)
	sim.player.pos = body.pos + Vector2(outer - 40.0, 0.0)
	sim.player.vel = Vector2(200.0, 0.0)
	sim.tick(0.6, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(int(sim.layer) == ScaleFrame.CHART, "leaving the band returns to the chart")
	check(sim.player.vel.length() > 40.0, "leaving the band keeps the keel moving")
	var dropped: Vector2 = sim.local_origin + sim.player.pos
	check(dropped.distance_to(body.chart_km) > ScaleFrame.soi_km(body), "the chart drop sits outside the well")
	var lane_world: Vector2 = sim.local_origin + sim.chart_lane_pos(sim.gates[0])
	check(lane_world.distance_to(body.chart_km) > ScaleFrame.soi_km(body), "a lane sits outside the well on the chart")
	var viewed: Vector2 = ScaleFrame.chart_view(sim, sim.player.pos)
	check(viewed.length() < ScaleFrame.CHART_VIEW_RADIUS + 80.0, "the chart view fits a phone helm")
	sim.local_origin = Vector2(500000.0, -420000.0)
	sim.player.pos = Vector2(5200.0, -800.0)
	sim.player.vel = Vector2.ZERO
	sim.layer = ScaleFrame.CHART
	sim.body_id = ""
	var origin_before := sim.local_origin
	sim.tick(0.05, {})
	check(sim.local_origin.distance_to(origin_before) > 1000.0, "a far chart rebases the origin")
	check(sim.player.pos.length() < 50.0, "the local pos stays small after the rebase")
	var chart: Vector2 = body.chart_km
	sim.layer = ScaleFrame.CHART
	sim.body_id = ""
	sim.local_origin = chart
	sim.player.pos = Vector2(ScaleFrame.soi_km(body) * 0.4, 0.0)
	sim.player.vel = Vector2.ZERO
	sim.tick(0.05, {})
	check(int(sim.layer) == ScaleFrame.APPROACH, "entering the well drops to approach")
	check(str(sim.body_id) == "aegis_prime", "approach names Aegis Prime")
	var alt := ScaleFrame.band_alt(body)
	sim.player.pos = Vector2(ScaleFrame.radius_km(body) + alt, 0.0)
	sim.player.vel = Vector2.ZERO
	sim.tick(0.05, {})
	check(int(sim.layer) == ScaleFrame.BAND, "matching the shell enters the band")
	check(sim.player.pos.distance_to(body.pos) > float(body.radius), "the band entry stays off the crust")


func _craft_trip() -> void:
	var sim := make("vesper")
	var probe: Dictionary = {}
	for item in sim.craft:
		if str(item.def_id) == "survey_probe":
			probe = item
			break
	var place = sim.survey_node("aegis_prime")
	check(ScaleFrame.scan_pace(sim, place) > 1.2, "a scan of Aegis takes longer than a toy world")
	check(CraftOrders.order(sim, str(probe.uid), "scan", "aegis_prime") == "", "the probe accepts the scan")
	var started: Vector2 = probe.pos
	sim.tick(0.8, {})
	check(str(probe.state) == "outbound" or str(probe.state) == "working", "the probe is in transit")
	check(probe.pos.distance_to(started) > 20.0, "the scan run is a trip, not a teleport")
	check(probe.has("km_x"), "the probe stores kilometer coordinates")
	probe.hp = 0.0
	probe.state = "outbound"
	sim.tick(0.05, {})
	check(str(probe.state) == "lost", "a dead probe is lost where it was")
	check(probe.has("lost_km_x") and probe.has("lost_km_y"), "a lost craft keeps kilometer coordinates")


func _site() -> void:
	var sim := make("vesper")
	var parked: Vector2 = sim.player.pos
	sim.player.pos = sim.pocket_pos
	sim.claim.owned = true
	sim.claim.system_id = str(sim.defs.system.id)
	sim.claim.pen = {"alive": true, "hunger": 0.0, "milk": 0.0}
	check(sim.enter_site() == "", "the valley opens under the keel")
	check(int(sim.layer) == ScaleFrame.SITE, "layer 4 is the site")
	check(sim.player.pos.distance_to(parked) > 10.0, "the keel's band position is the pocket, not the pen")
	var ship_at: Vector2 = sim.player.pos
	sim.tick(0.8, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(sim.player.pos.distance_to(ship_at) < 1.0, "the capital ship does not walk the pen")
	check(sim.site_pos.length() > 2.0, "the site walks at meter scale")
	check(sim.site_pos.length() < 400.0, "the walk stays inside the valley")
	for actor in sim.actors:
		check(str(actor.get("team", "")) != "animal", "animals are not loose in the well")


func _listen() -> void:
	var sim := make("vesper")
	var snap: Dictionary = sim.net_snapshot()
	check(snap.has("layer") and snap.has("local_origin") and snap.has("pos") and snap.has("body_id"), "the listen snapshot shares layer and coords")
	var guest := SectorSim.new(defs)
	guest.new_game("vesper")
	guest.player.pos = Vector2(50.0, 50.0)
	guest.apply_snapshot(snap)
	check(int(guest.layer) == int(sim.layer), "the guest takes the host layer")
	check(guest.local_origin.distance_to(sim.local_origin) < 0.1, "the guest takes the host origin")
	check(str(guest.body_id) == str(sim.body_id), "the guest takes the host body")
