class_name Chart
extends RefCounted

## Expands a density spec into the system dict the sector already flies.


static func expand(spec: Dictionary) -> Dictionary:
	var bodies: Array = spec.get("bodies", [])
	var planets: Array = []
	var nodes: Array = []
	for raw in bodies:
		var body: Dictionary = raw
		var layers := _layers(body)
		var resource := {
			"id": str(body.get("resource_id", "raw_mass")),
			"name": str(body.get("resource_name", "Raw mass")),
			"amount": int(body.get("amount", 4)),
		}
		var planet := {
			"id": str(body.id),
			"name": str(body.name),
			"angle": float(body.angle),
			"distance": float(body.distance),
			"radius": float(body.radius),
			"spin": 0.07,
			"ring": bool(body.get("ring", false)),
			"ring_kind": str(body.get("ring_kind", "")),
			"moon": bool(body.get("moon", false)),
			"junk": bool(body.get("junk", false)),
			"colors": [str(body.get("color", "#b7c4c0")), str(body.get("accent", "#8aa4a0"))],
			"legal": str(body.get("legal", "")),
			"protected": bool(body.get("protected", false)),
			"resource": resource,
			"layers": layers,
		}
		planets.append(planet)
		nodes.append({
			"id": str(body.id),
			"name": str(body.name),
			"kind": "moon" if bool(body.get("moon", false)) else "planet",
			"anchor": str(body.id),
			"legal_title": str(body.get("legal", "")),
			"heat": str(body.get("heat", "")),
			"origin": "",
			"resource": resource.duplicate(true),
			"layers": layers.duplicate(true),
		})
		if bool(body.get("ring", false)):
			var ring_layers := _layers({
				"name": "%s ring" % str(body.name),
				"blurb": "A %s ring on %s, not a copy of another system's ice." % [str(body.get("ring_kind", "band")), str(body.name)],
				"air": "None across the band.",
				"face": str(body.get("face", "")),
				"crust": "The ring is loose. The world under it is not.",
				"life": "None in the band.",
				"ruins": str(body.get("ruins", "")),
				"legal": str(body.get("legal", "")),
			})
			nodes.append({
				"id": "%s_ring" % str(body.id),
				"name": "%s ring" % str(body.name),
				"kind": "ring",
				"anchor": str(body.id),
				"angle": 0.2,
				"band": 43.0,
				"legal_title": str(body.get("legal", "")),
				"heat": str(body.get("heat", "")),
				"origin": "",
				"resource": resource.duplicate(true),
				"layers": ring_layers,
			})
	var belt: Dictionary = spec.get("belt", {})
	if not belt.is_empty() and int(belt.get("count", 0)) > 0:
		var belt_res := {
			"id": str(belt.get("resource_id", "raw_mass")),
			"name": str(belt.get("resource_name", "Raw mass")),
			"amount": int(belt.get("amount", 4)),
		}
		var belt_layers := _layers({
			"name": str(belt.get("name", "Belt")),
			"blurb": str(belt.get("composition", "")),
			"air": "None. A belt is not a sky.",
			"face": str(belt.get("composition", "a named mix")),
			"crust": "Loose. The composition is the point.",
			"life": "None.",
			"ruins": "Survey marks, if anyone left them.",
			"legal": str(belt.get("legal", "")),
		})
		nodes.append({
			"id": str(belt.id),
			"name": str(belt.name),
			"kind": "belt",
			"anchor": "",
			"angle": 0.35,
			"distance": float(belt.radius),
			"radius": 36.0,
			"legal_title": str(belt.get("legal", "")),
			"heat": str(belt.get("heat", "")),
			"origin": str(belt.get("composition", "")),
			"resource": belt_res,
			"layers": belt_layers,
		})
	var field: Dictionary = spec.get("trash", {})
	if int(field.get("count", 0)) > 0:
		var trash_res := {
			"id": str(field.get("resource_id", "scrap")),
			"name": str(field.get("resource_name", "Scrap")),
			"amount": int(field.get("amount", 4)),
		}
		var trash_layers := _layers({
			"name": str(field.get("name", "Trash")),
			"blurb": str(field.get("origin", "")),
			"air": "Vacuum, paint, and whatever the origin still leaks.",
			"face": "Plates and tags.",
			"crust": "Hollow. This is junk with a history.",
			"life": "None living.",
			"ruins": str(field.get("origin", "")),
			"legal": str(field.get("legal", "")),
		})
		nodes.append({
			"id": str(field.id),
			"name": str(field.name),
			"kind": "trash",
			"anchor": str(field.get("anchor", "")),
			"angle": float(field.get("angle", 0.0)),
			"distance": float(field.get("distance", 0.0)),
			"radius": 40.0,
			"legal_title": str(field.get("legal", "")),
			"heat": str(field.get("heat", "")),
			"origin": str(field.get("origin", "")),
			"resource": trash_res,
			"layers": trash_layers,
		})
	var rain: Dictionary = spec.get("stream", {})
	if not rain.is_empty() and str(rain.get("id", "")) != "":
		var rain_res := {
			"id": str(rain.get("resource_id", "raw_mass")),
			"name": str(rain.get("resource_name", "Raw mass")),
			"amount": int(rain.get("amount", 4)),
		}
		var rain_layers := _layers({
			"name": str(rain.name),
			"blurb": str(rain.get("origin", "")),
			"air": "None. The stream is moving mass.",
			"face": "Chips on a vector.",
			"crust": "No crust. A timer and a direction.",
			"life": "None. It will still kill a careless probe.",
			"ruins": str(rain.get("origin", "")),
			"legal": str(rain.get("legal", "")),
		})
		nodes.append({
			"id": str(rain.id),
			"name": str(rain.name),
			"kind": "stream",
			"anchor": str(rain.get("anchor", "")),
			"angle": float(rain.get("angle", 0.0)),
			"distance": float(rain.get("distance", 0.0)),
			"radius": 34.0,
			"legal_title": str(rain.get("legal", "")),
			"heat": str(rain.get("heat", "")),
			"origin": str(rain.get("origin", "")),
			"resource": rain_res,
			"layers": rain_layers,
		})
	var pocket: Dictionary = spec.get("pocket", {}).duplicate(true)
	return {
		"id": str(spec.id),
		"name": str(spec.name),
		"seed": int(spec.seed),
		"why_visit": str(spec.get("why_visit", "")),
		"law_color": str(spec.get("law_color", "")),
		"star": spec.star,
		"planets": planets,
		"nodes": nodes,
		"belt": {
			"id": str(belt.get("id", "none")),
			"name": str(belt.get("name", "")),
			"composition": str(belt.get("composition", "")),
			"radius": float(belt.get("radius", 1.0)),
			"width": float(belt.get("width", 0.0)),
			"count": int(belt.get("count", 0)),
		},
		"trash": {
			"id": str(field.get("id", "none")),
			"name": str(field.get("name", "")),
			"origin": str(field.get("origin", "")),
			"anchor": str(field.get("anchor", "")),
			"angle": float(field.get("angle", 0.0)),
			"distance": float(field.get("distance", 0.0)),
			"count": int(field.get("count", 0)),
			"spread": float(field.get("spread", 0.0)),
		},
		"stream": rain.duplicate(true) if not rain.is_empty() else {},
		"pocket": pocket,
		"nest": spec.get("nest", {"id": "nest", "name": "", "angle": 0.0, "distance": 9000}),
		"zones": spec.zones,
		"pdo": spec.pdo,
		"pirates": spec.get("pirates", {"count": 0, "angle": 0.0, "standoff": 0}),
		"haulers": spec.get("haulers", []),
		"gates": spec.get("gates", []),
	}


static func _layers(body: Dictionary) -> Dictionary:
	var name := str(body.get("name", "Body"))
	return {
		"orbit": "%s. %s" % [name, str(body.get("blurb", ""))],
		"atmosphere": "%s air: %s" % [name, str(body.get("air", "none"))],
		"surface": "%s surface: %s" % [name, str(body.get("face", ""))],
		"crust": "%s crust: %s" % [name, str(body.get("crust", ""))],
		"biosign": "%s life: %s" % [name, str(body.get("life", ""))],
		"ruins": "%s ruins: %s" % [name, str(body.get("ruins", ""))],
		"legal": str(body.get("legal", "")),
	}
