class_name HelmShip2D
extends CharacterBody2D

## Inertial helm for the scale demo. About 48 m, Vesper plan.
## The live sector keeps its own helm. This hull is not instanced there.

var world_m: Vector2 = Vector2.ZERO

var turn_rate: float = 1.7
var thrust_accel: float = 48.0
var burn_accel: float = 86.0
var vmax: float = 280.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	var points := PackedVector2Array([
		Vector2(28.0, 0.0),
		Vector2(6.0, 7.0),
		Vector2(-16.0, 9.0),
		Vector2(-20.0, 0.0),
		Vector2(-16.0, -9.0),
		Vector2(6.0, -7.0),
	])
	var shape := CollisionShape2D.new()
	var poly := ConvexPolygonShape2D.new()
	poly.points = points
	shape.shape = poly
	add_child(shape)
	var skin := Polygon2D.new()
	skin.color = Color("e4d2b0")
	skin.polygon = points
	add_child(skin)
	var glow := Polygon2D.new()
	glow.color = Color(0.95, 0.55, 0.22, 0.85)
	glow.polygon = PackedVector2Array([
		Vector2(-18.0, 3.2),
		Vector2(-18.0, -3.2),
		Vector2(-27.0, 0.0),
	])
	add_child(glow)
	var gate: Variant = WorldCoord.gate()
	if gate != null:
		gate.register_body(self)
		gate.set_focus(self)
	sync_world_from_render()


func _exit_tree() -> void:
	var gate: Variant = WorldCoord.gate()
	if gate != null:
		gate.unregister_body(self)


func apply_origin_shift(shift: Vector2) -> void:
	position += shift


func snap_to_world() -> void:
	var gate: Variant = WorldCoord.gate()
	if gate == null:
		return
	global_position = gate.render_of_world(world_m)


func sync_world_from_render() -> void:
	var gate: Variant = WorldCoord.gate()
	if gate == null:
		return
	world_m = gate.world_of_node(self)


func _physics_process(delta: float) -> void:
	var yaw := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		yaw -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		yaw += 1.0
	rotation += yaw * turn_rate * delta
	var accel := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		accel += thrust_accel
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		accel -= thrust_accel * 0.55
	if Input.is_key_pressed(KEY_SPACE):
		accel += burn_accel
	var nose := Vector2.from_angle(rotation)
	velocity += nose * accel * delta
	if accel < 0.0 and velocity.dot(nose) < 0.0:
		velocity = velocity.slide(nose)
	if velocity.length() > vmax:
		velocity = velocity.limit_length(vmax)
	move_and_slide()
	sync_world_from_render()
