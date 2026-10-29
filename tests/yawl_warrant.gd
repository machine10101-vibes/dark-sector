extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("YAWL WARRANT PASS")
	else:
		print("YAWL WARRANT FAIL %d" % fails)
	quit(fails)
	return true


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func _break(sim, unit: Dictionary) -> void:
	unit.pos = Vector2(50000, 50000)
	unit.vel = Vector2.ZERO
	unit.hp = 1.0
	unit.shield = 0.0
	unit.armor_hp = 0.0
	unit.ai.fired_on_captain = false
	sim.damage_unit(unit, 80.0, "agent:captain")


func _run() -> void:
	var defs := Catalog.boot()
	var yawl: Dictionary = defs.ships.yawl
	var skiff: Dictionary = defs.ships.skiff
	var brig: Dictionary = defs.ships.brig
	check(int(yawl.bounty) == 36, "a Red Keel yawl posts 36 GRT")
	check(bool(yawl.playable) == false, "the yawl stays an outlaw hull")
	check(str(yawl.gun.family) == "laser" and float(yawl.gun.range) > float(brig.gun.range), "the yawl fights with a longer beam")
	check(str(skiff.gun.family) == "missile" and int(skiff.bounty) == 24, "the skiff keeps the rack and the 24 GRT bounty")
	check(str(brig.gun.family) == "bullet" and int(brig.bounty) == 64, "the brig keeps the turret and the 64 GRT bounty")
	var home := SectorSim.new(defs)
	home.new_game("vesper")
	home.hold_npc = true
	var helion_yawl := 0
	var helion_skiff := 0
	for actor in home.actors:
		if str(actor.team) != "red_keel":
			continue
		if str(actor.class_id) == "yawl":
			helion_yawl += 1
		if str(actor.class_id) == "skiff":
			helion_skiff += 1
	check(helion_yawl == 0 and helion_skiff == 3, "Helion's pack stays on three skiffs")
	var ice := SectorSim.new(defs)
	ice.new_game("vesper")
	ice._arrive("HC-V1-R2-S4", "")
	ice.hold_npc = true
	var flank: Dictionary = {}
	for actor in ice.actors:
		if str(actor.team) == "red_keel" and str(actor.ai.role) == "kite":
			flank = actor
	check(not flank.is_empty() and str(flank.class_id) == "yawl", "Stamped Ice's kite is a yawl")
	if flank.is_empty():
		return
	var ship_name := str(flank.name)
	var listed := false
	for raw in DockBoard.wanted(ice):
		var row: Dictionary = raw
		if str(row.id) == str(flank.agent_id):
			listed = int(row.bounty) == 36 and str(row.role) == "kite" and str(row.name) == ship_name
	check(listed, "the warrant board names the yawl, the job, and 36 GRT")
	ice.player.pos = flank.pos + Vector2(200, 0)
	var caption: String = ice.lock_caption(flank)
	check(caption == "LOCK  %s  ·  200 m  ·  bounty 36" % ship_name, "the lock line posts the yawl bounty (%s)" % caption)
	var red0 := float(ice.heat.get("red_keel", 0.0))
	var purse0 := DockBoard.purse(ice)
	_break(ice, flank)
	check(not bool(flank.alive), "the yawl breaks")
	check(DockBoard.purse(ice) == purse0 + 36, "the captain collects 36 GRT")
	check(absf(float(ice.heat.get("red_keel", 0.0)) - (red0 + 10.0)) < 0.1, "the pack heat stays the same step")
	var wreck: Dictionary = ice.wrecks[ice.wrecks.size() - 1]
	check(int(wreck.cargo.get("scrap", 0)) == 1 and int(wreck.cargo.get("hull_plate", 0)) == 1, "the yawl wreck keeps scrap and plate")
	ice.player.pos = wreck.pos + Vector2(80, 0)
	var held: String = ice.wreck_caption(wreck)
	check(held.find("scrap ×1") >= 0 and held.find("Hull plate ×1") >= 0 and held.find("strip keel salvage and scrap") >= 0, "the yawl wreck names the strip (%s)" % held)
	var print_sky := SectorSim.new(defs)
	print_sky.new_game("vesper")
	print_sky._arrive("HC-V1-R2-S6", "")
	print_sky.hold_npc = true
	var saw_yawl := false
	var saw_brig := false
	var saw_skiff := false
	for actor in print_sky.actors:
		if str(actor.team) != "red_keel":
			continue
		if str(actor.ai.role) == "kite" and str(actor.class_id) == "yawl":
			saw_yawl = true
		elif str(actor.ai.role) == "raider" and str(actor.class_id) == "brig":
			saw_brig = true
		elif str(actor.ai.role) == "ambush" and str(actor.class_id) == "skiff":
			saw_skiff = true
	check(saw_yawl and saw_brig and saw_skiff, "Fine Print keeps a yawl, a brig, and a skiff")
	var stage: Node = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	var mesh := Node3D.new()
	stage.call("_fill_ship", mesh, "yawl", [], [], [], "kite")
	check(mesh.get_node_or_null("YawlSpar") != null and mesh.get_node_or_null("YawlLens") != null and mesh.get_node_or_null("BountyPlate") != null and mesh.get_node_or_null("PostFinP") != null, "a yawl wears a spar, a lens, a bounty plate, and kite fins")
	var small := Node3D.new()
	stage.call("_fill_ship", small, "skiff", [], [], [], "kite")
	check(small.get_node_or_null("YawlSpar") == null and small.get_node_or_null("BountyPlate") != null and small.get_node_or_null("PostFinP") != null, "a kite skiff keeps the plate and the fins without the yawl spar")
