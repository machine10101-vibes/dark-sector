extends Node

## Autoload. render_position = world_meters - origin_meters.
## Rebase slides every registered body so the focus ship stays near 0,0.
## world_m and velocity stay put.

signal rebased(delta_m: Vector2, new_origin_m: Vector2)

var origin_m: Vector2 = Vector2.ZERO
var focus: Node2D = null
var system_id: String = "HC-V1-R1-S1"
var body_id: String = "aegis_prime"
var layer: int = WorldCoord.BAND
var origin_id: String = "aegis_orbital_band"

var rebase_threshold_m: float = 8000.0
var rebase_hysteresis_m: float = 500.0
var settle_s: float = 0.05

var rebase_count: int = 0
var settle_left: float = 0.0
var armed: bool = true

var _bodies: Array[Node] = []


func _ready() -> void:
	process_priority = 50
	process_physics_priority = 50


func register_body(body: Node) -> void:
	if body == null:
		return
	if _bodies.has(body):
		return
	_bodies.append(body)


func unregister_body(body: Node) -> void:
	_bodies.erase(body)
	if focus == body:
		focus = null


func set_focus(node: Node2D) -> void:
	focus = node
	if node != null:
		register_body(node)


func world_of_node(node: Node2D) -> Vector2:
	return origin_m + node.global_position


func render_of_world(world_m: Vector2) -> Vector2:
	return world_m - origin_m


func make_coord(meters: Vector2) -> WorldCoord:
	var coord := WorldCoord.new()
	coord.system_id = system_id
	coord.body_id = body_id
	coord.layer = layer
	coord.origin_id = origin_id
	coord.meters = meters
	return coord


func apply_coord_to_node(node: Node2D, coord: WorldCoord) -> void:
	if node == null or coord == null:
		return
	if node.has_method("snap_to_world"):
		node.set("world_m", coord.meters)
		node.snap_to_world()
	else:
		node.global_position = render_of_world(coord.meters)


func save_focus() -> Dictionary:
	var meters: Vector2 = origin_m
	if focus != null and is_instance_valid(focus):
		var stored: Variant = focus.get("world_m")
		if stored is Vector2:
			meters = stored
		else:
			meters = world_of_node(focus)
	return make_coord(meters).to_dict()


func load_focus(data: Dictionary) -> void:
	var coord := WorldCoord.from_dict(data)
	if coord.system_id != "":
		system_id = coord.system_id
	if coord.body_id != "":
		body_id = coord.body_id
	layer = coord.layer
	if coord.origin_id != "":
		origin_id = coord.origin_id
	origin_m = coord.meters
	settle_left = settle_s
	armed = false
	if focus != null and is_instance_valid(focus):
		if focus.has_method("snap_to_world"):
			focus.set("world_m", coord.meters)
			focus.snap_to_world()
		else:
			focus.global_position = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if settle_left > 0.0:
		settle_left = maxf(0.0, settle_left - delta)
		return
	if focus == null or is_instance_valid(focus) == false:
		return
	var render: Vector2 = focus.global_position
	var reach: float = render.length()
	if reach < rebase_threshold_m - rebase_hysteresis_m:
		armed = true
	if armed and reach >= rebase_threshold_m:
		armed = false
		rebase(render)


func rebase(delta_m: Vector2) -> void:
	origin_m += delta_m
	var shift: Vector2 = -delta_m
	var live: Array = _bodies.duplicate()
	for body in live:
		if is_instance_valid(body) == false:
			_bodies.erase(body)
			continue
		if body.has_method("apply_origin_shift"):
			body.apply_origin_shift(shift)
		elif body is Node2D:
			(body as Node2D).global_position += shift
	settle_left = settle_s
	rebase_count += 1
	rebased.emit(delta_m, origin_m)
