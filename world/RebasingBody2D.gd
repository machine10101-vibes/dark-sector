class_name RebasingBody2D
extends Node2D

## world_m is the source of truth. global_position is only the render offset.

var world_m: Vector2 = Vector2.ZERO


func _ready() -> void:
	var gate: Variant = WorldCoord.gate()
	if gate != null:
		gate.register_body(self)
		snap_to_world()


func _exit_tree() -> void:
	var gate: Variant = WorldCoord.gate()
	if gate != null:
		gate.unregister_body(self)


func apply_origin_shift(shift: Vector2) -> void:
	global_position += shift


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
