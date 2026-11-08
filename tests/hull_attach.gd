extends SceneTree

## Every yard module on every playable hull must touch the hull it is bolted
## to. A mount whose whole footprint hangs clear of the skin is a floating part.

var fails := 0
var frames := 0
const CLASSES := ["vesper", "anvil", "kestrel", "lumen", "casque", "alidade"]


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	run()
	return true


func run() -> void:
	var scr = load("res://world/stage3d.gd")
	if scr == null:
		print("FAIL: stage3d did not load")
		quit(1)
		return
	var stage: Node3D = scr.new()
	stage.set("portrait_mode", true)
	root.add_child(stage)
	var game := root.get_node("Game")
	var floating := 0
	for class_id in CLASSES:
		var bare: Node3D = stage.call("pose_portrait", class_id, [])
		var base_names := {}
		for child in bare.get_children():
			base_names[str(child.name)] = true
		var modules: Array = game.defs.ships[class_id].get("yard", [])
		for module_id in modules:
			var holder: Node3D = stage.call("pose_portrait", class_id, [str(module_id)])
			holder.rotation = Vector3.ZERO
			var parts: Array = []
			for child in holder.get_children():
				var part := str(child.name)
				if base_names.has(part):
					continue
				var box := part_bounds(holder, child)
				if box.size == Vector3.ZERO:
					continue
				parts.append({"name": part, "box": box, "ok": touches(stage, holder, box)})
			var grew := true
			while grew:
				grew = false
				for item in parts:
					if item.ok:
						continue
					for other in parts:
						if other.ok and (item.box as AABB).grow(0.5).intersects(other.box):
							item.ok = true
							grew = true
							break
			for item in parts:
				if not item.ok:
					floating += 1
					print("float: %s %s %s box=%s" % [class_id, module_id, item.name, str(item.box)])
	var bare_floating := 0
	for class_id in ["vesper", "anvil", "kestrel", "lumen", "casque", "alidade", "skiff", "brig", "yawl", "lugger", "pinnace", "ketch", "cutter"]:
		var holder := Node3D.new()
		stage.add_child(holder)
		stage.call("_fill_ship", holder, class_id, [], [])
		var parts: Array = []
		for child in holder.get_children():
			var part := str(child.name)
			var box := part_bounds(holder, child)
			if box.size == Vector3.ZERO:
				continue
			var seed: bool = part in ["Plate", "Wings", "Deck"] or touches(stage, holder, box)
			parts.append({"name": part, "box": box, "ok": seed})
		var grew := true
		while grew:
			grew = false
			for item in parts:
				if item.ok:
					continue
				for other in parts:
					if other.ok and (item.box as AABB).grow(0.5).intersects(other.box):
						item.ok = true
						grew = true
						break
		for item in parts:
			if not item.ok:
				bare_floating += 1
				print("float: %s %s box=%s" % [class_id, item.name, str(item.box)])
	check(bare_floating == 0, "no stock hull part floats clear of its hull (%d floating)" % bare_floating)
	check(floating == 0, "no module part floats clear of its hull (%d floating)" % floating)
	if fails == 0:
		print("HULL ATTACH PASS")
		quit(0)
	else:
		print("HULL ATTACH FAIL %d" % fails)
		quit(1)


func part_bounds(holder: Node3D, node: Node) -> AABB:
	var into := holder.global_transform.affine_inverse()
	var acc := AABB()
	var any := false
	var meshes: Array = []
	if node is MeshInstance3D:
		meshes.append(node)
	for item in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(item)
	for item in meshes:
		var inst := item as MeshInstance3D
		if inst.mesh == null:
			continue
		var box: AABB = into * inst.global_transform * inst.get_aabb()
		if any:
			acc = acc.merge(box)
		else:
			acc = box
			any = true
	return acc if any else AABB()


func touches(stage: Node, holder: Node3D, box: AABB) -> bool:
	var steps := 5
	for ix in steps:
		for iz in steps:
			var x := box.position.x + box.size.x * float(ix) / float(steps - 1)
			var z := box.position.z + box.size.z * float(iz) / float(steps - 1)
			var reach: float = stage.call("_skin_reach", holder, x)
			if absf(z) > reach + 0.6:
				continue
			var top: float = stage.call("_skin_top", holder, x, clampf(z, -reach, reach))
			var keel: float = stage.call("_keel_y", holder, x, clampf(z, -reach, reach))
			if box.position.y <= top + 0.8 and box.end.y >= keel - 0.3:
				return true
	return false


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)
