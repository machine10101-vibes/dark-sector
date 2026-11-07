class_name ChartAtlas
extends RefCounted

## Places the Haven chart. Region centers come from the lane book.
## S1 sits on the center. S2–S6 sit on a ring that stays inside the cell.

const SLOT_RADIUS := 0.58

const FALLBACK := {
	"R1": Vector2(0, 0),
	"R2": Vector2(2, 0),
	"R3": Vector2(4, 0),
	"R4": Vector2(4, -2),
	"R5": Vector2(2, 2),
	"R6": Vector2(0, 2),
	"R7": Vector2(2, 4),
	"R8": Vector2(2, 6),
}


static func build(defs: Dictionary) -> Dictionary:
	var named: Dictionary = _index()
	var regions: Dictionary = _region_table(defs, named)
	var systems: Array = []
	var seen: Dictionary = {}
	var name_rows: Array = named.get("systems", [])
	for raw in name_rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		var sid := str(row.get("id", ""))
		if sid == "":
			continue
		seen[sid] = true
		var region := str(row.get("region", region_of(sid)))
		systems.append(_system_row(defs, regions, sid, str(row.get("name", sid)), region))
	var chart: Dictionary = defs.get("systems", {})
	for key in chart.keys():
		var sid := str(key)
		if seen.has(sid):
			continue
		var spec: Dictionary = chart[sid]
		systems.append(_system_row(defs, regions, sid, str(spec.get("name", sid)), region_of(sid)))
	var lanes_out: Array = []
	var book: Dictionary = defs.get("lanes", {})
	var raw_lanes: Array = book.get("lanes", [])
	for raw_lane in raw_lanes:
		if typeof(raw_lane) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = raw_lane
		var origin := str(lane.get("from", ""))
		var dest := str(lane.get("to", ""))
		if origin == "" or dest == "":
			continue
		lanes_out.append({
			"id": str(lane.get("id", "")),
			"from": origin,
			"to": dest,
			"color": str(lane.get("rule_color", "amber")),
			"traffic": str(lane.get("traffic", "")),
		})
	_add_gate_lanes(defs, systems, lanes_out)
	return {
		"systems": systems,
		"lanes": lanes_out,
		"regions": _region_list(regions),
		"bounds": _bounds(systems),
	}


static func slot_index(system_id: String) -> int:
	var parts := system_id.split("-")
	if parts.is_empty():
		return 1
	var tail := str(parts[parts.size() - 1])
	if tail.begins_with("S") and tail.substr(1).is_valid_int():
		return int(tail.substr(1))
	return 1


static func slot_offset(slot: int) -> Vector2:
	if slot <= 1:
		return Vector2.ZERO
	var step := slot - 2
	var ang := -PI * 0.5 + float(step) * TAU / 5.0
	return Vector2.from_angle(ang) * SLOT_RADIUS


static func region_of(system_id: String) -> String:
	var parts := system_id.split("-")
	if parts.size() >= 4:
		return str(parts[3])
	return ""


static func links(atlas: Dictionary, system_id: String) -> Array:
	var out: Array = []
	var lanes: Array = atlas.get("lanes", [])
	for raw in lanes:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = raw
		var other := ""
		if str(lane.get("from", "")) == system_id:
			other = str(lane.get("to", ""))
		elif str(lane.get("to", "")) == system_id:
			other = str(lane.get("from", ""))
		else:
			continue
		out.append({
			"id": other,
			"color": str(lane.get("color", "amber")),
			"traffic": str(lane.get("traffic", "")),
		})
	return out


static func system_named(atlas: Dictionary, system_id: String) -> Dictionary:
	var systems: Array = atlas.get("systems", [])
	for raw in systems:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		if str(row.get("id", "")) == system_id:
			return row
	return {}


static func _add_gate_lanes(defs: Dictionary, systems: Array, lanes_out: Array) -> void:
	var known: Dictionary = {}
	for raw in systems:
		var row: Dictionary = raw
		known[str(row.get("id", ""))] = true
	var seen: Dictionary = {}
	for raw in lanes_out:
		var lane: Dictionary = raw
		seen[_pair(str(lane.get("from", "")), str(lane.get("to", "")))] = true
	var chart: Dictionary = defs.get("systems", {})
	for key in chart.keys():
		var origin := str(key)
		if known.has(origin) == false:
			continue
		var spec: Dictionary = chart[origin]
		var gates: Array = spec.get("gates", [])
		for gate_raw in gates:
			if typeof(gate_raw) != TYPE_DICTIONARY:
				continue
			var gate: Dictionary = gate_raw
			var dest := str(gate.get("to", ""))
			if dest == "" or known.has(dest) == false:
				continue
			var pair := _pair(origin, dest)
			if seen.has(pair):
				continue
			seen[pair] = true
			lanes_out.append({
				"id": str(gate.get("id", pair)),
				"from": origin,
				"to": dest,
				"color": str(gate.get("color", "amber")),
				"traffic": str(gate.get("name", "")),
			})


static func _pair(a: String, b: String) -> String:
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]


static func lane_color(rule: String) -> Color:
	match rule:
		"green":
			return Color("7dcea0")
		"red":
			return Color("e07a6a")
		"mixed":
			return Color("d08a4a")
		_:
			return Color("e0b15a")


static func _system_row(defs: Dictionary, regions: Dictionary, system_id: String, fallback_name: String, region_id: String) -> Dictionary:
	var spec: Dictionary = {}
	var chart: Dictionary = defs.get("systems", {})
	if chart.has(system_id) and typeof(chart[system_id]) == TYPE_DICTIONARY:
		spec = chart[system_id]
	var display := str(spec.get("name", fallback_name))
	if display == "":
		display = fallback_name
	var home: Dictionary = regions.get(region_id, {"x": 0.0, "y": 0.0, "name": region_id})
	var at := Vector2(float(home.get("x", 0.0)), float(home.get("y", 0.0))) + slot_offset(slot_index(system_id))
	return {
		"id": system_id,
		"name": display,
		"region": region_id,
		"region_name": str(home.get("name", region_id)),
		"pos": at,
		"slot": slot_index(system_id),
		"law": str(spec.get("law_color", "")),
		"why": str(spec.get("why_visit", "")),
		"places": places_of(spec),
	}


static func places_of(spec: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if spec.is_empty():
		return out
	for raw in spec.get("nodes", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = raw
		var res: Dictionary = node.get("resource", {})
		_add_place(out, seen, str(node.get("id", "")), str(node.get("name", "")), str(node.get("kind", "")), str(res.get("name", "")))
	var belt: Dictionary = spec.get("belt", {})
	if int(belt.get("count", 0)) > 0:
		_add_place(out, seen, str(belt.get("id", "")), str(belt.get("name", "")), "belt", str(belt.get("resource_name", "")))
	var field: Dictionary = spec.get("trash", {})
	if int(field.get("count", 0)) > 0:
		_add_place(out, seen, str(field.get("id", "")), str(field.get("name", "")), "trash", str(field.get("resource_name", "")))
	var pocket: Dictionary = spec.get("pocket", {})
	_add_place(out, seen, str(pocket.get("id", "")), str(pocket.get("name", "")), "pocket", "")
	var rain: Dictionary = spec.get("stream", {})
	if str(rain.get("id", "")) != "" and str(rain.get("id", "")) != "none":
		_add_place(out, seen, str(rain.get("id", "")), str(rain.get("name", rain.get("id", ""))), "stream", str(rain.get("resource_name", "")))
	for raw in spec.get("planets", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = raw
		var scale: Dictionary = body.get("scale", {})
		for land_raw in scale.get("biomes", []):
			if typeof(land_raw) != TYPE_DICTIONARY:
				continue
			var land: Dictionary = land_raw
			_add_place(out, seen, str(land.get("id", "")), str(land.get("name", "")), "land", str(body.get("name", "")))
	return out


static func _add_place(out: Array, seen: Dictionary, id: String, place_name: String, kind: String, resource: String) -> void:
	if place_name == "" or id == "none":
		return
	if seen.has(id) or seen.has(place_name):
		return
	seen[id] = true
	seen[place_name] = true
	out.append({
		"id": id,
		"name": place_name,
		"kind": kind,
		"resource": resource,
	})


static func place_line(place: Dictionary) -> String:
	var name := str(place.get("name", ""))
	var kind := str(place.get("kind", ""))
	var res := str(place.get("resource", ""))
	if res != "" and res != name:
		return "%s · %s · %s" % [name, kind, res]
	if kind != "":
		return "%s · %s" % [name, kind]
	return name


static func _index() -> Dictionary:
	var loaded: Variant = Serde.load_json("res://world/hc_v1/ids.json")
	if typeof(loaded) != TYPE_DICTIONARY:
		return {}
	return loaded


static func _region_table(defs: Dictionary, named: Dictionary) -> Dictionary:
	var table: Dictionary = {}
	var name_rows: Array = named.get("regions", [])
	for raw in name_rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		var rid := str(row.get("id", ""))
		if rid == "":
			continue
		var at: Vector2 = FALLBACK.get(rid, Vector2.ZERO)
		table[rid] = {
			"id": rid,
			"name": str(row.get("name", rid)),
			"x": at.x,
			"y": at.y,
		}
	var book: Dictionary = defs.get("lanes", {})
	var placed: Array = book.get("regions", [])
	for raw in placed:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		var rid := str(row.get("id", ""))
		if rid == "":
			continue
		var prior: Dictionary = table.get(rid, {"id": rid, "name": rid})
		prior["x"] = float(row.get("x", prior.get("x", 0.0)))
		prior["y"] = float(row.get("y", prior.get("y", 0.0)))
		prior["id"] = rid
		if str(prior.get("name", "")) == "":
			prior["name"] = rid
		table[rid] = prior
	return table


static func _region_list(table: Dictionary) -> Array:
	var out: Array = []
	for key in table.keys():
		out.append(table[key])
	return out


static func _bounds(systems: Array) -> Rect2:
	if systems.is_empty():
		return Rect2(-1, -1, 2, 2)
	var min_x := 1.0e9
	var min_y := 1.0e9
	var max_x := -1.0e9
	var max_y := -1.0e9
	for raw in systems:
		var row: Dictionary = raw
		var at: Vector2 = row.get("pos", Vector2.ZERO)
		min_x = minf(min_x, at.x)
		min_y = minf(min_y, at.y)
		max_x = maxf(max_x, at.x)
		max_y = maxf(max_y, at.y)
	return Rect2(min_x, min_y, maxf(0.2, max_x - min_x), maxf(0.2, max_y - min_y))
