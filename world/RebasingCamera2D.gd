class_name RebasingCamera2D
extends Camera2D

## Follows the focus ship and snaps when the origin rebases.
## Zoom stays at ship scale. A 6371 km limb must not read as hull-sized.

var follow: Node2D = null


func _ready() -> void:
	enabled = true
	make_current()
	if zoom.x > 0.35:
		zoom = Vector2(0.22, 0.22)
	if FloatingOrigin and FloatingOrigin.rebased.is_connected(_on_rebased) == false:
		FloatingOrigin.rebased.connect(_on_rebased)
	_snap()


func _physics_process(_delta: float) -> void:
	_snap()


func _on_rebased(_delta_m: Vector2, _new_origin_m: Vector2) -> void:
	_snap()


func _snap() -> void:
	var target: Node2D = follow
	if target == null and FloatingOrigin:
		target = FloatingOrigin.focus
	if target == null or is_instance_valid(target) == false:
		return
	global_position = target.global_position
