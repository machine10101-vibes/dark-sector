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
	check("Helion Compact Guard" in str(aegis.layers.legal), "Aegis Prime has a legal title")
	check(sim.trash.size() >= 8, "confiscated hulls are in the hold field")
	check("confiscated" in str(sim.defs.system.trash.origin).to_lower(), "trash names its origin")
	check(sim.asteroids.is_empty(), "no clone rock belt")
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
	var barn := make("anvil")
	check(str(barn.player.class_id) == "anvil", "Barn is a different hull")
	var beak := make("kestrel")
	check(str(beak.player.class_id) == "kestrel", "Beak is a different hull")
