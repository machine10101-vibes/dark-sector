extends SubViewportContainer

var vp: SubViewport
var cam: Camera3D
var yard: Node3D
var _screen := Vector2(1280, 720)
var _hero := false


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
	_screen = screen
	if vp != null:
		vp.size = Vector2i(maxi(int(screen.x), 2), maxi(int(screen.y), 2))
	_aim(_hero)


func set_keel(class_id: String, hero: bool) -> void:
	_hero = hero
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
	var narrow := _screen.x < 860.0
	var landscape := _screen.x > _screen.y
	if yard != null:
		yard.set("menu_bias", -42.0 if hero and narrow and landscape else 0.0)
	if hero:
		if narrow and landscape:
			cam.position = Vector3(-70.0, 34.0, 230.0)
			cam.look_at(Vector3(-36.0, 16.0, 0.0), Vector3.UP)
		elif narrow:
			cam.position = Vector3(-8.0, 48.0, 292.0)
			cam.look_at(Vector3(6.0, 16.0, 0.0), Vector3.UP)
		else:
			cam.position = Vector3(-18.0, 36.0, 210.0)
			cam.look_at(Vector3(8.0, 22.0, 0.0), Vector3.UP)
	else:
		if narrow and landscape:
			cam.position = Vector3(-240.0, 150.0, 520.0)
			cam.look_at(Vector3(80.0, 8.0, 20.0), Vector3.UP)
		elif narrow:
			cam.position = Vector3(-180.0, 200.0, 560.0)
			cam.look_at(Vector3(140.0, 4.0, 16.0), Vector3.UP)
		else:
			cam.position = Vector3(-210.0, 168.0, 460.0)
			cam.look_at(Vector3(220.0, 10.0, 40.0), Vector3.UP)
