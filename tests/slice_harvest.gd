extends SceneTree

var defs: Dictionary = {}
var fails := 0


func _init() -> void:
	defs = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": Serde.load_json("res://data/system.json"),
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
		"claim": Serde.load_json("res://data/claim.json"),
		"harvest": Serde.load_json("res://data/harvest.json"),
	}
	_field()
	_beam()
	_wreckage()
	_fabricate()
	_roundtrip()
	_industry()
	_clutter()
	if fails == 0:
		print("HARVEST PASS")
	else:
		print("HARVEST FAIL %d" % fails)
	quit(fails)


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func make(class_id: String = "vesper") -> SectorSim:
	var sim := SectorSim.new(defs)
	sim.new_game(class_id)
	sim.hold_npc = true
	return sim


func _field() -> void:
	var sim := make()
	var other := make()
	check(sim.nodes.size() > 80, "the Reach is seeded with harvest nodes (%d)" % sim.nodes.size())
	check(_count_belt(sim, "rust_arc") >= 24, "Rust Arc is a large iron belt")
	check(_count_belt(sim, "pale_shelf") >= 20, "Pale Shelf is a large aluminum belt")
	check(_count_belt(sim, "copper_vein") >= 18, "Copper Vein is a large copper belt")
	check(_count_belt(sim, "kings_drift") >= 10, "King's Drift is a gold belt")
	check(_spread(sim, "rust_arc") > 280.0, "Rust Arc has radial width")
	check(_kind(sim, "wreckage") >= 16, "battlefields of torn plate are placed")
	check(_kind(sim, "derelict") >= 5, "abandoned hulls are placed")
	for mat_id in ["iron", "aluminum", "copper", "gold", "wreck_plate"]:
		check(_has_material(sim, mat_id), "%s can be found" % mat_id)
	var rich := false
	var classed := true
	for node in sim.nodes:
		if str(node.kind) != "derelict":
			continue
		if int(node.loads.get("gold", 0)) > 0:
			rich = true
		if str(node.class_id) == "":
			classed = false
	check(classed, "abandoned hulls keep a class")
	check(rich, "one abandoned hull still carries gold")
	check(sim.belt_marks.size() >= 6, "belts and graves are named")
	var first: Dictionary = sim.nodes[0]
	var again: Dictionary = other.nodes[0]
	check(str(first.id) == str(again.id) and first.pos.distance_to(again.pos) < 0.01, "belt placement is seeded")
	var buried := ""
	for node in sim.nodes:
		if node.pos.length() < float(sim.defs.system.star.radius):
			buried = str(node.id)
			break
		for body in sim.planets:
			if node.pos.distance_to(body.pos) < float(body.radius):
				buried = str(node.id)
				break
		if buried != "":
			break
	check(buried == "", "harvest nodes sit off the crust (%s)" % buried)
	var min_stock := 999
	var max_stock := 0
	var mixed := 0
	var giants := 0
	var saw_iron := false
	var saw_copper := false
	for node in sim.nodes:
		if str(node.kind) != "meteor":
			continue
		var stock := PlasmaHarvest.remaining(node)
		min_stock = mini(min_stock, stock)
		max_stock = maxi(max_stock, stock)
		var metals := 0
		for key in ["iron", "aluminum", "copper", "gold"]:
			if int(node.loads.get(key, 0)) > 0:
				metals += 1
		if metals >= 2:
			mixed += 1
		if float(node.size) > 70.0:
			giants += 1
		for feature in node.visual.get("ore", []):
			if str(feature.mat) == "iron":
				saw_iron = true
			if str(feature.mat) == "copper":
				saw_copper = true
	check(max_stock >= min_stock + 4, "some meteors carry more ore than others (%d..%d)" % [min_stock, max_stock])
	check(mixed >= 8, "meteors can hold more than one metal (%d)" % mixed)
	check(giants >= 6, "large asteroids float in the belts (%d)" % giants)
	check(saw_iron and saw_copper, "iron and copper are baked onto the stone")
	var bare := Silhouette.extent(Silhouette.parts("vesper", []))
	var coil := Silhouette.extent(Silhouette.parts("vesper", ["coil"]))
	var plate := Silhouette.extent(Silhouette.parts("vesper", ["plate"]))
	check(coil.x > bare.x + 20.0, "coil cannon lengthens the nose")
	check(plate.y > bare.y + 8.0, "plated armor widens the keel")


func _beam() -> void:
	var sim := make()
	var rock := _first(sim, "iron", "meteor")
	check(not rock.is_empty(), "an iron rock exists to cut")
	var before := int(rock.loads.iron)
	sim.player.pos = rock.pos + Vector2(900, 0)
	sim.player.vel = Vector2.ZERO
	check(PlasmaHarvest.engage(sim, rock.pos) == "far", "beam falls short outside range")
	check(int(rock.loads.iron) == before, "a short beam takes nothing")
	sim.player.pos = rock.pos + Vector2(180, 0)
	check(PlasmaHarvest.engage(sim, rock.pos) == "ok", "right-click range locks the gatherer")
	check(bool(sim.gather.active), "plasma gatherer is active")
	var guard := 0
	while int(sim.player.cargo.get("iron", 0)) < 1 and guard < 200:
		sim.tick(0.05, {})
		guard += 1
	check(int(sim.player.cargo.get("iron", 0)) >= 1, "iron comes aboard (%d ticks)" % guard)
	check(int(rock.loads.get("iron", 0)) == before - 1, "the rock depletes")
	check(float(sim.gather.extend) > 0.2, "the gatherer barrel extends")
	sim.player.cargo.clear()
	var cap := int(Fit.stats(defs, sim.player).cargo_cap)
	sim.player.cargo["scrap"] = cap
	var stock := PlasmaHarvest.remaining(rock)
	var locked := PlasmaHarvest.engage(sim, rock.pos)
	check(locked == "ok" or bool(sim.gather.active) or stock <= 0, "gatherer can be aimed at a remaining rock")
	if stock > 0:
		for _i in 80:
			sim.tick(0.05, {})
		check(PlasmaHarvest.remaining(rock) == stock, "a full hold stops the beam")
		check(int(sim.player.cargo.get("iron", 0)) == 0, "full hold does not smuggle ore")


func _wreckage() -> void:
	var sim := make()
	var pirate := {}
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			pirate = actor
			break
	pirate.hp = 1.0
	var wreck_at: Vector2 = pirate.pos
	sim.damage_unit(pirate, 8.0, sim.player.agent_id)
	check(not bool(pirate.alive), "the skiff dies into a wreck")
	var debris := 0
	var plate: Dictionary = {}
	for node in sim.nodes:
		if str(node.belt) == "battle" and node.pos.distance_to(wreck_at) < 120.0:
			debris += 1
			if plate.is_empty() and int(node.loads.get("wreck_plate", 0)) > 0:
				plate = node
	check(debris >= 3, "battle-torn plates burst from the kill")
	check(not plate.is_empty(), "a torn plate can be harvested")
	sim.player.pos = plate.pos + Vector2(80, 0)
	sim.player.vel = Vector2.ZERO
	sim.player.cargo.clear()
	check(PlasmaHarvest.engage(sim, plate.pos) == "ok", "right-click locks onto torn plate")
	var guard := 0
	while int(sim.player.cargo.get("wreck_plate", 0)) < 1 and guard < 200:
		sim.tick(0.05, {})
		guard += 1
	check(int(sim.player.cargo.get("wreck_plate", 0)) >= 1, "wreck plate comes aboard")
	var hulk := _kind_node(sim, "derelict")
	sim.player.pos = hulk.pos + Vector2(100, 0)
	sim.player.cargo.clear()
	var hulk_before := PlasmaHarvest.remaining(hulk)
	check(PlasmaHarvest.engage(sim, hulk.pos) == "ok", "abandoned hull accepts the beam")
	guard = 0
	while PlasmaHarvest.remaining(hulk) >= hulk_before and guard < 200:
		sim.tick(0.05, {})
		guard += 1
	check(PlasmaHarvest.remaining(hulk) < hulk_before, "abandoned hull yields into the hold")
	check(Fit.cargo_used(sim.player) >= 1, "derelict cargo is real")


func _fabricate() -> void:
	var sim := make()
	check(PlasmaHarvest.fabricate(sim, "coil_cannon") == "cost", "cannon refuses an empty hold")
	check(sim.player.modules.is_empty(), "nothing bolts without ore")
	sim.player.cargo = {"copper": 3, "iron": 5, "gold": 1, "aluminum": 3, "wreck_plate": 2}
	var gun_before := float(Fit.stats(defs, sim.player).gun.damage)
	var thrust_before := float(Fit.stats(defs, sim.player).thrust)
	var hp_before := int(sim.player.max_hp)
	check(PlasmaHarvest.fabricate(sim, "coil_cannon") == "", "coil cannon fabricates")
	check(float(Fit.stats(defs, sim.player).gun.damage) > gun_before, "cannon raises gun damage")
	check(Silhouette.shapes_of(defs, sim.player.modules).has("coil"), "cannon changes the silhouette")
	check(int(sim.player.cargo.get("gold", 0)) == 0, "gold is spent")
	check(PlasmaHarvest.fabricate(sim, "ion_booster") == "", "ion booster fabricates")
	check(float(Fit.stats(defs, sim.player).thrust) > thrust_before, "booster raises thrust")
	check(Silhouette.shapes_of(defs, sim.player.modules).has("booster"), "booster bells are on the keel")
	check(PlasmaHarvest.fabricate(sim, "plate_belt") == "", "plated armor fabricates")
	check(int(sim.player.max_hp) >= hp_before + 48, "armor raises hull")
	check(float(sim.player.hp) >= float(hp_before), "new plate comes on whole")
	check(Silhouette.shapes_of(defs, sim.player.modules).has("plate"), "armor belt is drawn")
	check(PlasmaHarvest.fabricate(sim, "coil_cannon") == "have", "a second cannon is refused")
	check(sim.resource_name("iron") == "Iron", "iron has a hold name")
	check(sim.resource_name("wreck_plate") == "Wreck plate", "plate has a hold name")


func _roundtrip() -> void:
	var sim := make()
	var rock := _first(sim, "copper", "meteor")
	sim.player.pos = rock.pos + Vector2(120, 0)
	sim.player.cargo.clear()
	PlasmaHarvest.engage(sim, rock.pos)
	var guard := 0
	while int(sim.player.cargo.get("copper", 0)) < 1 and guard < 200:
		sim.tick(0.05, {})
		guard += 1
	var left := int(rock.loads.get("copper", 0))
	var rock_id := str(rock.id)
	sim.player.cargo["aluminum"] = 3
	sim.player.cargo["copper"] = 1
	check(PlasmaHarvest.fabricate(sim, "ion_booster") == "", "booster is on the log")
	var pirate := {}
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			pirate = actor
			break
	pirate.hp = 1.0
	sim.damage_unit(pirate, 8.0, sim.player.agent_id)
	var raw = JSON.parse_string(JSON.stringify(sim.to_dict()))
	check(raw != null, "the log stringifies")
	var copy := SectorSim.new(defs)
	copy.from_dict(raw)
	var restored := PlasmaHarvest.by_id(copy, rock_id)
	check(int(restored.loads.get("copper", 0)) == left, "depleted ore survives the log")
	check(copy.player.modules.has("ion_booster"), "fabricated booster survives the log")
	check(int(copy.player.max_hp) == int(Fit.stats(defs, copy.player).hp_max), "hull rating reloads from the drawing")
	var runtime := 0
	for node in copy.nodes:
		if bool(node.get("runtime", false)):
			runtime += 1
	check(runtime >= 3, "battle debris survives the log")
	check(str(copy.nodes[0].id) == str(sim.nodes[0].id), "seeded field is the same Reach")


func _industry() -> void:
	var sim := make()
	var coil := Silhouette.extent(Silhouette.parts("vesper", ["coil"]))
	var lance := Silhouette.extent(Silhouette.parts("vesper", ["lance"]))
	var bare := Silhouette.extent(Silhouette.parts("vesper", []))
	var composite := Silhouette.extent(Silhouette.parts("vesper", ["composite"]))
	check(lance.x > coil.x + 10.0, "shard lance outruns the coil nose")
	check(composite.y > bare.y + 8.0, "composite belt widens the keel")
	sim.player.cargo = {"iron": 3}
	sim.player.pos = Vector2(9000, 0)
	check(PlasmaHarvest.sell(sim, "iron") == "far", "chandlery will not buy outside Hollow Latch")
	check(int(sim.player.cargo.iron) == 3, "a refused sale leaves the iron")
	sim.player.pos = sim.pocket_pos
	check(PlasmaHarvest.sell(sim, "iron") == "", "Latch buys the iron stack")
	check(int(sim.player.scrip) == 24, "iron pays 8 scrip a unit")
	check(int(sim.player.cargo.get("iron", 0)) == 0, "sold iron leaves the hold")
	sim.player.cargo = {"iron": 2, "aluminum": 1}
	check(PlasmaHarvest.start_refine(sim, "alloy_billet") == "", "refinery accepts iron and aluminum")
	check(int(sim.player.cargo.get("alloy_billet", 0)) == 0, "the billet is not instant")
	check(PlasmaHarvest.start_refine(sim, "alloy_billet") == "busy", "the bay runs one job")
	sim.tick(1.0, {})
	var progressed := float(sim.works.progress)
	check(progressed > 0.5, "the pour advances on the clock")
	var raw = JSON.parse_string(JSON.stringify(sim.to_dict()))
	var copy := SectorSim.new(defs)
	copy.from_dict(raw)
	check(bool(copy.works.active) and str(copy.works.id) == "alloy_billet", "a pour survives the log")
	check(absf(float(copy.works.progress) - progressed) < 0.05, "pour progress reloads")
	check(int(copy.player.scrip) == 24, "scrip survives the log")
	var guard := 0
	while int(copy.player.cargo.get("alloy_billet", 0)) < 1 and guard < 40:
		copy.tick(0.5, {})
		guard += 1
	check(int(copy.player.cargo.get("alloy_billet", 0)) == 1, "alloy billet comes out of the refinery")
	check(copy.resource_name("alloy_billet") == "Alloy billet", "alloy has a hold name")
	copy.player.pos = copy.pocket_pos
	check(PlasmaHarvest.sell(copy, "alloy_billet") == "", "Latch buys a synthetic")
	check(int(copy.player.scrip) == 24 + 34, "alloy pays more than the raw stack")
	var yard := make()
	yard.player.cargo = {"circuit_lace": 1, "alloy_billet": 1}
	var bite := float(Fit.stats(defs, yard.player).gun.damage)
	check(PlasmaHarvest.fabricate(yard, "shard_lance") == "", "lance drawing starts")
	check(not yard.player.modules.has("shard_lance"), "lance is not instant")
	guard = 0
	while not yard.player.modules.has("shard_lance") and guard < 40:
		yard.tick(0.5, {})
		guard += 1
	check(yard.player.modules.has("shard_lance"), "shard lance bolts on")
	check(float(Fit.stats(defs, yard.player).gun.damage) >= bite + 14.0, "lance hits harder than the stock gun")
	var hull := int(yard.player.max_hp)
	yard.player.cargo = {"hull_resin": 1, "alloy_billet": 1}
	check(PlasmaHarvest.fabricate(yard, "composite_belt") == "", "composite drawing starts")
	guard = 0
	while not yard.player.modules.has("composite_belt") and guard < 40:
		yard.tick(0.5, {})
		guard += 1
	check(int(yard.player.max_hp) >= hull + 72, "composite belt raises hull")
	check(int(yard.player.hp) == int(yard.player.max_hp), "new composite comes on whole")
	var boats := yard.craft.size()
	yard.player.cargo = {"alloy_billet": 1, "copper": 2, "iron": 1}
	check(PlasmaHarvest.start_craft(yard, "prospector") == "", "prospector laying starts")
	guard = 0
	while _craft_count(yard, "prospector") < 1 and guard < 40:
		yard.tick(0.5, {})
		guard += 1
	check(yard.craft.size() == boats + 1, "prospector takes a rack")
	var rock := _first(yard, "iron", "meteor")
	var iron_before := int(rock.loads.iron)
	yard.player.pos = rock.pos
	yard.player.vel = Vector2.ZERO
	yard.player.cargo.clear()
	check(CraftOrders.launch(yard, "prospector") == "", "prospector launches")
	guard = 0
	while Fit.cargo_used(yard.player) < 1 and guard < 80:
		yard.tick(0.2, {})
		guard += 1
	check(Fit.cargo_used(yard.player) >= 1, "prospector brings ore home")
	check(int(rock.loads.get("iron", 0)) == iron_before - 1, "prospector cuts the meteor")
	for planet in yard.planets:
		yard.scans[str(planet.id)] = {"complete": true}
	var rich := _richest(yard)
	yard.player.pos = rich.pos
	yard.player.vel = Vector2.ZERO
	yard.player.cargo = {"alloy_billet": 2, "circuit_lace": 1, "hull_resin": 1}
	check(PlasmaHarvest.start_craft(yard, "pathfinder") == "", "pathfinder laying starts")
	guard = 0
	while _craft_count(yard, "pathfinder") < 1 and guard < 50:
		yard.tick(0.5, {})
		guard += 1
	check(_craft_count(yard, "pathfinder") == 1, "pathfinder is on the rack")
	check(CraftOrders.launch(yard, "pathfinder") == "", "pathfinder launches")
	guard = 0
	while yard.beacon.is_empty() and guard < 40:
		yard.tick(0.2, {})
		guard += 1
	check(str(yard.beacon.get("name", "")) == str(rich.name), "pathfinder marks the richest rock")
	check(PlasmaHarvest.hangar_free(yard) == 0, "the rack is full")
	yard.player.cargo = {"alloy_billet": 1, "copper": 2, "iron": 1}
	check(PlasmaHarvest.start_craft(yard, "prospector") == "full", "a full hangar refuses another boat")
	check(int(yard.player.cargo.get("alloy_billet", 0)) == 1, "a refused lay spends nothing")
	var uid := ""
	for item in yard.craft:
		if str(item.def_id) == "prospector":
			item.state = "lost"
			uid = str(item.uid)
	var held := yard.craft.size()
	check(PlasmaHarvest.start_craft(yard, "prospector") == "", "a lost prospector can be rebuilt")
	guard = 0
	while true and guard < 40:
		var back := false
		for item in yard.craft:
			if str(item.uid) == uid and str(item.state) == "docked":
				back = true
		if back:
			break
		yard.tick(0.5, {})
		guard += 1
	var restored := false
	for item in yard.craft:
		if str(item.uid) == uid and str(item.state) == "docked":
			restored = true
	check(restored, "rebuilt prospector is the same boat")
	check(yard.craft.size() == held, "a rebuild does not add a second hull")


func _craft_count(sim: SectorSim, def_id: String) -> int:
	var n := 0
	for item in sim.craft:
		if str(item.def_id) == def_id and str(item.state) != "lost":
			n += 1
	return n


func _richest(sim: SectorSim) -> Dictionary:
	var best: Dictionary = {}
	var best_n := 0
	for node in sim.nodes:
		if str(node.kind) != "meteor":
			continue
		var n := PlasmaHarvest.remaining(node)
		if n > best_n:
			best_n = n
			best = node
	return best


func _clutter() -> void:
	var sim := make()
	var pocket: Vector2 = sim.pocket_pos
	var spawn: Vector2 = pocket + Vector2(40, 170)
	var near := 0
	var inner := 0
	var drift := 0
	var giant_near := false
	var plate_near := false
	var near_spawn := false
	var metals := {}
	for node in sim.nodes:
		var kind := str(node.kind)
		var belt := str(node.belt)
		if belt == "drift":
			drift += 1
		if kind == "meteor" and node.pos.length() < 1900.0:
			inner += 1
		if node.pos.distance_to(pocket) >= 1000.0:
			continue
		if kind == "meteor":
			near += 1
			metals[str(node.material)] = true
			if float(node.size) > 80.0:
				giant_near = true
			if node.pos.distance_to(spawn) < 700.0:
				near_spawn = true
		if kind == "wreckage":
			plate_near = true
	check(near >= 12, "meteors clutter the pocket (%d within 1000)" % near)
	check(near_spawn, "a meteor sits within 700 of the keel")
	check(inner >= 8, "meteors sit inside the old belt radius (%d)" % inner)
	check(giant_near, "a large asteroid hangs near Hollow Latch")
	check(plate_near, "torn plate drifts around the Latch")
	check(drift >= 400, "ore drift crosses the Reach (%d)" % drift)
	for mat_id in ["iron", "aluminum", "copper", "gold"]:
		check(bool(metals.get(mat_id, false)), "%s is visible around the Latch" % mat_id)
	var rock := {}
	var best_d := 700.0
	for node in sim.nodes:
		if str(node.kind) != "meteor":
			continue
		var dist: float = node.pos.distance_to(spawn)
		if dist < best_d:
			best_d = dist
			rock = node
	check(not rock.is_empty(), "the keel can see a rock")
	if rock.is_empty():
		return
	sim.interact(rock.pos, "inspect")
	check(str(sim.focus.get("kind", "")) == "node", "left-click a rock inspects it")
	sim.player.pos = rock.pos + Vector2(160, 0)
	sim.player.vel = Vector2.ZERO
	sim.interact(rock.pos, "use")
	check(bool(sim.gather.active), "right-click a nearby rock locks the gatherer")
	sim.interact(Vector2(24000, 24000), "use")
	check(not bool(sim.gather.active), "right-click empty dark stows the beam")
	var cinder = sim.planet("cinder")
	sim.interact(cinder.pos, "inspect")
	check(str(sim.focus.get("kind", "")) == "planet", "left-click Cinder inspects the world")
	sim.interact(cinder.pos, "use")
	var sent := false
	for item in sim.craft:
		if str(item.def_id) == "survey_probe" and str(item.target) == "cinder" and str(item.state) != "docked":
			sent = true
	check(sent, "right-click Cinder launches a probe")
	check(str(sim.ui_open) == "dossier", "right-click Cinder opens the dossier")
	var actor := {}
	for body in sim.actors:
		if bool(body.alive):
			actor = body
			break
	check(not actor.is_empty(), "a ship is in the Reach")
	if not actor.is_empty():
		sim.interact(actor.pos, "inspect")
		check(str(sim.focus.get("kind", "")) == "actor", "left-click a ship inspects it")
		check(str(sim.focus.get("id", "")) == str(actor.id), "the look is that ship")
	sim.interact(sim.pocket_pos, "inspect")
	check(str(sim.focus.get("kind", "")) == "latch", "left-click the Latch mark")
	sim.interact(sim.pocket_pos, "use")
	check(str(sim.ui_open) == "claim", "right-click the Latch opens the homestead")
	sim.interact(Vector2.ZERO, "inspect")
	check(str(sim.focus.get("kind", "")) == "star", "left-click Ash Lamp")
	sim.interact(sim.player.pos, "use")
	check(str(sim.focus.get("kind", "")) == "keel", "right-click the keel")
	check(str(sim.ui_open) == "bay", "right-click the keel opens the bay")
	var hulk_pos: Vector2 = sim.player.pos + Vector2(140, -40)
	sim.wrecks.append({
		"id": "wreck_click",
		"name": "Test hulk",
		"pos": hulk_pos,
		"stripped": false,
		"agent_id": "agent:test",
		"team": "red_keel",
		"class_id": "skiff",
		"controller": "ai",
		"cargo": {},
	})
	sim.interact(hulk_pos, "inspect")
	check(str(sim.focus.get("kind", "")) == "wreck", "left-click a wreck")
	sim.gather.active = false
	sim.interact(hulk_pos, "use")
	check(not bool(sim.gather.active), "a battle wreck does not take the beam without a tender")


func _count_belt(sim: SectorSim, belt_id: String) -> int:
	var n := 0
	for node in sim.nodes:
		if str(node.belt) == belt_id:
			n += 1
	return n


func _spread(sim: SectorSim, belt_id: String) -> float:
	var lo := 100000.0
	var hi := 0.0
	for node in sim.nodes:
		if str(node.belt) != belt_id:
			continue
		var rad: float = node.pos.length()
		lo = minf(lo, rad)
		hi = maxf(hi, rad)
	return hi - lo


func _kind(sim: SectorSim, kind: String) -> int:
	var n := 0
	for node in sim.nodes:
		if str(node.kind) == kind:
			n += 1
	return n


func _kind_node(sim: SectorSim, kind: String) -> Dictionary:
	for node in sim.nodes:
		if str(node.kind) == kind:
			return node
	return {}


func _has_material(sim: SectorSim, mat_id: String) -> bool:
	for node in sim.nodes:
		if int(node.loads.get(mat_id, 0)) > 0:
			return true
	return false


func _first(sim: SectorSim, mat_id: String, kind: String) -> Dictionary:
	for node in sim.nodes:
		if str(node.kind) == kind and str(node.material) == mat_id and int(node.loads.get(mat_id, 0)) > 0:
			return node
	return {}
