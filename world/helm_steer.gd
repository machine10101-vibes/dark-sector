class_name HelmSteer
extends RefCounted

## Pointer grammar for the helm. Click locks a mark or flies a heading,
## drag boxes own units, right-click opens strike or fleet command,
## double-right engages. Middle-drag looks. Combat math stays elsewhere.

const DRAG_PX := 7.0
const LOOK_YAW := 0.0075
const LOOK_PITCH := 0.006
const PITCH_LO := 0.2
const PITCH_HI := 1.48


static func is_drag(start: Vector2, now: Vector2) -> bool:
	return start.distance_to(now) >= DRAG_PX


## What a press-release means. A short tap is a click. A pull is a box pick.
static func gesture(start: Vector2, now: Vector2, double_click: bool, empty: bool, right: bool) -> String:
	if is_drag(start, now) and not right:
		return "box"
	if right:
		if double_click and not empty:
			return "engage"
		if empty:
			return "command"
		return "strike"
	if empty:
		return "fly"
	if double_click:
		return "approach"
	return "lock"


static func box_of(start: Vector2, now: Vector2) -> Rect2:
	return Rect2(start, now - start).abs()


static func box_hits(box: Rect2, marks: Array) -> Array:
	var hits: Array = []
	for raw in marks:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		var at: Vector2 = row.get("at", Vector2.ZERO)
		var rad := float(row.get("rad", 16.0))
		var disc := Rect2(at - Vector2(rad, rad), Vector2(rad * 2.0, rad * 2.0))
		if box.intersects(disc):
			hits.append(row)
	return hits


static func apply_look(yaw: float, pitch: float, dx: float, dy: float) -> Dictionary:
	var next_yaw := wrapf(yaw - dx * LOOK_YAW, -PI, PI)
	var next_pitch := clampf(pitch + dy * LOOK_PITCH, PITCH_LO, PITCH_HI)
	return {"yaw": next_yaw, "pitch": next_pitch, "mode": "orbit"}


static func plane_point(cam: Camera3D, screen: Vector2) -> Vector2:
	if cam == null:
		return Vector2.INF
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.0008:
		return Vector2.INF
	var t := -origin.y / dir.y
	if t <= 0.05:
		return Vector2.INF
	var hit := origin + dir * t
	var render := Vector2(hit.x, -hit.z)
	var gate: Variant = WorldCoord.gate()
	if gate != null:
		return render + Vector2(gate.origin_m)
	return render
