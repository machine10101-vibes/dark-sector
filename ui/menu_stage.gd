extends SubViewportContainer

var vp: SubViewport
var cam: Camera3D
var yard: Node3D
var _screen := Vector2(1280, 720)
var _hero := false


func _ready() -> void:
	name = "Yard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	vp = SubViewport.new()
	vp.name = "YardView"
	# The yard used to share the helm World3D. Its turntable Needle (about
	# 1.85× the flight hull) stayed at the pad after Take, so two keels spawned.
	vp.own_world_3d = true
	vp.world_3d = World3D.new()
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
	if cam != null:
		# A current yard eye in a shared world steals the flight view, so the
		# big turntable Needle and the ice ring sit on top of the keel.
		cam.current = on
	if vp != null:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if yard != null:
		yard.visible = on
		yard.set_process(on)
		if on:
			yard.scale = Vector3.ONE
			yard.position = Vector3.ZERO
		elif yard.has_method("dismiss_yard"):
			yard.dismiss_yard()


func _aim(hero: bool) -> void:
	if cam == null:
		return
	var narrow := _screen.x < 860.0
	var portrait := _screen.y > _screen.x
	var landscape := _screen.x > _screen.y
	if yard != null:
		yard.set("menu_bias", -42.0 if hero and narrow and landscape else 0.0)
	var t := Time.get_ticks_msec() * 0.001
	var swing := sin(t * 0.28) * 14.0
	var lift := sin(t * 0.17) * 3.5
	var drift := sin(t * 0.11) * 8.0
	cam.fov = 46.0
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	if hero:
		# Whole keel in the open glass. A close pose sat inside the hull and
		# a cropped slice covered the window above the cards.
		if narrow and landscape:
			# Cards take the right side. Shift the frustum so the whole keel
			# sits in the open glass on the left, close enough to read.
			cam.fov = 28.0
			cam.h_offset = 110.0
			cam.position = Vector3(-280.0 + swing * 0.3, 210.0 + lift, 340.0)
			cam.look_at(Vector3(-16.0, 22.0, 0.0), Vector3.UP)
		elif narrow:
			cam.fov = 38.0
			cam.position = Vector3(-380.0 + swing * 0.3, 250.0 + lift, 520.0)
			cam.look_at(Vector3(6.0, -8.0, 0.0), Vector3.UP)
		elif portrait:
			cam.fov = 32.0
			cam.position = Vector3(-220.0 + swing * 0.2, 170.0 + lift, 300.0)
			cam.look_at(Vector3(6.0, 24.0, 0.0), Vector3.UP)
		else:
			# The cards cover the lower glass. Aim near the hull so it sits
			# large in the open band, not cropped on the top edge.
			cam.fov = 26.0
			cam.position = Vector3(-210.0 + swing * 0.25, 150.0 + lift, 500.0)
			cam.look_at(Vector3(6.0, 18.0, 0.0), Vector3.UP)
	else:
		# Title shot. The keel sits in the open glass: right of a wide slate,
		# under a tall one. Aegis is a limb beside that keel, not a texture wall.
		if portrait:
			# High and back, so the keel is a whole ship under the card and the
			# ice reads as a ring instead of a white floor.
			cam.fov = 40.0
			cam.position = Vector3(-319.0 + drift * 0.15, 466.0 + lift, -81.0)
			cam.look_at(Vector3(198.0, 36.0, 24.0), Vector3.UP)
		elif narrow and landscape:
			cam.fov = 36.0
			cam.position = Vector3(-119.0 + drift * 0.25, 178.0 + lift, 229.0)
			cam.look_at(Vector3(97.0, 31.0, -48.0), Vector3.UP)
		else:
			cam.fov = 38.0
			cam.position = Vector3(-119.0 + drift * 0.25, 178.0 + lift, 229.0)
			cam.look_at(Vector3(125.0, 30.0, -20.0), Vector3.UP)
