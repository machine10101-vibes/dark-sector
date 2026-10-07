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
	_silhouettes()
	_dock()
	_inertia_and_gun()
	_steer()
	_traffic()
	_save()
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


func _silhouettes() -> void:
	var needle := Silhouette.extent(Silhouette.parts("vesper", []))
	var barn := Silhouette.extent(Silhouette.parts("anvil", []))
	var beak := Silhouette.extent(Silhouette.parts("kestrel", []))
	check(needle.x > barn.x + 10.0 and barn.y > needle.y + 8.0, "Needle is longer than Barn, Barn is wider")
	check(absf(beak.y - needle.y) > 4.0 and absf(beak.x - barn.x) > 4.0, "Beak is not a copy of the other two")
	check(defs.ships.vesper.color != defs.ships.anvil.color, "Needle and Barn colors differ")
	check(defs.ships.kestrel.color != defs.ships.vesper.color, "Beak color differs from Needle")
	check(defs.factions.has("vellum_compact") and defs.factions.has("helion_compact"), "Vellum Compact was not renamed")


func _dock() -> void:
	var sim := make("vesper")
	check(str(sim.defs.system.id) == "HC-V1-R1-S1", "system id is Helion Dock")
	check(str(sim.defs.system.name) == "Helion Dock", "system name stays Helion Dock")
	check(str(sim.defs.system.star.name) == "Helion", "the star is Helion")
	var aegis = sim.planet("aegis_prime")
	check(aegis != null and bool(aegis.ring) and str(aegis.ring_kind) == "ice", "Aegis Prime wears an ice ring")
	var pad_gap: float = sim.beacon_pos.distance_to(aegis.pos) - float(aegis.radius)
	var ring_reach := float(aegis.radius) * (1.0 + 0.085 * 3.35)
	check(pad_gap > 700.0, "the Helion pad sits clear of Aegis")
	check(sim.beacon_pos.distance_to(aegis.pos) > ring_reach + 400.0, "the Helion pad sits outside the ice ring")
	check(sim.beacon_pos.distance_to(aegis.pos) < float(sim.defs.system.zones.green.radius), "the pad stays inside the green disc")
	check(sim.pocket_pos.distance_to(aegis.pos) > float(sim.defs.system.zones.green.radius), "The Unlet stays outside the green disc")
	check("Helion Compact Guard" in str(aegis.layers.legal), "Aegis Prime has a legal title")
	check(sim.trash.size() >= 8, "confiscated hulls are in the hold field")
	check("confiscated" in str(sim.defs.system.trash.origin).to_lower(), "trash names its origin")
	check(sim.asteroids.size() >= 8, "Cinder Reach is a field of rocks")
	check(str(sim.defs.system.belt.name) == "Cinder Reach", "the ore field is named")
	check("nickel cinder" in str(sim.defs.system.belt.composition), "the ore names its mix")
	check(sim.belt_pos.distance_to(sim.beacon_pos) > 180.0, "the ore field stands off the pad")
	check(sim.belt_pos.distance_to(aegis.pos) > float(aegis.radius) * 1.3, "the ore field sits outside the ice")
	var toward: Vector2 = aegis.pos - sim.beacon_pos
	check((sim.belt_pos - sim.beacon_pos).dot(toward) > 0.0, "the ore field sits between the pad and Aegis")
	check(sim.meteors.size() >= 4, "lease gravel is in the sky")
	var gravel_near := false
	for rock in sim.meteors:
		var chip: Dictionary = rock
		if sim.beacon_pos.distance_to(chip.pos) < 520.0:
			gravel_near = true
	check(gravel_near, "lease gravel crosses the pad sky")
	var scrap_near := 0
	for hull in sim.trash:
		var piece: Dictionary = hull
		if sim.beacon_pos.distance_to(piece.pos) < 520.0:
			scrap_near += 1
	check(scrap_near >= 3, "hull scrap hangs in the pad sky")
	check(sim.survey_node("cinder_reach") != null and int(sim.deposits.get("cinder_reach", 0)) > 0, "the ore field holds a deposit")
	var nickel = sim.survey_node("cinder_reach")
	var ice = sim.survey_node("lease_gravel")
	var copper = sim.survey_node("copper_slag")
	var plate = sim.survey_node("hull_plate")
	check(nickel != null and str(nickel.resource.id) == "nickel_cinder", "Cinder Reach yields nickel cinder")
	check(ice != null and str(ice.resource.id) == "ice_spall", "Lease Gravel yields ice spall")
	check(copper != null and str(copper.resource.id) == "copper_slag" and int(sim.deposits.get("copper_slag", 0)) > 0, "copper slag is a seam")
	check(plate != null and str(plate.resource.id) == "hull_plate" and int(sim.deposits.get("hull_plate", 0)) > 0, "hull plate is a seam")
	var ring = sim.survey_node("aegis_ring")
	var hold = sim.survey_node("seized_hold")
	check(ring != null and str(ring.resource.id) == "raw_mass", "the ice ring still yields raw mass")
	check(hold != null and str(hold.resource.id) == "raw_mass", "the seized hold still yields raw mass")
	check(sim.ice_pos.distance_to(sim.beacon_pos) > 500.0, "ice spall stands off the pad")
	check(sim.copper_pos.distance_to(sim.beacon_pos) > 500.0, "copper slag stands off the pad")
	check(sim.ice_pos.distance_to(sim.belt_pos) > 80.0, "ice spall stands off the belt")
	check(sim.copper_pos.distance_to(sim.belt_pos) > 80.0, "copper slag stands off the belt")
	check(sim.ice_pos.distance_to(sim.copper_pos) > 400.0, "ice and copper sit in different sky")
	check(sim.plate_pos.distance_to(sim.beacon_pos) > 400.0, "hull plate sits with the seized hold")
	check(sim.ice_pos.distance_to(sim.plate_pos) > 200.0, "ice and plate sit in different sky")
	var saw_ice := false
	var saw_copper := false
	var saw_nickel := false
	for rock in sim.asteroids:
		var chip: Dictionary = rock
		var mat := str(chip.get("material", ""))
		if mat == "ice_spall":
			saw_ice = true
		elif mat == "copper_slag":
			saw_copper = true
		elif mat == "nickel_cinder":
			saw_nickel = true
	check(saw_ice and saw_copper and saw_nickel, "the sky holds nickel, ice, and copper")
	check(sim.gang_name != "" and sim.gang_id != "", "a pirate gang holds the amber")
	var roster: Array = []
	if sim.defs.has("gangs") and sim.defs.gangs.has(sim.gang_id):
		var listed: Variant = sim.defs.gangs[sim.gang_id].get("ships", [])
		if listed is Array:
			roster = listed
	check(roster.size() >= 3, "the gang lists its ships")
	var pack := 0
	var painted := true
	for actor in sim.actors:
		if str(actor.team) != "red_keel":
			continue
		if str(actor.gang) != str(sim.gang_id) or str(actor.paint) == "":
			painted = false
		if pack < roster.size() and str(actor.name) != str(roster[pack]):
			painted = false
		pack += 1
	check(painted and pack >= 2 and pack <= 4, "the pack flies the gang's ships in one paint")
	check(str(sim.defs.system.pocket.name) == "The Unlet", "claim pocket is marked")
	check(not bool(sim.defs.system.pocket.plantable), "pocket is not plantable")
	check(not bool(sim.claim.plantable), "new game keeps the pocket closed")
	var before := str(sim.lines[0].text)
	PocketRules.confirm_walk(sim)
	check(not bool(sim.claim.surveyed), "a walk does not open the pocket")
	check(str(sim.lines[0].text) != before, "the closed pocket says so")


func _inertia_and_gun() -> void:
	var sim := make("anvil")
	var dock = sim.planet("aegis_prime")
	sim.player.rot = (sim.player.pos - dock.pos).angle()
	sim.tick(0.7, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	var coasting: float = sim.player.vel.length()
	check(coasting > 30.0, "thrust builds speed")
	sim.tick(0.4, {"thrust": 0.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(not bool(sim.player.thrusting), "thrust flag drops when the key is up")
	check(sim.player.vel.length() > 15.0, "the hull still drifts")
	var shots := sim.projectiles.size()
	sim.player.fire_cd = 0.0
	sim.try_fire(sim.player, Fit.stats(defs, sim.player).gun)
	check(sim.projectiles.size() == shots + 1, "the gun fires")


func _steer() -> void:
	var sim := make("vesper")
	check(bool(sim.player.moored), "a new needle starts moored")
	sim.tick(0.25, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(bool(sim.player.moored) == false, "thrust clears the mooring")
	check(sim.player.vel.length() > 20.0, "cast off has way on")
	sim.tick(0.35, {"thrust": 0.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(bool(sim.player.moored) == false, "the pad does not grab the keel again")
	sim.player.rot = 0.0
	sim.player.vel = Vector2(90.0, 0.0)
	sim.tick(0.55, {"thrust": 0.0, "retro": 0.0, "rot": 1.0, "strafe": 0.0, "fire": false})
	check(sim.player.vel.angle() > 0.2, "yaw carries the keel, not only the nose")
	check(sim.player.vel.length() > 40.0, "a turn keeps the drift")
	sim.player.rot = 0.0
	sim.player.vel = Vector2.ZERO
	sim.tick(0.4, {"thrust": 0.0, "retro": 0.0, "rot": 0.0, "strafe": 1.0, "fire": false})
	check(absf(sim.player.vel.y) > 8.0, "strafe steps off the nose line")


func _traffic() -> void:
	var sim := SectorSim.new(defs)
	sim.new_game("kestrel")
	var patrol := {}
	var hauler := {}
	var pirates := 0
	for actor in sim.actors:
		if str(actor.team) == "helion_compact":
			patrol = actor
		elif str(actor.team) == "civilian":
			hauler = actor
		elif str(actor.team) == "red_keel":
			pirates += 1
	check(not patrol.is_empty(), "Helion Compact patrol is on the lane")
	check(not hauler.is_empty() and str(hauler.name) == "Hauler Holt", "a civilian hauler is in the system")
	check(pirates >= 2 and pirates <= 4, "a small Red Keel pack is in the system")
	var patrol_at: Vector2 = patrol.pos
	var hauler_at: Vector2 = hauler.pos
	sim.tick(1.6, {})
	var patrol_now: Vector2 = Vector2.ZERO
	var hauler_now: Vector2 = Vector2.ZERO
	for actor in sim.actors:
		if str(actor.agent_id) == str(patrol.agent_id):
			patrol_now = actor.pos
		if str(actor.agent_id) == str(hauler.agent_id):
			hauler_now = actor.pos
	check(patrol_now.distance_to(patrol_at) > 12.0, "the patrol moves")
	check(hauler_now.distance_to(hauler_at) > 8.0, "the hauler moves")


func _save() -> void:
	var sim := make("vesper")
	sim.player.pos = Vector2(1234.0, -567.0)
	sim.player.vel = Vector2(40.0, -10.0)
	var data := sim.to_dict()
	check(str(data.system_id) == "HC-V1-R1-S1", "the log names Helion Dock")
	check(str(data.player.class_id) == "vesper", "the log names the Needle")
	var copy := SectorSim.new(defs)
	copy.from_dict(data)
	check(str(copy.player.class_id) == "vesper", "reload keeps the Needle")
	check(copy.player.pos.distance_to(Vector2(1234.0, -567.0)) < 1.0, "reload keeps the position")
	check(str(copy.defs.system.id) == "HC-V1-R1-S1", "reload is still Helion Dock")
	check(str(copy.gang_id) == str(sim.gang_id) and str(copy.gang_name) == str(sim.gang_name), "reload keeps the gang")
	var barn := make("anvil")
	check(str(barn.player.class_id) == "anvil", "Barn is a different hull")
	var beak := make("kestrel")
	check(str(beak.player.class_id) == "kestrel", "Beak is a different hull")
