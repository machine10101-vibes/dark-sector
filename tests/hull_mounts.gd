extends SceneTree

var fails := 0


func _init() -> void:
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
	if fails == 0:
		print("HULL MOUNTS PASS")
	else:
		print("HULL MOUNTS FAIL %d" % fails)
	quit(fails)


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)
