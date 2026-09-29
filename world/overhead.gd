extends Node

## Presents the flat sector on a pitched board so the helm is a third-person overhead.

var sector: Node2D
var world_vp: SubViewport
var cam3: Camera3D
var board: MeshInstance3D
var board_mesh: QuadMesh


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
	cam3.fov = 42.0
	cam3.near = 0.05
	cam3.far = 80.0
	rig.add_child(cam3)
	board_mesh = QuadMesh.new()
	board = MeshInstance3D.new()
	board.name = "Board"
	board.mesh = board_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = world_vp.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.texture_repeat = false
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
	var aspect := float(wide) / float(tall)
	var span := 6.4
	board_mesh.size = Vector2(span * aspect * 1.46, span * 1.62)
	board.rotation_degrees = Vector3(-50.0, 0.0, 0.0)
	board.position = Vector3(0.0, -0.42, 0.05)
	cam3.position = Vector3(0.0, 2.45, 8.4)
	cam3.look_at(Vector3(0.0, -0.55, 0.0))


func set_live(on: bool) -> void:
	if cam3 != null:
		cam3.current = on
	if world_vp != null:
		world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
