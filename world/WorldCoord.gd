class_name WorldCoord
extends RefCounted

## Absolute meters for one body. Render position is meters minus the floating origin.

const CHART := 0
const WELL := 1
const BAND := 2
const CRAFT := 3
const SITE := 4

var system_id: String = ""
var body_id: String = ""
var layer: int = BAND
var origin_id: String = ""
var meters: Vector2 = Vector2.ZERO


func to_dict() -> Dictionary:
	return {
		"system_id": system_id,
		"body_id": body_id,
		"layer": layer,
		"local_origin_id": origin_id,
		"x": meters.x,
		"y": meters.y,
	}


static func from_dict(data: Dictionary) -> WorldCoord:
	var coord := WorldCoord.new()
	coord.system_id = str(data.get("system_id", ""))
	coord.body_id = str(data.get("body_id", ""))
	coord.layer = int(data.get("layer", BAND))
	coord.origin_id = str(data.get("local_origin_id", ""))
	coord.meters = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	return coord
