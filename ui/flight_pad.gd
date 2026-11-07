extends Control

## Touch helm. Writes Game.flight. Keyboard still wins when a key is down.

var joy: Control
var fire_button: Button
var strafe_left: Button
var strafe_right: Button
var boost_button: Button
var zoom_in: Button
var zoom_out: Button
var knob := Vector2.ZERO
var joy_touch := -1
var fire_held := false
var hold_left := false
var hold_right := false
var boost_held := false
var radius := 64.0
var knob_r := 22.0


## The well is the touch target. On a short phone it stays under the helm bars.
## Travel is how far the thumb moves. The puck is the disc under it.
static func metrics_of(screen: Vector2, short: bool) -> Vector3:
	var well := 148.0 if short else 220.0
	var gun := 64.0 if short else 84.0
	var side := 70.0 if short else 76.0
	var room := screen.x - (gun + side + 36.0) - 16.0
	well = minf(well, maxf(128.0, room))
	var ceiling := screen.y - (108.0 if short else 200.0)
	well = minf(well, maxf(128.0, ceiling))
	var puck := clampf(well * 0.22, 28.0, 46.0)
	var bowl := well * 0.5 - 4.0
	var travel := maxf(36.0, bowl - puck - 2.0)
	return Vector3(well, travel, puck)


## How high the action bars sit: above the stick and the gun cluster.
static func reserved_of(screen: Vector2, short: bool) -> float:
	var gun := 64.0 if short else 84.0
	var zoom_h := 36.0 if short else 40.0
	var cluster := gun + zoom_h + 18.0
	return maxf(metrics_of(screen, short).x, cluster)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy = Control.new()
	joy.name = "Joy"
	joy.mouse_filter = Control.MOUSE_FILTER_STOP
	joy.gui_input.connect(_on_joy)
	add_child(joy)
	joy.draw.connect(_draw_joy)
	fire_button = _pad_button("GUN")
	fire_button.button_down.connect(func() -> void: fire_held = true)
	fire_button.button_up.connect(func() -> void: fire_held = false)
	strafe_left = _pad_button("Port")
	strafe_left.button_down.connect(func() -> void: hold_left = true)
	strafe_left.button_up.connect(func() -> void: hold_left = false)
	strafe_right = _pad_button("Stbd")
	strafe_right.button_down.connect(func() -> void: hold_right = true)
	strafe_right.button_up.connect(func() -> void: hold_right = false)
	zoom_in = _pad_button("+")
	zoom_in.pressed.connect(func() -> void: _zoom(1.0))
	zoom_out = _pad_button("–")
	zoom_out.pressed.connect(func() -> void: _zoom(-1.0))
	boost_button = _pad_button("Boost")
	boost_button.button_down.connect(func() -> void: boost_held = true)
	boost_button.button_up.connect(func() -> void: boost_held = false)


func place(screen: Vector2, dock: float = 8.0, short: bool = false) -> void:
	position = Vector2.ZERO
	size = screen
	var fit := metrics_of(screen, short)
	var joy_size := fit.x
	radius = fit.y
	knob_r = fit.z
	var gun := 64.0 if short else 84.0
	var zoom_h := 36.0 if short else 40.0
	var base := screen.y - dock
	joy.position = Vector2(10, base - joy_size - 6)
	joy.size = Vector2(joy_size, joy_size)
	var gun_x := screen.x - gun - 12.0
	var gun_y := base - gun - 6.0
	fire_button.position = Vector2(gun_x, gun_y)
	fire_button.size = Vector2(gun, gun)
	var side := 70.0 if short else 76.0
	var half := maxf(40.0, gun * 0.46)
	strafe_right.position = Vector2(gun_x - side - 8.0, gun_y)
	strafe_right.size = Vector2(side, half)
	strafe_left.position = Vector2(gun_x - side - 8.0, gun_y + gun - half)
	strafe_left.size = Vector2(side, half)
	var zoom_w := (gun - 6.0) * 0.5
	zoom_in.position = Vector2(gun_x, gun_y - zoom_h - 6.0)
	zoom_in.size = Vector2(zoom_w, zoom_h)
	zoom_out.position = Vector2(gun_x + zoom_w + 6.0, gun_y - zoom_h - 6.0)
	zoom_out.size = Vector2(zoom_w, zoom_h)
	boost_button.position = Vector2(gun_x - side - 8.0, gun_y - zoom_h - 6.0)
	boost_button.size = Vector2(side, zoom_h)
	joy.queue_redraw()


func band_top(screen: Vector2, short: bool) -> float:
	return screen.y - 8.0 - reserved_of(screen, short) - 12.0


func release() -> void:
	_release_joy()
	fire_held = false
	hold_left = false
	hold_right = false
	boost_held = false
	Game.flight = {
		"thrust": 0.0,
		"retro": 0.0,
		"rot": 0.0,
		"strafe": 0.0,
		"fire": false,
		"boost": false,
	}


func _process(_delta: float) -> void:
	if not visible or Game.map_open:
		release()
		return
	if joy_touch == -2 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) == false:
		_release_joy()
	if fire_button != null:
		fire_held = fire_button.button_pressed
	if strafe_left != null:
		hold_left = strafe_left.button_pressed
	if strafe_right != null:
		hold_right = strafe_right.button_pressed
	if boost_button != null:
		boost_held = boost_button.button_pressed
	var thrust := 0.0
	var retro := 0.0
	var rot := 0.0
	if knob.length() > radius * 0.1:
		var aim := knob / radius
		var x := clampf(aim.x, -1.0, 1.0)
		rot = signf(x) * pow(absf(x), 1.4)
		if aim.y < 0.0:
			thrust = clampf(-aim.y, 0.0, 1.0)
		else:
			retro = clampf(aim.y, 0.0, 1.0)
	var strafe := 0.0
	if hold_left and not hold_right:
		strafe = -1.0
	elif hold_right and not hold_left:
		strafe = 1.0
	Game.flight = {
		"thrust": thrust,
		"retro": retro,
		"rot": rot,
		"strafe": strafe,
		"fire": fire_held,
		"boost": boost_held,
	}


func _pad_button(text: String) -> Button:
	var node := ThemeKit.button(text)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(node)
	return node


func _zoom(direction: float) -> void:
	var z := Game.zoom
	if direction > 0.0:
		z *= 1.12
	else:
		z /= 1.12
	Game.zoom = clampf(z, 0.05, 1.55)


func _input(event: InputEvent) -> void:
	if joy_touch == -1:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed == false and touch.index == joy_touch:
			_release_joy()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed == false and click.button_index == MOUSE_BUTTON_LEFT and joy_touch == -2:
			_release_joy()


func _on_joy(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			joy_touch = touch.index
			_set_knob(touch.position)
		elif touch.index == joy_touch:
			_release_joy()
		joy.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == joy_touch:
			_set_knob(drag.position)
			joy.accept_event()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			joy_touch = -2
			_set_knob(click.position)
		elif joy_touch == -2:
			_release_joy()
		joy.accept_event()
	elif event is InputEventMouseMotion and joy_touch == -2:
		_set_knob((event as InputEventMouseMotion).position)
		joy.accept_event()


func _set_knob(local: Vector2) -> void:
	var center := joy.size * 0.5
	var delta := local - center
	if delta.length() > radius:
		delta = delta.normalized() * radius
	knob = delta
	joy.queue_redraw()


func _release_joy() -> void:
	joy_touch = -1
	knob = Vector2.ZERO
	joy.queue_redraw()


func _draw_joy() -> void:
	var center := joy.size * 0.5
	var bowl := maxf(radius + knob_r, center.x - 4.0)
	joy.draw_circle(center, bowl, Color(0.04, 0.05, 0.07, 0.55))
	joy.draw_arc(center, bowl, 0.0, TAU, 48, Color("8a7344"), 3.0, true)
	joy.draw_circle(center + knob, knob_r, Color("cbb892"))
	joy.draw_circle(center + knob, knob_r * 0.36, Color("e6d7bf"))
