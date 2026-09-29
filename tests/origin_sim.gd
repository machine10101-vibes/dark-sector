extends SceneTree

var fails := 0


func _init() -> void:
	_autoload()
	_coord()
	_save()
	_rebase()
	_velocity()
	_limb()
	if fails == 0:
		print("ORIGIN PASS")
	else:
		print("ORIGIN FAIL %d" % fails)
	quit(fails)


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func _autoload() -> void:
	var node := root.get_node_or_null("FloatingOrigin")
	check(node != null, "FloatingOrigin autoload exists")
	check(node.get_script().resource_path == "res://world/FloatingOrigin.gd", "autoload script is FloatingOrigin.gd")


func _reset() -> void:
	FloatingOrigin.origin_m = Vector2.ZERO
	FloatingOrigin.focus = null
	FloatingOrigin.rebase_count = 0
	FloatingOrigin.settle_left = 0.0
	FloatingOrigin.armed = true
	FloatingOrigin.system_id = "HC-V1-R1-S1"
	FloatingOrigin.body_id = "aegis_prime"
	FloatingOrigin.layer = WorldCoord.BAND
	FloatingOrigin.origin_id = "aegis_orbital_band"
	var held: Array = FloatingOrigin._bodies.duplicate()
	for body in held:
		FloatingOrigin.unregister_body(body)


func _coord() -> void:
	var coord := WorldCoord.new()
	coord.system_id = "HC-V1-R1-S1"
	coord.body_id = "aegis_prime"
	coord.layer = WorldCoord.BAND
	coord.origin_id = "aegis_orbital_band"
	coord.meters = Vector2(18791000.0, 12.0)
	var data := coord.to_dict()
	check(str(data.system_id) == "HC-V1-R1-S1", "coord names the system")
	check(data.has("local_origin_id"), "dict key is local_origin_id")
	check(int(data.layer) == WorldCoord.BAND, "band is layer 2")
	var back := WorldCoord.from_dict(data)
	check(back.origin_id == "aegis_orbital_band", "origin id round-trips")
	check(back.meters.distance_to(coord.meters) < 0.01, "meters round-trip")
	check(back.layer == WorldCoord.BAND, "band layer round-trips")


func _save() -> void:
	var defs: Dictionary = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": Serde.load_json("res://data/system.json"),
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
	}
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.player.pos = Vector2(1234.0, -567.0)
	sim.player.vel = Vector2(40.0, -10.0)
	var data := sim.to_dict()
	var focus: Dictionary = data.focus_coord
	check(absf(float(focus.x) - 1234.0) < 0.01, "focus coord stores world x")
	check(absf(float(focus.y) + 567.0) < 0.01, "focus coord stores world y")
	check(str(focus.local_origin_id) == "aegis_orbital_band", "focus coord names the band origin")
	var player_coord: Dictionary = data.player.coord
	check(absf(float(player_coord.x) - 1234.0) < 0.01, "player coord is world meters, not a render offset")
	check(data.player.has("pos"), "the log still stores pos")
	var copy := SectorSim.new(defs)
	copy.from_dict(data)
	check(copy.player.pos.distance_to(Vector2(1234.0, -567.0)) < 1.0, "reload keeps the position")
	check(copy.player.vel.distance_to(Vector2(40.0, -10.0)) < 0.1, "reload keeps velocity")


func _rebase() -> void:
	_reset()
	var ship := RebasingBody2D.new()
	ship.name = "Focus"
	root.add_child(ship)
	var park := Vector2(18791000.0, 0.0)
	FloatingOrigin.origin_m = park
	ship.world_m = park
	ship.snap_to_world()
	FloatingOrigin.set_focus(ship)
	check(ship.global_position.length() < 1.0, "parking render starts near 0,0")
	var traveled := 0.0
	for hop in 3:
		ship.world_m += Vector2(9000.0, 0.0)
		traveled += 9000.0
		var world_before: Vector2 = ship.world_m
		ship.snap_to_world()
		FloatingOrigin.settle_left = 0.0
		FloatingOrigin.armed = true
		FloatingOrigin._physics_process(0.016)
		check(FloatingOrigin.rebase_count == hop + 1, "rebase count is %d after %.0f m" % [hop + 1, traveled])
		check(ship.global_position.length() < 1.0, "render stays near 0 after rebase %d" % [hop + 1])
		check(ship.world_m.distance_to(world_before) < 0.01, "world_m unchanged by rebase %d" % [hop + 1])
	check(traveled >= 20000.0, "the flight covers more than 20 km")
	check(FloatingOrigin.origin_m.x > park.x + 20000.0, "origin_m advanced and world center math still holds")
	var limb := PlanetLimb2D.new()
	limb.name = "Aegis"
	root.add_child(limb)
	check(limb.world_center_m.distance_to(Vector2(12000000.0, 0.0)) < 0.1, "Aegis world center stays (12000000, 0)")
	ship.queue_free()
	limb.queue_free()


func _velocity() -> void:
	_reset()
	var helm := HelmShip2D.new()
	helm.name = "Vesper"
	root.add_child(helm)
	helm.velocity = Vector2(120.0, -35.0)
	helm.world_m = Vector2(18791000.0, 0.0)
	var speed_before: Vector2 = helm.velocity
	var pos_before: Vector2 = helm.position
	helm.apply_origin_shift(Vector2(-8000.0, 40.0))
	check(helm.velocity.distance_to(speed_before) < 0.001, "helm rebase does not change velocity")
	check(helm.position.distance_to(pos_before + Vector2(-8000.0, 40.0)) < 0.01, "helm rebase moves position")
	check(helm.world_m.distance_to(Vector2(18791000.0, 0.0)) < 0.01, "helm world_m stays until the next sync")
	helm.queue_free()


func _limb() -> void:
	_reset()
	var limb := PlanetLimb2D.new()
	root.add_child(limb)
	var center_before: Vector2 = limb.world_center_m
	FloatingOrigin.origin_m = Vector2(18791000.0, 0.0)
	FloatingOrigin.rebase(Vector2(8000.0, 0.0))
	check(limb.world_center_m.distance_to(center_before) < 0.01, "rebase does not edit the planet center")
	check(limb.world_center_m.distance_to(Vector2(12000000.0, 0.0)) < 0.1, "Aegis center is still (12000000, 0)")
	check(absf(limb.radius_m - 6371000.0) < 0.1, "Aegis radius stays 6371000 m")
	var render: Vector2 = limb.global_position
	var expect: Vector2 = FloatingOrigin.render_of_world(limb.world_center_m)
	check(render.distance_to(expect) < 1.0, "limb render follows world center minus origin")
	limb.queue_free()
