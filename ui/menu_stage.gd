extends SubViewportContainer

var vp: SubViewport
var cam: Camera3D
var yard: Node3D


func _ready() -> void:
	name = "Yard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = false
	vp = SubViewport.new()
	vp.name = "YardView"
	vp.transparent_bg = false
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(1280, 720)
	add_child(vp)
	var env := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("07080c")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color(0.16, 0.2, 0.26)
	world.ambient_light_energy = 0.45
	env.environment = world
	vp.add_child(env)
	cam = Camera3D.new()
	cam.name = "YardEye"
	cam.current = true
	cam.fov = 46.0
	cam.near = 0.5
	cam.far = 14000.0
	vp.add_child(cam)
	yard = preload("res://world/stage3d.gd").new()
	yard.name = "YardStage"
	vp.add_child(yard)
	_aim(false)


func fit(screen: Vector2) -> void:
	position = Vector2.ZERO
	size = screen
	if vp != null:
		vp.size = Vector2i(maxi(int(screen.x), 2), maxi(int(screen.y), 2))


func set_keel(class_id: String, hero: bool) -> void:
	if yard != null and yard.has_method("show_yard"):
		yard.show_yard(class_id, hero)
	_aim(hero)


func set_live(on: bool) -> void:
	visible = on
	if vp != null:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if yard != null:
		yard.set_process(on)


func _aim(hero: bool) -> void:
	if cam == null:
		return
	if hero:
		cam.position = Vector3(-18.0, 36.0, 210.0)
		cam.look_at(Vector3(8.0, 22.0, 0.0), Vector3.UP)
	else:
		cam.position = Vector3(-210.0, 168.0, 460.0)
		cam.look_at(Vector3(220.0, 10.0, 40.0), Vector3.UP)
