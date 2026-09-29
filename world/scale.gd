class_name ScaleFrame
extends RefCounted

## Nested helm. Chart and approach are kilometers. The band keeps the
## existing local playfield so the loop still resolves. Saves store a
## rebasing origin in kilometers plus a local pos, never one float from the star.

const CHART := 0
const APPROACH := 1
const BAND := 2
const CRAFT := 3
const SITE := 4

const CHART_KM_PER_UNIT := 40.0
const BAND_KM_PER_UNIT := 0.1
const REBASE_KM := 4000.0
const LIMB_RADIUS := 15000.0


static func layer_name(layer: int) -> String:
	match layer:
		CHART:
			return "chart"
		APPROACH:
			return "approach"
		BAND:
			return "band"
		CRAFT:
			return "craft"
		SITE:
			return "site"
		_:
			return "band"


static func chart_km(body: Dictionary) -> Vector2:
	return Vector2.from_angle(float(body.get("angle", 0.0))) * float(body.get("distance", 0.0)) * CHART_KM_PER_UNIT


static func scale_of(row: Dictionary) -> Dictionary:
	var raw = row.get("scale", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


static func radius_km(row: Dictionary) -> float:
	var scale := scale_of(row)
	if scale.has("radius_km"):
		return float(scale.radius_km)
	if scale.has("across_km"):
		return float(scale.across_km) * 0.5
	return maxf(80.0, float(row.get("radius", 40.0)) * 4.0)


static func across_km(row: Dictionary) -> float:
	var scale := scale_of(row)
	if scale.has("across_km"):
		return float(scale.across_km)
	return radius_km(row) * 2.0


static func soi_km(row: Dictionary) -> float:
	var scale := scale_of(row)
	if scale.has("soi_km"):
		return float(scale.soi_km)
	return maxf(radius_km(row) * 4.0, 600.0)


static func bands_of(row: Dictionary) -> Array:
	var scale := scale_of(row)
	var rows = scale.get("bands", [])
	if typeof(rows) != TYPE_ARRAY:
		return []
	return rows


static func primary_band(row: Dictionary) -> Dictionary:
	var rows := bands_of(row)
	if rows.is_empty():
		return {"id": "band", "name": "Orbital band", "alt_km": 80.0, "width_km": 60.0}
	var first: Dictionary = rows[0]
	return first


static func band_alt(row: Dictionary) -> float:
	return float(primary_band(row).get("alt_km", 80.0))


static func sites_of(row: Dictionary) -> Array:
	var scale := scale_of(row)
	var rows = scale.get("sites", [])
	if typeof(rows) != TYPE_ARRAY:
		return []
	return rows


static func biomes_of(row: Dictionary) -> Array:
	var scale := scale_of(row)
	var rows = scale.get("biomes", [])
	if typeof(rows) != TYPE_ARRAY:
		return []
	return rows


static func ship_length_m(hull: Dictionary) -> float:
	return clampf(float(hull.get("length_m", 90.0)), 40.0, 180.0)


static func probe_length_m(row: Dictionary) -> float:
	return clampf(float(row.get("length_m", 8.0)), 4.0, 14.0)


static func band_outer(sim, body: Dictionary) -> float:
	var far := float(body.get("radius", 80.0)) + 960.0
	var zones: Dictionary = sim.defs.system.get("zones", {})
	var green: Dictionary = zones.get("green", {})
	if str(green.get("anchor", "")) == str(body.get("id", "")):
		far = maxf(far, float(green.get("radius", 0.0)) + 360.0)
	var center: Vector2 = body.pos
	for gate in sim.gates:
		var row: Dictionary = gate
		far = maxf(far, center.distance_to(row.pos) + float(row.get("radius", 80.0)) + 260.0)
	var pocket: Dictionary = sim.defs.system.get("pocket", {})
	if str(pocket.get("anchor", "")) == str(body.get("id", "")):
		far = maxf(far, float(pocket.get("distance", 0.0)) + float(pocket.get("radius", 0.0)) + 180.0)
	return far


static func scan_pace(sim, place: Dictionary) -> float:
	var anchor = sim.planet(str(place.get("anchor", place.get("id", ""))))
	var radius := 400.0
	var alt := 120.0
	if anchor != null:
		radius = radius_km(anchor)
		alt = band_alt(anchor)
	var kind := str(place.get("kind", ""))
	if kind == "ring":
		alt += 40.0
	elif kind == "trash":
		alt += 15.0
	var pace := 1.0 + alt / 520.0 + radius / 9000.0
	return clampf(pace, 1.2, 4.2)


static func local_km(sim, pos: Vector2) -> Vector2:
	var layer := int(sim.layer)
	if layer == CHART or layer == APPROACH:
		return pos
	if layer == SITE:
		return pos * 0.001
	var body = sim.planet(str(sim.body_id))
	if body == null:
		return pos * BAND_KM_PER_UNIT
	return (pos - body.pos) * BAND_KM_PER_UNIT


static func frame(sim) -> Dictionary:
	var local: Vector2 = sim.player.pos
	if int(sim.layer) == SITE:
		local = sim.site_pos
	return {
		"system_id": str(sim.defs.system.id),
		"body_id": str(sim.body_id),
		"layer": int(sim.layer),
		"local_origin": [sim.local_origin.x, sim.local_origin.y],
		"pos": [local.x, local.y],
		"band_id": str(sim.band_id),
		"site_id": str(sim.site_id),
	}


static func mark_lost(sim, craft: Dictionary) -> void:
	var km: Vector2 = local_km(sim, craft.pos)
	craft.layer = CRAFT
	craft.km_x = km.x
	craft.km_y = km.y
	craft.lost_km_x = km.x
	craft.lost_km_y = km.y
	craft.lost_body = str(sim.body_id)
	craft.lost_system = str(sim.defs.system.id)


static func belt_is_volume(belt: Dictionary) -> bool:
	return int(belt.get("count", 0)) >= 8 or float(belt.get("width", 0.0)) >= 80.0
