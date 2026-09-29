extends Node

## Lays the sector flat and looks down from above, a little off vertical, so the chart has depth.

var sector: Node2D
var world_vp: SubViewport
var cam3: Camera3D
var board: MeshInstance3D


func _ready() -> void:
	world_vp = SubViewport.new()
	world_vp.name = "WorldView"
	world_vp.disable_3d = true
	world_vp.transparent_bg = false
	world_vp.handle_input_locally = false
	world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_vp.size = Vector2i(1280, 720)
	add_child(world_vp)
	sector = preload("res://world/sector_view.gd").new()
	sector.name = "Sector"
	world_vp.add_child(sector)
	var rig := Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	cam3 = Camera3D.new()
	cam3.name = "Eye"
	cam3.current = true
	cam3.fov = 62.0
	cam3.near = 0.05
	cam3.far = 120.0
	rig.add_child(cam3)
	board = MeshInstance3D.new()
	board.name = "Board"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = world_vp.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.texture_repeat = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	board.material_override = mat
	rig.add_child(board)
	RenderingServer.set_default_clear_color(Color("07080c"))
	_fit()
	var host := get_viewport()
	if host != null and host.size_changed.is_connected(_fit) == false:
		host.size_changed.connect(_fit)


func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	var wide := maxi(int(screen.x), 2)
	var tall := maxi(int(screen.y), 2)
	world_vp.size = Vector2i(wide, tall)
	# About 32 degrees off straight down. Wide fov makes the near edge sit closer.
	cam3.fov = 58.0
	cam3.position = Vector3(0.0, 8.6, 5.2)
	cam3.look_at(Vector3(0.0, 0.0, -0.15), Vector3(0.0, 0.0, -1.0))
	var hits := _screen_on_ground()
	var min_x := hits[0].x
	var max_x := hits[0].x
	var min_z := hits[0].z
	var max_z := hits[0].z
	for hit in hits:
		min_x = minf(min_x, hit.x)
		max_x = maxf(max_x, hit.x)
		min_z = minf(min_z, hit.z)
		max_z = maxf(max_z, hit.z)
	var quad := QuadMesh.new()
	quad.size = Vector2((max_x - min_x) * 1.08, (max_z - min_z) * 1.08)
	board.mesh = quad
	board.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	board.position = Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)


func _screen_on_ground() -> Array[Vector3]:
	var screen := get_viewport().get_visible_rect().size
	var corners: Array[Vector2] = [
		Vector2(0.0, screen.y),
		Vector2(screen.x, screen.y),
		Vector2(screen.x, 0.0),
		Vector2(0.0, 0.0),
	]
	var hits: Array[Vector3] = []
	for corner in corners:
		var ray_from := cam3.project_ray_origin(corner)
		var ray_dir := cam3.project_ray_normal(corner)
		var t := -ray_from.y / ray_dir.y
		hits.append(ray_from + ray_dir * t)
	return hits


func set_live(on: bool) -> void:
	if cam3 != null:
		cam3.current = on
	if world_vp != null:
		world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
