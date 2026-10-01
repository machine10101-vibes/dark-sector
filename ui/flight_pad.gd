extends Control

## Touch helm. Writes Game.flight. Keyboard still wins when a key is down.

var joy: Control
var fire_button: Button
var strafe_left: Button
var strafe_right: Button
var zoom_in: Button
var zoom_out: Button
var knob := Vector2.ZERO
var joy_touch := -1
var fire_held := false
var hold_left := false
var hold_right := false
var radius := 64.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy = Control.new()
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


func place(screen: Vector2, dock: float = 8.0, short: bool = false) -> void:
	position = Vector2.ZERO
	size = screen
	var joy_size := 96.0 if short else 132.0
	radius = 38.0 if short else 52.0
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
	joy.queue_redraw()


func band_top(screen: Vector2, short: bool) -> float:
	var joy_size := 96.0 if short else 132.0
	var gun := 64.0 if short else 84.0
	var zoom_h := 36.0 if short else 40.0
	var cluster := gun + zoom_h + 18.0
	var pad_h := maxf(joy_size, cluster)
	return screen.y - 8.0 - pad_h - 12.0


func release() -> void:
	_release_joy()
	fire_held = false
	hold_left = false
	hold_right = false
	Game.flight = {
		"thrust": 0.0,
		"retro": 0.0,
		"rot": 0.0,
		"strafe": 0.0,
		"fire": false,
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
	joy.draw_circle(center, radius, Color(0.04, 0.05, 0.07, 0.55))
	joy.draw_arc(center, radius, 0.0, TAU, 40, Color("8a7344"), 2.0, true)
	joy.draw_circle(center + knob, 22.0, Color("cbb892"))
	joy.draw_circle(center + knob, 8.0, Color("e6d7bf"))
