extends SceneTree

var fails := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = root.get_node("/root/Game")
	var stage: Node3D = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	stage.show_yard("vesper", false)
	stage._step_yard(0.2)
	var spokes := stage.get_node_or_null("YardSpokes") as MeshInstance3D
	check(spokes != null and spokes.visible, "the title star wears corona spokes")
	var planet := stage.get_node_or_null("yard_aegis") as Node3D
	check(planet != null, "the yard has an Aegis limb")
	if planet != null:
		var ball := planet.get_node_or_null("Ball") as MeshInstance3D
		var radius := 0.0
		if ball != null and ball.mesh is SphereMesh:
			radius = (ball.mesh as SphereMesh).radius
		var ring := stage.find_child("yard_dock", true, false) as Node3D
		if ring != null:
			var gap: float = ring.position.distance_to(planet.position)
			check(gap > radius + 16.0, "the dock ring sits off the limb")
		else:
			check(false, "the dock ring sits off the limb")
	var holder := stage.find_child("yard", true, false) as Node3D
	check(holder != null and holder.get_node_or_null("MountMast") != null, "Needle keeps the spine mast")
	stage.show_yard("anvil", true)
	stage._step_yard(0.2)
	holder = stage.find_child("yard", true, false) as Node3D
	check(holder != null and holder.get_node_or_null("MountBay") != null, "Barn keeps the wide bay")
	var key := stage.get_node_or_null("YardKey") as OmniLight3D
	check(key != null and key.light_energy > 3.0, "the turntable key rakes the hull")
	var rim := stage.get_node_or_null("YardRim") as OmniLight3D
	check(rim != null and rim.light_energy > 2.0, "Helion rims the turntable")
	stage.show_yard("kestrel", true)
	stage._step_yard(0.2)
	holder = stage.find_child("yard", true, false) as Node3D
	check(holder != null and holder.get_node_or_null("MountGunP") != null, "Beak keeps the wing guns")
	var menu: Node = load("res://ui/menu_stage.gd").new()
	root.add_child(menu)
	var vp: SubViewport = menu.get("vp")
	var grade: Environment = null
	if vp != null:
		for child in vp.get_children():
			if child is WorldEnvironment:
				grade = (child as WorldEnvironment).environment
	check(grade != null and grade.glow_enabled and grade.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "the yard grade matches the helm")
	game.mode = "menu"
	var eye: Node = load("res://world/overhead.gd").new()
	root.add_child(eye)
	await process_frame
	await process_frame
	check(float(eye.get("_ease")) == 1.0, "a menu frame does not pull the helm")
	game.mode = "sector"
	await process_frame
	check(float(eye.get("_ease")) < 0.999, "choosing a keel opens the pad wide")
	if fails == 0:
		print("YARD LOOK PASS")
	else:
		print("YARD LOOK FAIL %d" % fails)
	quit(fails)


func check(ok: bool, label: String) -> void:
	if ok:
		print("ok: %s" % label)
	else:
		fails += 1
		print("FAIL: %s" % label)
