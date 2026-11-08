extends SceneTree

var fail := 0


func _init() -> void:
	var defs: Dictionary = Catalog.boot()
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.hold_npc = true
	for key in defs.systems.keys():
		var sid := str(key)
		sim._arrive(sid, "")
		var title := str(sim.defs.system.name)
		if sim.trash.size() < 4:
			_bad("%s wrecks %d" % [title, sim.trash.size()])
		var red := 0
		for actor in sim.actors:
			if str(actor.get("team", "")) == "red_keel":
				red += 1
		if red < 1:
			_bad("%s has no Red Keel" % title)
		var mats := {}
		for rock in sim.asteroids:
			var id := str(rock.get("material", ""))
			mats[id] = int(mats.get(id, 0)) + 1
		if int(mats.get("nickel_cinder", 0)) < 1 or int(mats.get("ice_spall", 0)) < 1 or int(mats.get("copper_slag", 0)) < 1:
			_bad("%s materials %s" % [title, mats])
		if sim.meteors.size() < 2:
			_bad("%s comets %d" % [title, sim.meteors.size()])
	sim._arrive("HC-V1-R1-S1", "")
	if int(sim.defs.system.pirates.count) < 1:
		_bad("Helion pack was rewritten")
	if not str(sim.defs.system.trash.origin).to_lower().contains("confiscated"):
		_bad("Helion hold lost its origin")
	if sim.trash.size() < 8:
		_bad("Helion hold shrank")
	var before: Vector2 = sim.meteors[0].pos
	sim.tick(1.0, {})
	if sim.meteors[0].pos.distance_to(before) < 1.0:
		_bad("Helion gravel is still")
	sim._arrive("HC-V1-R5-S1", "")
	if int(sim.defs.system.trash.get("count", 0)) < 4:
		_bad("First Soil still has an empty hold")
	if str(sim.defs.system.stream.get("id", "")) != "lane_gravel":
		_bad("First Soil has no comet lane")
	if int(sim.defs.system.pirates.get("count", 0)) != 2:
		_bad("First Soil pack is not a pair")
	var soil_skiff := false
	for actor in sim.actors:
		if str(actor.get("team", "")) == "red_keel" and str(actor.get("class_id", "")) == "skiff" and sim.bounty_of(actor) == 24:
			soil_skiff = true
	if not soil_skiff:
		_bad("First Soil pack is not a 24 GRT skiff")
	var wreck: Variant = sim.survey_node("lane_wreck")
	if wreck == null or int(sim.deposits.get("lane_wreck", 0)) < 1:
		_bad("First Soil wreck cannot be salvaged")
	var rain_before: Vector2 = sim.meteors[0].pos
	sim.tick(1.0, {})
	if sim.meteors[0].pos.distance_to(rain_before) < 1.0:
		_bad("First Soil gravel is still")
	var near := 1.0e9
	for i in sim.trash.size():
		for j in range(i + 1, sim.trash.size()):
			var a: Vector2 = sim.trash[i].pos
			var b: Vector2 = sim.trash[j].pos
			near = minf(near, a.distance_to(b))
	if near < 70.0:
		_bad("First Soil wrecks are clumped (%s)" % snapped(near, 0.1))
	sim._arrive("HC-V1-R1-S2", "")
	if int(sim.defs.system.pirates.get("count", 0)) != 2:
		_bad("Brass Lantern pack count changed")
	var patrols := 0
	var hostiles := 0
	for actor in sim.actors:
		if str(actor.team) == "helion_compact":
			patrols += 1
		if str(actor.team) == "red_keel":
			hostiles += 1
	if patrols < 1 or hostiles < 1:
		_bad("Brass Lantern lost the patrol or the pack")
	if fail == 0:
		print("SKY FILL PASS")
	else:
		print("SKY FILL FAIL ", fail)
	quit(0 if fail == 0 else 1)


func _bad(line: String) -> void:
	fail += 1
	print("FAIL ", line)
