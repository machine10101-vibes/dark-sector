extends SceneTree

var fails := 0
var frames := 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	_run()
	if fails == 0:
		print("HULL MOUNTS PASS")
	else:
		print("HULL MOUNTS FAIL %d" % fails)
	quit(fails)
	return true


func _run() -> void:
	var stage: Node = load("res://world/stage3d.gd").new()
	stage.call("_ready")
	var roles: Array = ["mast", "blister", "sponson", "probes"]
	var names: Array = ["MountMast", "MountBay", "MountGunP", "MountProbe"]
	var spots: Dictionary = {}
	for class_id in ["vesper", "anvil", "kestrel"]:
		var holder := Node3D.new()
		stage.call("_fill_ship", holder, class_id, roles, [])
		var bare: Dictionary = Silhouette.parts(class_id, [])
		var worn: Dictionary = Silhouette.parts(class_id, roles, [])
		check(worn.hull.size() == bare.hull.size(), "%s planform stays the 2D card" % class_id)
		var row: Dictionary = {}
		for part_name in names:
			var node := holder.get_node_or_null(str(part_name)) as Node3D
			check(node != null, "%s wears %s" % [class_id, part_name])
			if node != null:
				row[part_name] = node.position
		spots[class_id] = row
		var empty := Node3D.new()
		stage.call("_fill_ship", empty, class_id, [], [])
		check(empty.get_node_or_null("MountMast") == null, "%s bare hull has no mast mount" % class_id)
		check(empty.get_node_or_null("MountBay") == null, "%s bare hull has no bay" % class_id)
		check(empty.get_node_or_null("MountGunP") == null, "%s bare hull has no guns" % class_id)
		check(empty.get_node_or_null("MountProbe") == null, "%s bare hull has no probe rail" % class_id)
	var needle: Dictionary = Silhouette.parts("vesper", [])
	var barn: Dictionary = Silhouette.parts("anvil", [])
	var beak: Dictionary = Silhouette.parts("kestrel", [])
	check(is_equal_approx(float(needle.hull[0].x), 52.0), "Needle nose stays 52")
	check(is_equal_approx(float(barn.hull[0].x), 26.0), "Barn nose stays 26")
	check(is_equal_approx(float(beak.hull[0].x), 48.0), "Beak nose stays 48")
	for part_name in names:
		var a: Vector3 = spots.vesper[part_name]
		var b: Vector3 = spots.anvil[part_name]
		var c: Vector3 = spots.kestrel[part_name]
		check(a.distance_to(b) > 4.0, "Needle and Barn %s sit apart" % part_name)
		check(a.distance_to(c) > 4.0, "Needle and Beak %s sit apart" % part_name)
		check(b.distance_to(c) > 4.0, "Barn and Beak %s sit apart" % part_name)
	var yard_needle: Array = stage.call("_signature_mount", "vesper")
	var yard_barn: Array = stage.call("_signature_mount", "anvil")
	var yard_beak: Array = stage.call("_signature_mount", "kestrel")
	check(str(yard_needle[0]) == "sensor_mast", "yard Needle wears the mast")
	check(str(yard_barn[0]) == "cargo_blister", "yard Barn wears the bay")
	check(str(yard_beak[0]) == "gun_sponson", "yard Beak wears the guns")
	var defs: Dictionary = root.get_node("/root/Game").get("defs")
	var needle_bare: Dictionary = Fit.stats(defs, {"class_id": "vesper", "modules": []})
	var masted: Dictionary = Fit.stats(defs, {"class_id": "vesper", "modules": ["sensor_mast"]})
	var bayed: Dictionary = Fit.stats(defs, {"class_id": "anvil", "modules": ["cargo_blister"]})
	var gunned: Dictionary = Fit.stats(defs, {"class_id": "kestrel", "modules": ["gun_sponson"]})
	var barn_bare: Dictionary = Fit.stats(defs, {"class_id": "anvil", "modules": []})
	var beak_bare: Dictionary = Fit.stats(defs, {"class_id": "kestrel", "modules": []})
	check(float(masted.sensor) > float(needle_bare.sensor), "survey mast still lengthens the sensor")
	check(int(bayed.cargo_cap) > int(barn_bare.cargo_cap), "cargo bay still adds hold")
	check(float(gunned.gun.damage) > float(beak_bare.gun.damage), "cheek gun still adds damage")
	var wick: Dictionary = Silhouette.parts("lumen", [])
	var ram: Dictionary = Silhouette.parts("casque", [])
	var kite: Dictionary = Silhouette.parts("alidade", [])
	check(float(wick.hull[0].x) > 56.0, "Wick nose is a long spar")
	check(float(ram.hull[0].x) < 20.0, "Ram nose is a short plow")
	var kite_beam := 0.0
	for point in kite.hull:
		kite_beam = maxf(kite_beam, absf(point.y))
	check(kite_beam > 26.0, "Kite wing is wider than the spar")
	check(holder_part(stage, "lumen", "LampHeart"), "Wick wears a lamp")
	check(holder_part(stage, "casque", "RamPlow"), "Ram wears a plow")
	check(holder_part(stage, "alidade", "SkyDome"), "Kite wears an eye")
	check(holder_part(stage, "lumen", "Plate"), "Wick plate triangulates")
	check(holder_part(stage, "casque", "Plate"), "Ram plate triangulates")
	check(holder_part(stage, "alidade", "Plate"), "Kite plate triangulates")
	var wick_gun: Dictionary = Fit.stats(defs, {"class_id": "lumen", "modules": []}).gun
	var ram_gun: Dictionary = Fit.stats(defs, {"class_id": "casque", "modules": []}).gun
	var kite_gun: Dictionary = Fit.stats(defs, {"class_id": "alidade", "modules": []}).gun
	check(str(wick_gun.family) == "laser", "Wick fires a beam")
	check(str(ram_gun.family) == "missile", "Ram fires a missile")
	check(str(kite_gun.family) == "bullet", "Kite fires a long gun")
	check(float(kite_gun.range) > float(beak_bare.gun.range), "Kite reaches past Beak")
	var sim = load("res://world/sector_sim.gd").new()
	sim.defs = defs
	sim.new_game("casque")
	check(int(sim.player.rounds.splinter) >= 18, "Ram carries a missile magazine")
	sim.new_game("lumen")
	check(str(sim.player.class_id) == "lumen", "Wick can cast off")
	for class_id in ["vesper", "anvil", "kestrel", "lumen", "casque", "alidade"]:
		var jets := Node3D.new()
		stage.call("_fill_ship", jets, class_id, ["jets"], [])
		var gear := jets.get_node_or_null("Gearjets0")
		check(gear != null, "%s wears turn thrusters" % class_id)
		check(gear != null and _named(gear, "Bell"), "%s thrusters have bells" % class_id)
		check(gear != null and _named(gear, "Manifold"), "%s thrusters are bolted on" % class_id)


func _named(node: Node, prefix: String) -> bool:
	if str(node.name).begins_with(prefix):
		return true
	for child in node.get_children():
		if _named(child, prefix):
			return true
	return false


func holder_part(stage: Node, class_id: String, part_name: String) -> bool:
	var holder := Node3D.new()
	stage.call("_fill_ship", holder, class_id, [], [])
	return holder.get_node_or_null(part_name) != null


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)
