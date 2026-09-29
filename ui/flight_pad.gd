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


func place(screen: Vector2) -> void:
	position = Vector2.ZERO
	size = screen
	var joy_size := 150.0
	radius = 62.0
	joy.position = Vector2(12, screen.y - joy_size - 64)
	joy.size = Vector2(joy_size, joy_size)
	fire_button.position = Vector2(screen.x - 104, screen.y - 168)
	fire_button.size = Vector2(88, 88)
	strafe_left.position = Vector2(screen.x - 196, screen.y - 120)
	strafe_left.size = Vector2(80, 44)
	strafe_right.position = Vector2(screen.x - 196, screen.y - 172)
	strafe_right.size = Vector2(80, 44)
	zoom_in.position = Vector2(screen.x - 104, screen.y - 224)
	zoom_in.size = Vector2(40, 44)
	zoom_out.position = Vector2(screen.x - 56, screen.y - 224)
	zoom_out.size = Vector2(40, 44)
	joy.queue_redraw()


func _process(_delta: float) -> void:
	if not visible:
		return
	var thrust := 0.0
	var retro := 0.0
	var rot := 0.0
	if knob.length() > radius * 0.18:
		var aim := knob / radius
		rot = clampf(aim.x, -1.0, 1.0)
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
