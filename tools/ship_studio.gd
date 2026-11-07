extends SceneTree

## Renders ship and craft hulls to PNG on a real display.
## godot --path . --script res://tools/ship_studio.gd -- out_dir kind[:view] ...
## A kind is a craft id, ship:<class_id>[:bare], npc:<class_id>[:post], or mothership. A view is bow, aft, top, or side.

var frames := 0
var jobs: Array = []
var out_dir := "/tmp/studio"
var stage: Node3D
var cam: Camera3D
var holder: Node3D
var job_index := -1
var wait := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	for i in range(1, args.size()):
		jobs.append(args[i])
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1100, 700)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		_build()
		return false
	if frames < 6:
		return false
	if wait > 0:
		wait -= 1
		return false
	if job_index >= 0 and job_index < jobs.size():
		_shoot(str(jobs[job_index]))
	job_index += 1
	if job_index >= jobs.size():
		quit(0)
		return true
	_show(str(jobs[job_index]))
	wait = 4
	return false


func _build() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.26, 0.32)
	env.ambient_light_energy = 0.7
	world.environment = env
	root.add_child(world)
	cam = Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.2
	cam.far = 2000.0
	root.add_child(cam)
	cam.current = true
	stage = load("res://world/stage3d.gd").new()
	stage.set("portrait_mode", true)
	root.add_child(stage)
	stage.set_process(false)
	_show(str(jobs[0]))
	job_index = 0
	wait = 4


func _show(spec: String) -> void:
	var parts := spec.split(":")
	var kind := parts[0]
	if holder != null:
		if str(holder.name) == "portrait":
			holder.visible = false
		else:
			holder.queue_free()
		holder = null
	if kind == "ship":
		var class_id := str(parts[1])
		var modules: Array = []
		var game := root.get_node("Game")
		var hull: Dictionary = game.defs.ships[class_id]
		if parts.size() < 3 or str(parts[2]) != "bare":
			for slot in hull.get("yard", []):
				modules.append(str(slot))
		holder = stage.call("pose_portrait", class_id, modules)
		holder.rotation = Vector3.ZERO
		if holder.get_parent() == null:
			stage.add_child(holder)
		holder.visible = true
	elif kind == "npc":
		holder = Node3D.new()
		var post := str(parts[2]) if parts.size() > 2 and ["bow", "aft", "top", "side"].has(str(parts[2])) == false else ""
		stage.call("_fill_ship", holder, str(parts[1]), [], [], [], post)
		stage.add_child(holder)
	else:
		holder = stage.call("pose_craft", kind)
		stage.add_child(holder)
	var view := str(parts[parts.size() - 1])
	var box := _bounds(holder)
	holder.position = -box.get_center()
	var extent := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var dist := maxf(extent * 1.9, 28.0)
	var dir := Vector3(-0.58, 0.42, 0.82)
	if view == "bow":
		dir = Vector3(0.9, 0.35, 0.55)
	elif view == "top":
		dir = Vector3(-0.05, 1.0, 0.18)
	elif view == "side":
		dir = Vector3(-0.15, 0.1, 1.0)
	elif view == "aft":
		dir = Vector3(-0.9, 0.3, 0.45)
	cam.position = dir.normalized() * dist
	cam.look_at(Vector3.ZERO, Vector3.UP)


func _bounds(node: Node3D) -> AABB:
	var acc := AABB()
	var any := false
	var into := node.global_transform.affine_inverse()
	for item in node.find_children("*", "MeshInstance3D", true, false):
		var m := item as MeshInstance3D
		if m.mesh == null:
			continue
		var part := str(m.name)
		if part.begins_with("Exhaust") or part == "Wake" or part.begins_with("Jet") or part.begins_with("Retro"):
			continue
		var box: AABB = into * m.global_transform * m.get_aabb()
		if any:
			acc = acc.merge(box)
		else:
			acc = box
			any = true
	if not any:
		return AABB(Vector3(-10, -6, -6), Vector3(20, 12, 12))
	return acc


func _shoot(spec: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, spec.replace(":", "_")]
	img.save_png(path)
	print("shot ", path)
