extends SceneTree

var fails := 0
var frames := 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	_run()
	if fails == 0:
		print("WORLD FIDELITY PASS")
	else:
		print("WORLD FIDELITY FAIL %d" % fails)
	quit(fails)
	return true


func _run() -> void:
	var scr: Script = load("res://world/stage3d.gd")
	if scr == null or scr.can_instantiate() == false:
		print("FAIL: stage3d did not parse")
		fails += 1
		return
	var stage: Node = scr.new()
	stage.call("_ready")
	var rock: ArrayMesh = stage.call("_rock_mesh", 4, 12.0)
	var box: AABB = rock.get_aabb()
	check(box.size.x > 6.0 and box.size.y > 6.0 and box.size.z > 6.0, "a rock volume has thickness on every axis")
	check(box.size.y > box.size.x * 0.35, "a rock is not a flat card")
	var ring: Shader = stage.get("_ring_shader")
	var star: Shader = stage.get("_star_shader")
	var corona: Shader = stage.get("_corona_shader")
	var planet: Shader = stage.get("_planet_shader")
	check(ring != null and ring.code.find("TIME") >= 0 and ring.code.find("glitter") >= 0, "ice ring glitter moves")
	check(star != null and star.code.find("TIME") >= 0, "the star grain moves")
	check(corona != null and corona.code.find("spike") >= 0, "the corona has rays")
	check(planet != null and planet.code.find("VERTEX +=") >= 0 and planet.code.find("crater") >= 0, "the limb is bumped and cratered")
	for class_id in ["vesper", "anvil", "kestrel"]:
		var holder := Node3D.new()
		stage.call("_fill_ship", holder, class_id, ["mast", "blister", "sponson", "probes"], [])
		check(holder.get_node_or_null("Keel") != null, "%s wears a rounded keel" % class_id)
		check(holder.get_node_or_null("Panel0") != null, "%s wears deck plates" % class_id)
		check(holder.get_node_or_null("MountMast") != null, "%s still wears the mast" % class_id)
		check(holder.get_node_or_null("MountBay") != null, "%s still wears the bay" % class_id)
		check(holder.get_node_or_null("MountGunP") != null, "%s still wears the gun" % class_id)
		check(holder.get_node_or_null("MountProbe") != null, "%s still wears the probe" % class_id)
	check(holder_part(stage, "vesper", "VaneP"), "Needle wears spine vanes")
	check(holder_part(stage, "anvil", "RibP"), "Barn wears flank ribs")
	check(holder_part(stage, "kestrel", "CheekP"), "Beak wears cheek fairings")


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
