extends SceneTree

var fails := 0


func _init() -> void:
	var defs: Dictionary = Catalog.boot()
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.hold_npc = true
	var ids: Array = []
	for key in defs.systems.keys():
		ids.append(str(key))
	ids.sort()
	check(ids.size() == 48, "the board has 48 sectors")
	check(sim.portal_to("HC-V1-R1-S1").contains("already"), "the portal stays when you are already there")
	var klass := str(sim.player.class_id)
	for sid in ids:
		if str(sid) == "HC-V1-R1-S1":
			continue
		var err := sim.portal_to(str(sid))
		check(err == "" and str(sim.defs.system.id) == str(sid), "the portal opens %s" % str(sid))
		check(sim.gates.size() > 0, "%s still has a ring" % str(sid))
		if str(sim.player.class_id) != klass:
			check(false, "the keel changes on a portal")
			break
	check(sim.portal_to("HC-V1-R1-S1") == "", "the portal returns to Helion Dock")
	check(str(sim.defs.system.id) == "HC-V1-R1-S1", "Helion Dock is the sky again")
	var gate: Dictionary = {}
	for row in sim.gates:
		gate = row
		break
	sim.player.pos = gate.pos
	var dest := str(gate.get("to", ""))
	check(sim.try_lane() == "" and str(sim.defs.system.id) == dest, "standing in the ring still takes the lane")
	if sim.craft.size() > 0:
		sim.craft[0].state = "out"
		var blocked := sim.portal_to("HC-V1-R8-S5")
		check(blocked.contains("Recall"), "a craft that is out holds the portal")
		check(str(sim.defs.system.id) == dest, "the held portal does not move the keel")
	if fails == 0:
		print("PORTALS PASS")
	else:
		print("PORTALS FAIL %d" % fails)
	quit(fails)


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)
