class_name PlanetLimb2D
extends Node2D

## A world-sized body. The node sits at render_of_world(center), so the
## camera near the origin sees only the near limb.

var world_center_m: Vector2 = Vector2(12000000.0, 0.0)
var radius_m: float = 6371000.0
var atmo_m: float = 80000.0


func _ready() -> void:
	var gate: Variant = WorldCoord.gate()
	if gate != null and gate.rebased.is_connected(_place) == false:
		gate.rebased.connect(_place)
	_place(Vector2.ZERO, Vector2.ZERO)


func _process(_delta: float) -> void:
	_place(Vector2.ZERO, Vector2.ZERO)


func _place(_delta_m: Vector2, _new_origin_m: Vector2) -> void:
	var gate: Variant = WorldCoord.gate()
	if gate == null:
		return
	global_position = gate.render_of_world(world_center_m)
	queue_redraw()


func _draw() -> void:
	var air: float = radius_m + atmo_m
	draw_arc(Vector2.ZERO, air, 0.0, TAU, 96, Color(0.55, 0.72, 0.88, 0.45), 6000.0, true)
	draw_arc(Vector2.ZERO, radius_m, 0.0, TAU, 128, Color(0.32, 0.52, 0.36, 0.95), 9000.0, true)
