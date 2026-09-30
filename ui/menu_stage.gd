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
	world.ambient_light_color = Color(0.46, 0.52, 0.64)
	world.ambient_light_energy = 0.34
	world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.glow_enabled = true
	world.glow_intensity = 0.5
	world.glow_strength = 0.82
	world.glow_bloom = 0.14
	world.glow_hdr_threshold = 0.82
	world.fog_enabled = true
	world.fog_light_color = Color("07080c")
	world.fog_density = 0.00028
	world.fog_aerial_perspective = 0.32
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
	var t := Time.get_ticks_msec() * 0.001
	var swing := sin(t * 0.28) * 14.0
	var lift := sin(t * 0.17) * 3.5
	var drift := sin(t * 0.11) * 8.0
	cam.fov = 46.0
	if hero:
		# A slow 3/4 orbit. The hull stays in the open glass; the cards keep the other side.
		if narrow and landscape:
			cam.position = Vector3(-62.0 + swing * 0.45, 30.0 + lift, 196.0)
			cam.look_at(Vector3(-36.0, 16.0, 0.0), Vector3.UP)
		elif narrow:
			cam.position = Vector3(-6.0 + swing * 0.35, 42.0 + lift, 236.0)
			cam.look_at(Vector3(6.0, 22.0, 0.0), Vector3.UP)
		else:
			cam.position = Vector3(-14.0 + swing, 32.0 + lift, 188.0)
			cam.look_at(Vector3(8.0, 20.0, 0.0), Vector3.UP)
	else:
		if narrow and landscape:
			cam.position = Vector3(-220.0 + drift, 142.0 + lift, 500.0)
			cam.look_at(Vector3(120.0, 18.0, 10.0), Vector3.UP)
		elif narrow:
			cam.position = Vector3(-160.0 + drift * 0.6, 186.0, 520.0)
			cam.look_at(Vector3(180.0, 24.0, 8.0), Vector3.UP)
		else:
			cam.position = Vector3(-190.0 + drift, 156.0 + lift, 440.0)
			cam.look_at(Vector3(240.0, 20.0, 24.0), Vector3.UP)
