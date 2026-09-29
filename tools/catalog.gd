class_name Catalog
extends RefCounted

## Loads drop-folder defs. A bad file is logged and skipped. The host keeps flying.

static var errors: Array = []


static func boot() -> Dictionary:
	errors = []
	var defs := _baseline()
	_fill(defs)
	defs.live_catalog = true
	return defs


static func refresh(defs: Dictionary) -> void:
	if not bool(defs.get("live_catalog", false)):
		return
	_fill(defs)


static func reload(sim) -> String:
	refresh(sim.defs)
	var sid := str(sim.defs.system.id)
	if sim.defs.systems.has(sid):
		sim.defs.system = sim.defs.systems[sid]
		sim._build_static()
		sim._spawn_factions()
	arm_yards(sim)
	var note := "Data reloaded. %d file(s) skipped." % errors.size()
	sim.say(note)
	return note


static func arm_yards(sim) -> void:
	if not bool(sim.defs.get("live_catalog", false)):
		return
	var yard: Array = sim.player.yard
	for module_id in sim.defs.get("dropped_modules", []):
		var mid := str(module_id)
		if yard.has(mid) or sim.player.modules.has(mid):
			continue
		yard.append(mid)


static func spawn(sim, system_id: String) -> String:
	var chart: Dictionary = sim.defs.get("systems", {})
	if not chart.has(system_id):
		return "No system %s on the board." % system_id
	var row: Dictionary = chart[system_id]
	var gate_id := ""
	var gates: Array = row.get("gates", [])
	if not gates.is_empty():
		gate_id = str(gates[0].get("id", ""))
	sim._arrive(system_id, gate_id)
	return "Spawned %s." % str(sim.defs.system.name)


static func grant(sim, kind: String, id: String) -> String:
	if kind == "module":
		if not sim.defs.modules.has(id):
			return "No module %s." % id
		if not sim.player.yard.has(id):
			sim.player.yard.append(id)
		var result: Dictionary = sim.install(id)
		return str(result.reason)
	if kind == "crop":
		return Homestead.sow(sim, id)
	if kind == "animal":
		if int(sim.player.cargo.get("food_mass", 0)) < 1 and int(sim.claim.get("crate", {}).get("food", 0)) < 1:
			sim._add_cargo("food_mass", 1)
		return Homestead.stock(sim, id)
	if kind == "flag":
		if id.ends_with("_standing") or id == "glass_standing":
			sim.quest_flags[id] = 1
		else:
			sim.quest_flags[id] = true
		sim.say("Flag %s is set." % id)
		return "Flag %s is set." % id
	return "Unknown grant."


static func describe(sim) -> String:
	var sys: Dictionary = sim.defs.system
	var filed := str(sys.get("law_color", ""))
	var live := Law.at(sim, sim.player.pos)
	var why := str(sys.get("why_visit", ""))
	var line := "%s — file %s, here %s. %s" % [str(sys.name), filed, live, why]
	sim.say(line)
	return line


static func confiscate(sim) -> void:
	var gate: Dictionary = sim.defs.system.get("checkpoint", {})
	if gate.is_empty():
		return
	var standing := str(gate.get("standing", ""))
	if standing != "" and int(sim.quest_flags.get(standing, 0)) > 0:
		sim.say("The checkpoint reads %s. The hold passes." % standing)
		return
	var taken := false
	for key in gate.get("living_cargo", []):
		var cargo_id := str(key)
		if int(sim.player.cargo.get(cargo_id, 0)) > 0:
			sim.player.cargo[cargo_id] = 0
			taken = true
	if bool(sim.player.get("kine_aboard", false)):
		sim.player.kine_aboard = false
		if sim.claim.has("pen") and sim.claim.pen is Dictionary:
			sim.claim.pen.aboard = false
		taken = true
	if taken:
		sim.say(str(gate.get("line", "The checkpoint takes living cargo.")))


static func _baseline() -> Dictionary:
	var helion: Dictionary = Serde.load_json("res://data/system.json")
	var soil: Dictionary = Serde.load_json("res://data/first_soil.json")
	var chart := {
		str(helion.id): helion,
		str(soil.id): soil,
	}
	var density: Dictionary = Serde.load_json("res://data/density.json")
	for spec in density.get("systems", []):
		if typeof(spec) != TYPE_DICTIONARY:
			continue
		var built: Dictionary = Chart.expand(spec)
		chart[str(built.id)] = built
	return {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": helion,
		"systems": chart,
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
		"crops": {},
		"animals": {},
		"templates": {},
		"dropped_modules": [],
	}


static func _fill(defs: Dictionary) -> void:
	_overlay_modules(defs)
	_overlay_named(defs, "res://craft", "craft", _craft_error)
	_overlay_named(defs, "res://factions", "factions", _faction_error)
	_overlay_book(defs, "res://life/crops", "crops", _crop_error)
	_overlay_book(defs, "res://life/animals", "animals", _animal_error)
	_overlay_quests(defs)
	_overlay_templates(defs)
	_overlay_systems(defs)
	_load_indexes(defs)
	_stamp(defs)


static func _overlay_modules(defs: Dictionary) -> void:
	var dropped: Array = []
	for path in _json_files("res://modules"):
		var spec = _read(path)
		if spec == null:
			continue
		var why := _module_error(spec)
		if why != "":
			_skip(path, why)
			continue
		var mid := str(spec.id)
		defs.modules[mid] = spec
		dropped.append(mid)
	defs.dropped_modules = dropped


static func _overlay_named(defs: Dictionary, folder: String, key: String, check: Callable) -> void:
	if not defs.has(key) or typeof(defs[key]) != TYPE_DICTIONARY:
		defs[key] = {}
	var book: Dictionary = defs[key]
	for path in _json_files(folder):
		var spec = _read(path)
		if spec == null:
			continue
		var why: String = check.call(spec)
		if why != "":
			_skip(path, why)
			continue
		book[str(spec.id)] = spec


static func _overlay_book(defs: Dictionary, folder: String, key: String, check: Callable) -> void:
	var book := {}
	for path in _json_files(folder):
		var spec = _read(path)
		if spec == null:
			continue
		var why: String = check.call(spec)
		if why != "":
			_skip(path, why)
			continue
		book[str(spec.id)] = spec
	defs[key] = book


static func _overlay_quests(defs: Dictionary) -> void:
	if typeof(defs.quests) != TYPE_DICTIONARY:
		defs.quests = {}
	for path in _json_files("res://quests/authored"):
		var spec = _read(path)
		if spec == null:
			continue
		var why := _quest_error(spec)
		if why != "":
			_skip(path, why)
			continue
		defs.quests[str(spec.id)] = spec


static func _overlay_templates(defs: Dictionary) -> void:
	var book := {}
	for path in _json_files("res://quests/templates"):
		var spec = _read(path)
		if spec == null:
			continue
		var why := _template_error(spec)
		if why != "":
			_skip(path, why)
			continue
		book[str(spec.id)] = spec
	defs.templates = book


static func _overlay_systems(defs: Dictionary) -> void:
	var chart: Dictionary = defs.systems
	for path in _json_files("res://world/hc_v1/systems"):
		var file_name := str(path).get_file()
		if file_name == "_template.json":
			continue
		var spec = _read(path)
		if spec == null:
			continue
		var why := _system_error(spec)
		if why == "template":
			continue
		if why != "":
			_skip(path, why)
			continue
		var built: Dictionary = Chart.expand(spec)
		if spec.has("checkpoint"):
			built["checkpoint"] = spec.checkpoint
		built["flagship"] = str(spec.get("flagship", ""))
		built["status"] = str(spec.get("status", "authored"))
		chart[str(built.id)] = built


static func _load_indexes(defs: Dictionary) -> void:
	var lanes = _read("res://world/hc_v1/lanes.json")
	if lanes == null:
		defs.lanes = {"lanes": []}
	else:
		defs.lanes = lanes
	var streams = _read("res://world/hc_v1/streams.json")
	if streams == null:
		defs.streams = {"streams": []}
	else:
		defs.streams = streams
	var origins = _read("res://world/hc_v1/trash_origins.json")
	if origins == null:
		defs.trash_origins = {"origins": []}
	else:
		defs.trash_origins = origins
	var slots = _read("res://world/hc_v1/claim_slots.json")
	if slots != null and str(slots.get("status", "")) != "template":
		defs.claim_slots = slots


static func _stamp(defs: Dictionary) -> void:
	var book: Dictionary = defs.get("lanes", {})
	var lanes: Array = book.get("lanes", [])
	var chart: Dictionary = defs.systems
	for raw in lanes:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = raw
		var origin := str(lane.get("from", ""))
		var dest := str(lane.get("to", ""))
		if not chart.has(origin) or not chart.has(dest):
			continue
		var color := str(lane.get("rule_color", "amber"))
		if color == "mixed":
			color = "amber"
		var lane_id := str(lane.get("id", "%s-%s" % [origin, dest]))
		_ensure_gate(chart[origin], lane_id, dest, chart[dest], color, true)
		_ensure_gate(chart[dest], lane_id, origin, chart[origin], color, false)


static func _ensure_gate(system: Dictionary, lane_id: String, dest: String, other: Dictionary, color: String, outbound: bool) -> void:
	var gates: Array = system.get("gates", [])
	var gate_id := "%s-out" % lane_id if outbound else "%s-in" % lane_id
	var arrive := "%s-in" % lane_id if outbound else "%s-out" % lane_id
	for row in gates:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str(row.get("to", "")) == dest or str(row.get("id", "")) == gate_id:
			return
	var anchor := ""
	var planets: Array = system.get("planets", [])
	if not planets.is_empty() and typeof(planets[0]) == TYPE_DICTIONARY:
		anchor = str(planets[0].get("id", ""))
	var n := gates.size()
	gates.append({
		"id": gate_id,
		"name": str(other.get("name", dest)),
		"to": dest,
		"arrive": arrive,
		"anchor": anchor,
		"angle": 0.45 + float(n) * 0.62,
		"distance": 1500.0 + float(n) * 48.0,
		"radius": 90.0,
		"color": color,
	})
	system.gates = gates


static func _json_files(folder: String) -> Array:
	var names := DirAccess.get_files_at(folder)
	var out: Array = []
	for name in names:
		var file_name := str(name)
		if file_name.ends_with(".json"):
			out.append(folder.path_join(file_name))
	out.sort()
	return out


static func _read(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_skip(path, "file could not be opened")
		return null
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		_skip(path, "JSON parse failed")
		return null
	if typeof(parsed) != TYPE_DICTIONARY:
		_skip(path, "def must be a JSON object")
		return null
	return parsed


static func _skip(path: String, why: String) -> void:
	var line := "skipped %s: %s" % [path, why]
	errors.append(line)
	push_error("Dark Sector %s" % line)


static func _generic_name(name: String) -> bool:
	var n := name.strip_edges().to_lower()
	if n == "" or n == "untitled" or n == "belt" or n == "asteroid belt" or n == "planet" or n == "rock":
		return true
	if n.contains("meteor field") or n.contains("untitled"):
		return true
	if n.begins_with("planet ") and n.substr(7).strip_edges().is_valid_int():
		return true
	if n.begins_with("rock-"):
		return true
	return false


static func _mutation_error(mutations: Array) -> String:
	for item in mutations:
		var text := str(item).to_lower()
		if text.contains("xp"):
			return "mutation %s is isolated XP" % str(item)
	return ""


static func _module_error(spec: Dictionary) -> String:
	if str(spec.get("id", "")) == "" or str(spec.get("name", "")) == "":
		return "module needs an id and a name"
	if _generic_name(str(spec.name)):
		return "module name is generic"
	if not spec.has("mass") or not spec.has("power"):
		return "module needs mass and power"
	var layer: Array = spec.get("layer", [])
	if layer.is_empty():
		return "module needs a layer silhouette"
	for poly in layer:
		if typeof(poly) != TYPE_ARRAY or poly.size() < 3:
			return "a layer polygon needs three points"
		for pt in poly:
			if typeof(pt) != TYPE_ARRAY or pt.size() < 2:
				return "a layer point needs x and y"
	return ""


static func _craft_error(spec: Dictionary) -> String:
	if str(spec.get("id", "")) == "" or str(spec.get("name", "")) == "" or str(spec.get("job", "")) == "":
		return "craft needs id, name, and job"
	return ""


static func _faction_error(spec: Dictionary) -> String:
	if str(spec.get("id", "")) == "" or str(spec.get("name", "")) == "":
		return "faction needs an id and a name"
	return ""


static func _crop_error(spec: Dictionary) -> String:
	if str(spec.get("id", "")) == "" or str(spec.get("name", "")) == "":
		return "crop needs an id and a name"
	if str(spec.get("dies_if", "")) == "" or str(spec.get("yield", "")) == "":
		return "crop needs dies_if and yield"
	return ""


static func _animal_error(spec: Dictionary) -> String:
	if str(spec.get("id", "")) == "" or str(spec.get("name", "")) == "":
		return "animal needs an id and a name"
	if str(spec.get("dies_if", "")) == "" or str(spec.get("yield", "")) == "":
		return "animal needs dies_if and yield"
	return ""


static func _quest_error(spec: Dictionary) -> String:
	if str(spec.get("id", "")) == "" or str(spec.get("title", "")) == "":
		return "quest needs an id and a title"
	var has_route: bool = spec.has("route") and typeof(spec.get("route", null)) == TYPE_ARRAY and not (spec.get("route", []) as Array).is_empty()
	var has_body: bool = str(spec.get("body", "")) != ""
	if not has_route and not has_body:
		return "quest needs a route or a body"
	var mutations: Array = spec.get("mutations", [])
	if typeof(spec.get("mutations", [])) != TYPE_ARRAY:
		return "mutations must be a list"
	return _mutation_error(mutations)


static func _template_error(spec: Dictionary) -> String:
	if str(spec.get("id", "")) == "" or str(spec.get("title", "")) == "":
		return "template needs an id and a title"
	var uses := str(spec.get("uses", ""))
	if uses != "streams" and uses != "trash":
		return "template must use streams or trash"
	var success: Array = spec.get("success_mutations", [])
	if typeof(spec.get("success_mutations", [])) != TYPE_ARRAY:
		return "success_mutations must be a list"
	return _mutation_error(success)


static func _system_error(spec: Dictionary) -> String:
	if str(spec.get("status", "")) == "template":
		return "template"
	var id := str(spec.get("id", ""))
	if id == "" or not id.begins_with("HC-V1-R"):
		return "missing HC-V1 id"
	var sys_name := str(spec.get("name", ""))
	if sys_name == "" or _generic_name(sys_name):
		return "system name is empty or generic"
	var why := str(spec.get("why_visit", ""))
	if why.length() < 12 or not why.contains("."):
		return "why_visit must be one sentence"
	var law := str(spec.get("law_color", ""))
	if not ["green", "amber", "red"].has(law):
		return "law_color %s is not green, amber, or red" % law
	var star = spec.get("star", {})
	if typeof(star) != TYPE_DICTIONARY or str(star.get("name", "")) == "" or _generic_name(str(star.get("name", ""))):
		return "star needs a real name"
	var bodies = spec.get("bodies", [])
	if typeof(bodies) != TYPE_ARRAY or bodies.is_empty():
		return "needs at least one body"
	var ring := false
	for raw in bodies:
		if typeof(raw) != TYPE_DICTIONARY:
			return "a body is not an object"
		var body: Dictionary = raw
		var body_name := str(body.get("name", ""))
		if body_name == "" or _generic_name(body_name):
			return "body name is empty or generic"
		if str(body.get("id", "")) == "":
			return "body %s missing id" % body_name
		if str(body.get("legal", "")) == "":
			return "body %s missing a legal title" % body_name
		if not body.has("angle") or not body.has("distance") or not body.has("radius"):
			return "body %s missing orbit numbers" % body_name
		if bool(body.get("ring", false)):
			ring = true
	var belt = spec.get("belt", {})
	var has_belt := false
	if typeof(belt) == TYPE_DICTIONARY and int(belt.get("count", 0)) > 0:
		var composition := str(belt.get("composition", ""))
		if composition == "":
			return "belt needs a composition"
		if composition.to_lower().contains("asteroid belt") or _generic_name(str(belt.get("name", ""))):
			return "belt is generic"
		has_belt = true
	var field = spec.get("trash", {})
	var has_trash := typeof(field) == TYPE_DICTIONARY and int(field.get("count", 0)) > 0 and str(field.get("origin", "")) != ""
	var rain = spec.get("stream", {})
	var has_stream := typeof(rain) == TYPE_DICTIONARY and str(rain.get("id", "")) != ""
	if not has_belt and not ring:
		return "needs a belt or a ring"
	if not has_trash and not has_stream:
		return "needs trash with an origin or a stream"
	if typeof(spec.get("pdo", null)) != TYPE_DICTIONARY or typeof(spec.get("zones", null)) != TYPE_DICTIONARY:
		return "needs pdo and zones"
	var living := int(spec.get("pdo", {}).get("count", 0)) > 0 or int(spec.get("pirates", {}).get("count", 0)) > 0 or not (spec.get("haulers", []) as Array).is_empty()
	if not living:
		return "needs one living use"
	return ""
