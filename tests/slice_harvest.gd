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
