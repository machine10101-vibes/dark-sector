class_name RebasingBody2D
extends Node2D

## world_m is the source of truth. global_position is only the render offset.

var world_m: Vector2 = Vector2.ZERO


func _ready() -> void:
	if FloatingOrigin:
		FloatingOrigin.register_body(self)
		snap_to_world()


func _exit_tree() -> void:
	if FloatingOrigin:
		FloatingOrigin.unregister_body(self)


func apply_origin_shift(shift: Vector2) -> void:
	global_position += shift


func snap_to_world() -> void:
	if FloatingOrigin == null:
		return
	global_position = FloatingOrigin.render_of_world(world_m)


func sync_world_from_render() -> void:
	if FloatingOrigin == null:
		return
	world_m = FloatingOrigin.world_of_node(self)
