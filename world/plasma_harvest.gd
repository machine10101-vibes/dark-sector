class_name PlasmaHarvest
extends RefCounted

## Keel-mounted plasma gatherer. Right-click a rock, torn plate, or abandoned hull.


const HULKS := [
	["vesper", "Abandoned courier"],
	["anvil", "Cold hauler"],
	["skiff", "Dead skiff"],
	["cutter", "Quiet cutter"],
	["kestrel", "Broken beak"],
]


static func fresh_gather() -> Dictionary:
	return {
		"active": false,
		"target": "",
		"progress": 0.0,
		"age": 0.0,
		"flash": 0.0,
		"extend": 0.0,
		"aim_x": 1.0,
		"aim_y": 0.0,
	}


static func seed(sim) -> void:
	sim.nodes = []
	sim.belt_marks = []
	if not _ready(sim):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(sim.seed_value) + 901
	var data: Dictionary = sim.defs.harvest
	for belt in data.belts:
		_belt(sim, rng, belt)
	for field in data.fields:
		_field(sim, rng, field)
	_loose(sim, rng, int(data.get("loose", 0)))
	_derelicts(sim, rng, int(data.get("derelict_count", 0)))


static func engage(sim, pos: Vector2) -> String:
	if not _ready(sim) or not bool(sim.player.get("alive", false)):
		return "dead"
	var node := pick(sim, pos)
	if node.is_empty():
		if bool(sim.gather.get("active", false)):
			sim.gather.active = false
			sim.gather.target = ""
			sim.say("Plasma gatherer stowed.")
		return "none"
	if remaining(node) <= 0:
		return "empty"
	var reach := float(sim.defs.harvest.range)
	if sim.player.pos.distance_to(node.pos) > reach:
		sim.say("The plasma beam falls short of %s. Bring the keel closer." % node.name)
		return "far"
	if bool(sim.gather.get("active", false)) and str(sim.gather.get("target", "")) == str(node.id):
		return "ok"
	sim.gather.active = true
	sim.gather.target = str(node.id)
	sim.gather.progress = 0.0
	sim.gather.age = 0.0
	sim.say("Plasma gatherer locked on %s." % node.name)
	sim.sfx("plasma")
	return "ok"


static func fresh_works() -> Dictionary:
	return {
		"active": false,
		"kind": "",
		"id": "",
		"progress": 0.0,
		"seconds": 1.0,
		"waiting": false,
		"cost": {},
	}


static func step(sim, dt: float) -> void:
	_step_works(sim, dt)
	if typeof(sim.gather) != TYPE_DICTIONARY or sim.gather.is_empty() or not sim.gather.has("extend"):
		sim.gather = fresh_gather()
	var g: Dictionary = sim.gather
	var want := 1.0 if bool(g.active) else 0.0
	g.extend = move_toward(float(g.extend), want, dt * 3.6)
	g.flash = maxf(0.0, float(g.flash) - dt)
	g.age = float(g.age) + dt
	_slew_aim(sim, g, dt)
	sim.aim_id = ""
	if _ready(sim):
		var hovered := pick(sim, sim.aim)
		if not hovered.is_empty():
			sim.aim_id = str(hovered.id)
	if not bool(g.active):
		return
	if not bool(sim.player.get("alive", false)):
		g.active = false
		g.target = ""
		return
	var node := by_id(sim, str(g.target))
	if node.is_empty() or remaining(node) <= 0:
		g.active = false
		g.target = ""
		return
	var reach := float(sim.defs.harvest.range) * 1.12
	if sim.player.pos.distance_to(node.pos) > reach:
		g.active = false
		g.target = ""
		sim.say("The keel slipped the beam.")
		return
	var mat_id := next_yield(node)
	if mat_id == "":
		g.active = false
		g.target = ""
		return
	var hardness := float(sim.defs.harvest.materials[mat_id].get("hardness", 1.2))
	g.progress = float(g.progress) + dt / maxf(hardness, 0.2)
	if float(g.progress) < 1.0:
		return
	var stats := Fit.stats(sim.defs, sim.player)
	if Fit.cargo_used(sim.player) >= int(stats.cargo_cap):
		g.active = false
		g.progress = 0.0
		sim.say("Hold is full. The gatherer idles.")
		return
	node.loads[mat_id] = int(node.loads[mat_id]) - 1
	sim._add_cargo(mat_id, 1)
	g.progress = 0.0
	g.flash = 0.45
	sim.sfx("extract")
	var left := remaining(node)
	sim.say("%s aboard. %d left in %s." % [sim.resource_name(mat_id), left, node.name])
	if left <= 0:
		g.active = false
		g.target = ""
		sim.say("%s is cut to a husk." % node.name)


static func fabricate(sim, recipe_id: String) -> String:
	var held := _refuse_busy(sim)
	if held != "":
		return held
	var recipe := _recipe(sim, recipe_id)
	var blocked := _module_gate(sim, recipe, true)
	if blocked != "":
		return blocked
	if float(recipe.get("seconds", 0.0)) > 0.05:
		return start_works(sim, "module", recipe_id, float(recipe.seconds), recipe.cost)
	_pay(sim, recipe.cost)
	_apply_module(sim, recipe)
	return ""


static func start_refine(sim, mat_id: String) -> String:
	var held := _refuse_busy(sim)
	if held != "":
		return held
	var recipe := _synthetic(sim, mat_id)
	if recipe.is_empty():
		sim.say("The refinery has no pour by that name.")
		return "missing"
	var blocked := _stock_gate(sim, recipe.cost, 1)
	if blocked != "":
		return blocked
	return start_works(sim, "refine", mat_id, float(recipe.get("seconds", 5.0)), recipe.cost)


static func start_craft(sim, craft_id: String) -> String:
	var held := _refuse_busy(sim)
	if held != "":
		return held
	var recipe := _craft_recipe(sim, craft_id)
	if recipe.is_empty():
		sim.say("No boat by that drawing.")
		return "missing"
	var blocked := _craft_gate(sim, str(recipe.craft))
	if blocked != "":
		return blocked
	blocked = _stock_gate(sim, recipe.cost, 0)
	if blocked != "":
		return blocked
	return start_works(sim, "craft", str(recipe.craft), float(recipe.get("seconds", 8.0)), recipe.cost)


static func sell(sim, mat_id: String) -> String:
	if not _ready(sim) or not bool(sim.player.get("alive", false)):
		return "dead"
	if not PocketRules.in_pocket(sim):
		sim.say("The chandlery is at Hollow Latch. Bring the keel inside the pocket.")
		return "far"
	var price := price_of(sim, mat_id)
	if price <= 0:
		sim.say("The Latch will not buy %s." % sim.resource_name(mat_id))
		return "unsold"
	var have := int(sim.player.cargo.get(mat_id, 0))
	if have <= 0:
		return "empty"
	_take(sim, mat_id, have)
	sim.player.scrip = int(sim.player.get("scrip", 0)) + price * have
	sim.say("Latch paid %d scrip for %d %s. Purse is %d." % [price * have, have, sim.resource_name(mat_id), int(sim.player.scrip)])
	sim.sfx("dock")
	return ""


static func price_of(sim, mat_id: String) -> int:
	if not _ready(sim):
		return 0
	return int(sim.defs.harvest.get("prices", {}).get(mat_id, 0))


static func siphon(sim, node_id: String) -> String:
	var node := by_id(sim, node_id)
	if node.is_empty() or remaining(node) <= 0:
		return "empty"
	var stats := Fit.stats(sim.defs, sim.player)
	if Fit.cargo_used(sim.player) >= int(stats.cargo_cap):
		return "full"
	var mat_id := next_yield(node)
	if mat_id == "":
		return "empty"
	node.loads[mat_id] = int(node.loads[mat_id]) - 1
	sim._add_cargo(mat_id, 1)
	sim.say("%s aboard from %s." % [sim.resource_name(mat_id), node.name])
	sim.sfx("extract")
	return ""


static func hangar_free(sim) -> int:
	var cap := int(sim.defs.ships[sim.player.class_id].get("hangar", 4))
	var used := 0
	for item in sim.craft:
		if str(item.state) != "lost":
			used += 1
	return cap - used


static func lost_craft(sim, def_id: String) -> Dictionary:
	for item in sim.craft:
		if str(item.def_id) == def_id and str(item.state) == "lost":
			return item
	return {}


static func works_out(sim) -> Dictionary:
	var w: Dictionary = sim.works if typeof(sim.works) == TYPE_DICTIONARY else fresh_works()
	var cost: Dictionary = {}
	for key in w.get("cost", {}).keys():
		cost[str(key)] = int(w.cost[key])
	return {
		"active": bool(w.get("active", false)),
		"kind": str(w.get("kind", "")),
		"id": str(w.get("id", "")),
		"progress": float(w.get("progress", 0.0)),
		"seconds": float(w.get("seconds", 1.0)),
		"waiting": bool(w.get("waiting", false)),
		"cost": cost,
	}


static func works_in(raw) -> Dictionary:
	var w := fresh_works()
	if typeof(raw) != TYPE_DICTIONARY:
		return w
	w.active = bool(raw.get("active", false))
	w.kind = str(raw.get("kind", ""))
	w.id = str(raw.get("id", ""))
	w.progress = float(raw.get("progress", 0.0))
	w.seconds = maxf(float(raw.get("seconds", 1.0)), 0.2)
	w.waiting = bool(raw.get("waiting", false))
	var cost: Dictionary = {}
	for key in raw.get("cost", {}).keys():
		cost[str(key)] = int(raw.cost[key])
	w.cost = cost
	return w


static func spawn_battle_debris(sim, unit: Dictionary) -> void:
	if not _ready(sim):
		return
	var runtime := 0
	for node in sim.nodes:
		if bool(node.get("runtime", false)):
			runtime += 1
	if runtime >= 36:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(sim.time * 1000.0) + sim.wrecks.size() * 17 + 11
	var count := rng.randi_range(3, 4)
	for i in count:
		if runtime >= 36:
			break
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(26.0, 72.0)
		var pos: Vector2 = unit.pos + Vector2.from_angle(ang) * dist
		var loads := {"wreck_plate": rng.randi_range(1, 2)}
		if rng.randf() < 0.4:
			loads["iron"] = 1
		var node := _make(sim, "debris_%d_%d" % [sim.wrecks.size(), i], "wreckage", "Torn plate", "wreck_plate", loads, pos, rng)
		node.runtime = true
		node.belt = "battle"
		node.variant = i % 3
		BodyRender.bake(node)
		sim.nodes.append(node)
		runtime += 1


static func stock_out(sim) -> Dictionary:
	var out := {}
	for node in sim.nodes:
		if bool(node.get("runtime", false)):
			continue
		out[str(node.id)] = (node.loads as Dictionary).duplicate()
	return out


static func runtime_out(sim) -> Array:
	var rows: Array = []
	for node in sim.nodes:
		if not bool(node.get("runtime", false)):
			continue
		rows.append({
			"id": node.id,
			"kind": node.kind,
			"name": node.name,
			"material": node.material,
			"loads": (node.loads as Dictionary).duplicate(),
			"pos": Serde.vec_out(node.pos),
			"rot": float(node.rot),
			"spin": float(node.spin),
			"size": float(node.size),
			"seed": int(node.seed),
			"runtime": true,
			"class_id": str(node.get("class_id", "")),
			"belt": str(node.get("belt", "")),
			"variant": int(node.get("variant", 0)),
		})
	return rows


static func apply_stock(sim, saved) -> void:
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for node in sim.nodes:
		if not saved.has(node.id):
			continue
		var loads = saved[node.id]
		if typeof(loads) != TYPE_DICTIONARY:
			continue
		node.loads = {}
		for key in loads.keys():
			node.loads[str(key)] = int(loads[key])


static func restore_runtime(sim, rows) -> void:
	if typeof(rows) != TYPE_ARRAY:
		return
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = row.duplicate(true)
		node.pos = Serde.vec_in(node.pos)
		node.rot = float(node.get("rot", 0.0))
		node.spin = float(node.get("spin", 0.15))
		node.size = float(node.get("size", 18.0))
		node.seed = int(node.get("seed", 1))
		node.runtime = true
		node.variant = int(node.get("variant", 0))
		var loads: Dictionary = {}
		for key in node.get("loads", {}).keys():
			loads[str(key)] = int(node.loads[key])
		node.loads = loads
		BodyRender.bake(node)
		sim.nodes.append(node)


static func pick(sim, pos: Vector2) -> Dictionary:
	if not _ready(sim):
		return {}
	var extra := float(sim.defs.harvest.pick)
	var best: Dictionary = {}
	var best_d := 1.0e12
	for node in sim.nodes:
		if remaining(node) <= 0:
			continue
		var reach := float(node.size) + extra
		var dist := pos.distance_to(node.pos)
		if dist <= reach and dist < best_d:
			best = node
			best_d = dist
	return best


static func by_id(sim, id: String) -> Dictionary:
	for node in sim.nodes:
		if str(node.id) == id:
			return node
	return {}


static func remaining(node: Dictionary) -> int:
	var total := 0
	for key in node.get("loads", {}).keys():
		total += int(node.loads[key])
	return total


static func next_yield(node: Dictionary) -> String:
	var primary := str(node.get("material", ""))
	if int(node.get("loads", {}).get(primary, 0)) > 0:
		return primary
	for key in ["gold", "copper", "aluminum", "iron", "wreck_plate"]:
		if int(node.get("loads", {}).get(key, 0)) > 0:
			return key
	for key in node.get("loads", {}).keys():
		if int(node.loads[key]) > 0:
			return str(key)
	return ""


static func load_line(sim, node: Dictionary) -> String:
	var bits: PackedStringArray = PackedStringArray()
	var primary := str(node.get("material", ""))
	var loads: Dictionary = node.get("loads", {})
	if int(loads.get(primary, 0)) > 0:
		bits.append("%s ×%d" % [sim.resource_name(primary), int(loads[primary])])
	for key in ["gold", "copper", "aluminum", "iron", "wreck_plate"]:
		if key == primary:
			continue
		if int(loads.get(key, 0)) > 0:
			bits.append("%s ×%d" % [sim.resource_name(key), int(loads[key])])
	if bits.is_empty():
		return "husk"
	return ", ".join(bits)


static func material_of(sim, id: String) -> Dictionary:
	if not _ready(sim):
		return {}
	var mats: Dictionary = sim.defs.harvest.materials
	if mats.has(id):
		return mats[id]
	if mats.has("wreck_plate"):
		return mats.wreck_plate
	return {}


static func _slew_aim(sim, g: Dictionary, dt: float) -> void:
	var desired := Vector2.from_angle(float(sim.player.get("rot", 0.0)))
	if bool(g.active):
		var node := by_id(sim, str(g.target))
		if not node.is_empty():
			var housing := BodyRender.housing(sim, sim.player)
			var to: Vector2 = node.pos - housing
			if to.length() > 1.0:
				desired = to.normalized()
	var current := Vector2(float(g.get("aim_x", desired.x)), float(g.get("aim_y", desired.y)))
	if current.length() < 0.001:
		current = desired
	current = current.lerp(desired, clampf(dt * 7.0, 0.0, 1.0))
	if current.length() > 0.001:
		current = current.normalized()
	g.aim_x = current.x
	g.aim_y = current.y


static func _belt(sim, rng: RandomNumberGenerator, belt: Dictionary) -> void:
	var placed: Array = []
	var primary := _primary_mix(belt.mix)
	for i in 2:
		var loads := _giant_loads(rng, belt.mix, primary)
		var size := _size_for(rng, primary, _sum_loads(loads), "giant")
		var pos := _scatter_arc(sim, rng, belt, placed, size, maxf(90.0, size * 0.85))
		if pos == Vector2.INF:
			continue
		placed.append({"pos": pos, "reach": size})
		var node := _make(sim, "%s_giant_%d" % [belt.id, i], "meteor", _rock_name(sim, primary, "giant"), primary, loads, pos, rng, size)
		node.belt = str(belt.id)
		node.tier = "giant"
		sim.nodes.append(node)
	for i in int(belt.count):
		var tier := _tier(rng)
		var mat_id := _roll_mix(rng, belt.mix)
		var loads := _loads_for(rng, belt.mix, mat_id, tier)
		var size := _size_for(rng, mat_id, _sum_loads(loads), tier)
		var pos := _scatter_arc(sim, rng, belt, placed, size, 90.0)
		if pos == Vector2.INF:
			continue
		placed.append({"pos": pos, "reach": size})
		var node := _make(sim, "%s_%d" % [belt.id, i], "meteor", _rock_name(sim, mat_id, tier), mat_id, loads, pos, rng, size)
		node.belt = str(belt.id)
		node.tier = tier
		sim.nodes.append(node)
	if placed.is_empty():
		return
	var centroid := Vector2.ZERO
	for item in placed:
		var item_pos: Vector2 = item.pos
		centroid += item_pos
	centroid /= float(placed.size())
	sim.belt_marks.append({
		"name": str(belt.name),
		"pos": centroid,
		"material": primary,
	})


static func _field(sim, rng: RandomNumberGenerator, field: Dictionary) -> void:
	var origin := Vector2.from_angle(float(field.angle)) * float(field.distance)
	var placed: Array = []
	for i in int(field.count):
		var pos := Vector2.INF
		for _attempt in 8:
			var try_pos := origin + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * float(field.spread)
			if not _clear(sim, try_pos, 70.0):
				continue
			var crowded := false
			for other in placed:
				if try_pos.distance_to(other) < 36.0:
					crowded = true
					break
			if crowded:
				continue
			pos = try_pos
			break
		if pos == Vector2.INF:
			continue
		placed.append(pos)
		var loads := {"wreck_plate": rng.randi_range(1, 3)}
		if rng.randf() < 0.45:
			loads["iron"] = 1
		if rng.randf() < 0.2:
			loads["copper"] = 1
		var names := ["Torn plate", "Bent rib", "Hull shard"]
		var variant := i % 3
		var node := _make(sim, "%s_%d" % [field.id, i], "wreckage", names[variant], "wreck_plate", loads, pos, rng)
		node.belt = str(field.id)
		node.variant = variant
		BodyRender.bake(node)
		sim.nodes.append(node)
	if not placed.is_empty():
		sim.belt_marks.append({
			"name": str(field.name),
			"pos": origin,
			"material": "wreck_plate",
		})


static func _loose(sim, rng: RandomNumberGenerator, count: int) -> void:
	var mats := ["iron", "aluminum", "copper", "gold"]
	var made := 0
	var guard := 0
	while made < count and guard < count * 30:
		guard += 1
		var pos := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1500.0, 6100.0)
		if not _clear(sim, pos, 160.0):
			continue
		if _near_nodes(sim, pos, 180.0):
			continue
		var mat_id: String = mats[made % mats.size()]
		var tier := _tier(rng)
		var mix := {"iron": 1, "aluminum": 1, "copper": 1, "gold": 1}
		var loads := _loads_for(rng, mix, mat_id, tier)
		var size := _size_for(rng, mat_id, _sum_loads(loads), tier)
		var node := _make(sim, "loose_%d" % made, "meteor", _rock_name(sim, mat_id, tier), mat_id, loads, pos, rng, size)
		node.belt = "loose"
		node.tier = tier
		sim.nodes.append(node)
		made += 1


static func _derelicts(sim, rng: RandomNumberGenerator, count: int) -> void:
	var made := 0
	var guard := 0
	while made < count and guard < count * 40:
		guard += 1
		var pos := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1700.0, 6400.0)
		if not _clear(sim, pos, 220.0):
			continue
		if _near_kind(sim, pos, "derelict", 700.0):
			continue
		var spec: Array = HULKS[made % HULKS.size()]
		var loads := {
			"wreck_plate": rng.randi_range(2, 3),
			"iron": rng.randi_range(1, 2),
			"copper": 1,
		}
		if made == 0:
			loads["gold"] = 1
		var node := _make(sim, "derelict_%d" % made, "derelict", str(spec[1]), "wreck_plate", loads, pos, rng)
		node.class_id = str(spec[0])
		node.belt = "derelict"
		node.size = rng.randf_range(36.0, 48.0)
		node.spin = rng.randf_range(0.04, 0.12)
		BodyRender.bake(node)
		sim.nodes.append(node)
		made += 1


static func _make(sim, id: String, kind: String, node_name: String, material: String, loads: Dictionary, pos: Vector2, rng: RandomNumberGenerator, size_override: float = -1.0) -> Dictionary:
	var size := size_override
	if size <= 0.0:
		size = rng.randf_range(22.0, 44.0)
		if material == "gold":
			size = rng.randf_range(18.0, 32.0)
		if kind == "wreckage":
			size = rng.randf_range(16.0, 30.0)
	var node := {
		"id": id,
		"kind": kind,
		"name": node_name,
		"material": material,
		"loads": loads.duplicate(),
		"pos": pos,
		"rot": rng.randf() * TAU,
		"spin": rng.randf_range(0.08, 0.28) * (1.0 if rng.randf() > 0.5 else -1.0),
		"size": size,
		"seed": rng.randi(),
		"runtime": false,
		"class_id": "",
		"belt": "",
		"variant": 0,
	}
	BodyRender.bake(node)
	return node


static func _scatter_arc(sim, rng: RandomNumberGenerator, belt: Dictionary, placed: Array, reach: float, pad: float) -> Vector2:
	var center := float(belt.angle)
	var arc := float(belt.arc)
	var radius := float(belt.radius)
	var width := float(belt.width)
	for _attempt in 18:
		var ang := center + rng.randf_range(-arc * 0.5, arc * 0.5)
		var rad := radius + rng.randf_range(-width, width)
		var pos := Vector2.from_angle(ang) * rad
		if not _clear(sim, pos, pad):
			continue
		var crowded := false
		for other in placed:
			var other_pos: Vector2 = other.pos
			var other_reach: float = float(other.reach)
			if pos.distance_to(other_pos) < 1.05 * (reach + other_reach) + 8.0:
				crowded = true
				break
		if crowded:
			continue
		return pos
	return Vector2.INF


static func _clear(sim, pos: Vector2, pad: float) -> bool:
	if pos.length() < float(sim.defs.system.star.radius) + pad:
		return false
	for body in sim.planets:
		if pos.distance_to(body.pos) < float(body.radius) + pad:
			return false
	if pos.distance_to(sim.pocket_pos) < float(sim.defs.system.pocket.radius) + 80.0:
		return false
	if pos.distance_to(sim.nest_pos) < 260.0:
		return false
	return true


static func _near_nodes(sim, pos: Vector2, gap: float) -> bool:
	for node in sim.nodes:
		if pos.distance_to(node.pos) < gap:
			return true
	return false


static func _near_kind(sim, pos: Vector2, kind: String, gap: float) -> bool:
	for node in sim.nodes:
		if str(node.kind) == kind and pos.distance_to(node.pos) < gap:
			return true
	return false


static func _roll_mix(rng: RandomNumberGenerator, mix: Dictionary) -> String:
	var total := 0
	for key in mix.keys():
		total += int(mix[key])
	if total <= 0:
		return "iron"
	var roll := rng.randi_range(1, total)
	var acc := 0
	for key in mix.keys():
		acc += int(mix[key])
		if roll <= acc:
			return str(key)
	return str(mix.keys()[0])


static func _primary_mix(mix: Dictionary) -> String:
	var best := "iron"
	var best_n := -1
	for key in mix.keys():
		if int(mix[key]) > best_n:
			best_n = int(mix[key])
			best = str(key)
	return best


static func _tier(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if roll < 0.30:
		return "lean"
	if roll < 0.78:
		return "normal"
	return "rich"


static func _loads_for(rng: RandomNumberGenerator, mix: Dictionary, primary: String, tier: String) -> Dictionary:
	var n := 1
	if tier == "lean":
		n = 1 if primary == "gold" else rng.randi_range(1, 2)
	elif tier == "rich":
		n = rng.randi_range(2, 4) if primary == "gold" else rng.randi_range(6, 9)
	elif primary == "gold":
		n = rng.randi_range(1, 2)
	elif primary == "copper":
		n = rng.randi_range(2, 4)
	else:
		n = rng.randi_range(3, 5)
	var loads := {primary: n}
	var chance := 0.22
	if tier == "rich":
		chance = 0.62
	elif tier == "normal":
		chance = 0.38
	if rng.randf() < chance:
		var sec := _secondary_mix(mix, primary)
		if sec != "":
			var sn := 1
			if tier == "rich" and sec != "gold":
				sn = rng.randi_range(2, 4)
			elif tier == "normal" and sec != "gold":
				sn = rng.randi_range(1, 2)
			loads[sec] = sn
	return loads


static func _giant_loads(rng: RandomNumberGenerator, mix: Dictionary, primary: String) -> Dictionary:
	var n := rng.randi_range(6, 10) if primary == "gold" else rng.randi_range(10, 16)
	var loads := {primary: n}
	var sec := _secondary_mix(mix, primary)
	if sec != "":
		loads[sec] = rng.randi_range(2, 4) if sec == "gold" else rng.randi_range(3, 7)
	return loads


static func _sum_loads(loads: Dictionary) -> int:
	var total := 0
	for key in loads.keys():
		total += int(loads[key])
	return total


static func _size_for(rng: RandomNumberGenerator, material: String, total: int, tier: String) -> float:
	if tier == "giant":
		return rng.randf_range(86.0, 124.0)
	var base := 18.0 + float(total) * 3.6
	if material == "gold":
		base = maxf(base * 0.9, 26.0)
	return clampf(base + rng.randf_range(-2.5, 2.5), 16.0, 68.0)


static func _rock_name(sim, material: String, tier: String) -> String:
	var metal := str(sim.resource_name(material))
	if tier == "giant":
		return "Large %s asteroid" % metal
	if tier == "rich":
		return "Rich %s asteroid" % metal
	return "%s rock" % metal


static func _secondary_mix(mix: Dictionary, primary: String) -> String:
	var best := ""
	var best_n := -1
	for key in mix.keys():
		if str(key) == primary:
			continue
		if int(mix[key]) > best_n:
			best_n = int(mix[key])
			best = str(key)
	return best


static func _refuse_busy(sim) -> String:
	_ensure_works(sim)
	if bool(sim.works.get("active", false)):
		sim.say("The bay is already on a job.")
		return "busy"
	return ""


static func start_works(sim, kind: String, id: String, seconds: float, cost: Dictionary) -> String:
	var held := _refuse_busy(sim)
	if held != "":
		return held
	_pay(sim, cost)
	sim.works = {
		"active": true,
		"kind": kind,
		"id": id,
		"progress": 0.0,
		"seconds": maxf(seconds, 0.2),
		"waiting": false,
		"cost": cost.duplicate(),
	}
	match kind:
		"refine":
			sim.say("Refinery started. %s is in the crucible." % sim.resource_name(id))
		"craft":
			var boat := str(sim.defs.craft[id].name)
			sim.say("The bay is laying a %s." % boat)
		_:
			var recipe := _recipe(sim, id)
			var mod: Dictionary = sim.defs.modules.get(str(recipe.get("module", "")), {})
			sim.say("Fabricator started on %s." % str(mod.get("name", id)))
	sim.sfx("install")
	return ""


static func _step_works(sim, dt: float) -> void:
	_ensure_works(sim)
	var w: Dictionary = sim.works
	if not bool(w.active):
		return
	if str(w.kind) == "refine":
		var stats := Fit.stats(sim.defs, sim.player)
		if Fit.cargo_used(sim.player) >= int(stats.cargo_cap):
			w.progress = minf(float(w.progress), float(w.seconds) - 0.05)
			if not bool(w.waiting):
				w.waiting = true
				sim.say("Hold is full. The refinery holds the pour.")
			return
	w.waiting = false
	w.progress = float(w.progress) + dt
	if float(w.progress) < float(w.seconds):
		return
	var kind := str(w.kind)
	var id := str(w.id)
	var cost: Dictionary = (w.cost as Dictionary).duplicate()
	w.active = false
	w.progress = float(w.seconds)
	var err := _finish_works(sim, kind, id)
	if err != "":
		_refund(sim, cost)
		sim.say("The bay put the stock back.")


static func _finish_works(sim, kind: String, id: String) -> String:
	if kind == "refine":
		sim._add_cargo(id, 1)
		sim.say("%s is cool enough to rack." % sim.resource_name(id))
		sim.sfx("extract")
		return ""
	if kind == "craft":
		return _berth(sim, id)
	var recipe := _recipe(sim, id)
	var blocked := _module_gate(sim, recipe, false)
	if blocked != "":
		return blocked
	_apply_module(sim, recipe)
	return ""


static func _module_gate(sim, recipe: Dictionary, check_cost: bool) -> String:
	if not _ready(sim):
		return "The fabricator has no drawings."
	if recipe.is_empty():
		sim.say("No drawing by that name.")
		return "missing"
	var module_id := str(recipe.get("module", ""))
	var mod: Dictionary = sim.defs.modules.get(module_id, {})
	if mod.is_empty():
		sim.say("That drawing has no part.")
		return "missing"
	if sim.player.modules.has(module_id):
		sim.say("%s is already on the keel." % mod.name)
		return "have"
	var slot := str(mod.get("slot", "Utility"))
	if Fit.free_slots(sim.defs, sim.player).find(slot) < 0:
		sim.say("No free %s hardpoint." % slot)
		return "slot"
	if check_cost:
		var cost: Dictionary = recipe.get("cost", {})
		for mat_id in cost.keys():
			if int(sim.player.cargo.get(mat_id, 0)) < int(cost[mat_id]):
				sim.say("Short %s. The drawing wants %d." % [sim.resource_name(str(mat_id)), int(cost[mat_id])])
				return "cost"
	var before := Fit.stats(sim.defs, sim.player)
	var hypo: Dictionary = sim.player.duplicate(true)
	hypo.modules = sim.player.modules.duplicate()
	hypo.modules.append(module_id)
	var after := Fit.stats(sim.defs, hypo)
	if float(after.power_spare) < -0.01:
		sim.say("Reactor spare is %.0f. %s wants more than the bus can feed." % [before.power_spare, mod.name])
		return "power"
	return ""


static func _apply_module(sim, recipe: Dictionary) -> void:
	var module_id := str(recipe.module)
	var mod: Dictionary = sim.defs.modules[module_id]
	var before := Fit.stats(sim.defs, sim.player)
	var hp_before := int(before.hp_max)
	sim.player.modules.append(module_id)
	var after := Fit.stats(sim.defs, sim.player)
	var gain := int(after.hp_max) - hp_before
	sim.player.max_hp = int(after.hp_max)
	sim.player.hp = minf(float(sim.player.hp) + float(gain), float(sim.player.max_hp))
	var spent := _cost_line(sim, recipe.get("cost", {}))
	var keel := ""
	if bool(after.keel_warn):
		keel = " The keel complains under the new mass."
	sim.say("%s is on the keel, from %s. Yaw %.0f°/s → %.0f°/s.%s" % [mod.name, spent, before.yaw_deg, after.yaw_deg, keel])
	sim.sfx("install")


static func _stock_gate(sim, cost: Dictionary, extra_out: int) -> String:
	for mat_id in cost.keys():
		if int(sim.player.cargo.get(mat_id, 0)) < int(cost[mat_id]):
			sim.say("Short %s. The drawing wants %d." % [sim.resource_name(str(mat_id)), int(cost[mat_id])])
			return "cost"
	var take_n := 0
	for mat_id in cost.keys():
		take_n += int(cost[mat_id])
	var cap := int(Fit.stats(sim.defs, sim.player).cargo_cap)
	if Fit.cargo_used(sim.player) - take_n + extra_out > cap:
		sim.say("Hold is full. Make room before the pour.")
		return "full"
	return ""


static func _craft_gate(sim, def_id: String) -> String:
	if not sim.defs.craft.has(def_id):
		sim.say("No boat by that drawing.")
		return "missing"
	if lost_craft(sim, def_id).is_empty() and hangar_free(sim) <= 0:
		sim.say("Hangar is full. A lost boat can still be rebuilt.")
		return "full"
	return ""


static func _berth(sim, def_id: String) -> String:
	var blocked := _craft_gate(sim, def_id)
	if blocked != "":
		return blocked
	var lost := lost_craft(sim, def_id)
	if not lost.is_empty():
		lost.state = "docked"
		lost.hp = float(lost.max_hp)
		lost.battery = float(lost.max_battery)
		lost.pos = sim.player.pos
		lost.vel = Vector2.ZERO
		lost.target = ""
		lost.did_job = false
		sim.say("%s is rebuilt and back on the rack." % lost.name)
		sim.sfx("install")
		return ""
	var index := 1
	for item in sim.craft:
		if str(item.def_id) == def_id:
			index += 1
	var craft: Dictionary = sim._make_craft(def_id, index)
	craft.pos = sim.player.pos
	sim.craft.append(craft)
	sim.say("%s is on the rack." % craft.name)
	sim.sfx("launch")
	return ""


static func _pay(sim, cost: Dictionary) -> void:
	for mat_id in cost.keys():
		_take(sim, str(mat_id), int(cost[mat_id]))


static func _refund(sim, cost: Dictionary) -> void:
	for mat_id in cost.keys():
		sim._add_cargo(str(mat_id), int(cost[mat_id]))


static func _ensure_works(sim) -> void:
	if typeof(sim.works) != TYPE_DICTIONARY or (sim.works as Dictionary).is_empty() or not (sim.works as Dictionary).has("active"):
		sim.works = fresh_works()


static func _synthetic(sim, mat_id: String) -> Dictionary:
	if not _ready(sim):
		return {}
	for recipe in sim.defs.harvest.get("synthetics", []):
		if str(recipe.id) == mat_id:
			return recipe
	return {}


static func _craft_recipe(sim, craft_id: String) -> Dictionary:
	if not _ready(sim):
		return {}
	for recipe in sim.defs.harvest.get("craft_recipes", []):
		if str(recipe.id) == craft_id or str(recipe.craft) == craft_id:
			return recipe
	return {}


static func _recipe(sim, recipe_id: String) -> Dictionary:
	for recipe in sim.defs.harvest.recipes:
		if str(recipe.id) == recipe_id or str(recipe.module) == recipe_id:
			return recipe
	return {}


static func _take(sim, id: String, count: int) -> void:
	var left := int(sim.player.cargo.get(id, 0)) - count
	if left <= 0:
		sim.player.cargo.erase(id)
	else:
		sim.player.cargo[id] = left


static func _cost_line(sim, cost: Dictionary) -> String:
	var bits: Array = []
	for id in cost.keys():
		bits.append("%d %s" % [int(cost[id]), sim.resource_name(str(id))])
	return ", ".join(bits)


static func _ready(sim) -> bool:
	return sim != null and sim.defs.has("harvest") and not (sim.defs.harvest as Dictionary).is_empty() and (sim.defs.harvest as Dictionary).has("materials")
