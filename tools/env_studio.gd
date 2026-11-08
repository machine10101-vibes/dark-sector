extends SceneTree

## Renders the live helm scene to PNG on a real display.
## godot --rendering-driver opengl3 --path . --script res://tools/env_studio.gd -- out_dir shot...
## A shot is name@x,y,zoom[,look_deg]: keel position in world units, helm zoom, optional heading.

var frames := 0
var shots: Array = []
var out_dir := "/tmp/env"
var index := -1
var wait := 0
var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	for i in range(1, args.size()):
		shots.append(str(args[i]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		return false
	if frames == 8:
		main.call("_on_start", "vesper")
		root.get_node("Game").sim.hold_npc = true
		return false
	if frames >= 12 and frames < 16:
		for name in ["Hud", "DataDesk", "OriginDebug"]:
			var layer := main.get_node_or_null(name)
			if layer != null:
				layer.set("visible", false)
				layer.process_mode = Node.PROCESS_MODE_DISABLED
		return false
	if frames < 20:
		return false
	if wait > 0:
		wait -= 1
		return false
	if index >= 0 and index < shots.size():
		_shoot(shots[index])
	index += 1
	if index >= shots.size():
		quit(0)
		return true
	_place(shots[index])
	wait = 70
	return false


func _anchor(sim, kind: String) -> Vector2:
	match kind:
		"planet":
			return sim.planets[0].pos if sim.planets.size() > 0 else Vector2.ZERO
		"beacon":
			return sim.beacon_pos
		"rock":
			return sim.asteroids[0].pos if sim.asteroids.size() > 0 else sim.belt_pos
		"belt":
			return sim.belt_pos
		"ice":
			return sim.ice_pos
		"gate":
			return sim.gates[0].pos if sim.gates.size() > 0 else Vector2.ZERO
		"trash":
			return sim.trash_pos
		"wreck":
			return sim.wrecks[0].pos if sim.wrecks.size() > 0 else Vector2.ZERO
		"star":
			return Vector2.ZERO
	return Vector2.ZERO


## name@kind,dx,dy,zoom,heading_deg
func _place(spec: String) -> void:
	var game := root.get_node("Game")
	var sim = game.sim
	var at := spec.split("@")
	var nums := (at[1] if at.size() > 1 else "beacon").split(",")
	if sim.player.moored:
		sim.player.moored = false
	var base := _anchor(sim, nums[0])
	var off := Vector2(float(nums[1]) if nums.size() > 1 else 0.0, float(nums[2]) if nums.size() > 2 else 0.0)
	sim.player.pos = base + off
	sim.player.vel = Vector2.ZERO
	game.zoom = float(nums[3]) if nums.size() > 3 else 0.58
	if nums.size() > 4:
		sim.player.heading = deg_to_rad(float(nums[4]))


func _shoot(spec: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, spec.split("@")[0]]
	img.save_png(path)
	print("shot ", path)
