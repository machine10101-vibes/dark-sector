extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("LUGGER WARRANT PASS")
	else:
		print("LUGGER WARRANT FAIL %d" % fails)
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
	var lugger: Dictionary = defs.ships.lugger
	var skiff: Dictionary = defs.ships.skiff
	var brig: Dictionary = defs.ships.brig
	var yawl: Dictionary = defs.ships.yawl
	check(int(lugger.bounty) == 48, "a Red Keel lugger posts 48 GRT")
	check(bool(lugger.playable) == false, "the lugger stays an outlaw hull")
	check(str(lugger.gun.family) == "bullet" and float(lugger.gun.range) < float(brig.gun.range) and float(lugger.gun.drop) > 0.0 and float(lugger.gun.damage) > float(brig.gun.damage), "the lugger fights with a close dropping shot")
	check(str(skiff.gun.family) == "missile" and int(skiff.bounty) == 24, "the skiff keeps the rack and the 24 GRT bounty")
	check(str(brig.gun.kind) == "turret" and int(brig.bounty) == 64, "the brig keeps the turret and the 64 GRT bounty")
	check(str(yawl.gun.family) == "laser" and int(yawl.bounty) == 36, "the yawl keeps the beam and the 36 GRT bounty")
	var home := SectorSim.new(defs)
	home.new_game("vesper")
	home.hold_npc = true
	var helion_lugger := 0
	var helion_skiff := 0
	for actor in home.actors:
		if str(actor.team) != "red_keel":
			continue
		if str(actor.class_id) == "lugger":
			helion_lugger += 1
		if str(actor.class_id) == "skiff":
			helion_skiff += 1
	check(helion_lugger == 0 and helion_skiff == 3, "Helion's pack stays on three skiffs")
	var copy := SectorSim.new(defs)
	copy.new_game("vesper")
	copy._arrive("HC-V1-R2-S5", "")
	copy.hold_npc = true
	var lurk: Dictionary = {}
	for actor in copy.actors:
		if str(actor.team) == "red_keel" and str(actor.ai.role) == "ambush":
			lurk = actor
	check(not lurk.is_empty() and str(lurk.class_id) == "lugger", "Second Copy's ambush is a lugger")
	if lurk.is_empty():
		return
	var ship_name := str(lurk.name)
	var listed := false
	for raw in DockBoard.wanted(copy):
		var row: Dictionary = raw
		if str(row.id) == str(lurk.agent_id):
			listed = int(row.bounty) == 48 and str(row.role) == "ambush" and str(row.name) == ship_name
	check(listed, "the warrant board names the lugger, the job, and 48 GRT")
	copy.player.pos = lurk.pos + Vector2(200, 0)
	var caption: String = copy.lock_caption(lurk)
	check(caption == "LOCK  %s  ·  200 m  ·  bounty 48" % ship_name, "the lock line posts the lugger bounty (%s)" % caption)
	var red0 := float(copy.heat.get("red_keel", 0.0))
	var purse0 := DockBoard.purse(copy)
	_break(copy, lurk)
	check(not bool(lurk.alive), "the lugger breaks")
	check(DockBoard.purse(copy) == purse0 + 48, "the captain collects 48 GRT")
	check(absf(float(copy.heat.get("red_keel", 0.0)) - (red0 + 10.0)) < 0.1, "the pack heat stays the same step")
	var wreck: Dictionary = copy.wrecks[copy.wrecks.size() - 1]
	check(int(wreck.cargo.get("scrap", 0)) == 1 and int(wreck.cargo.get("hull_plate", 0)) == 1, "the lugger wreck keeps scrap and plate")
	copy.player.pos = wreck.pos + Vector2(80, 0)
	var held: String = copy.wreck_caption(wreck)
	check(held.find("scrap ×1") >= 0 and held.find("Hull plate ×1") >= 0 and held.find("strip keel salvage and scrap") >= 0, "the lugger wreck names the strip (%s)" % held)
	var stage: Node = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	var mesh := Node3D.new()
	stage.call("_fill_ship", mesh, "lugger", [], [], [], "ambush")
	check(mesh.get_node_or_null("LuggerCowl") != null and mesh.get_node_or_null("LuggerMaw") != null and mesh.get_node_or_null("BountyPlate") != null and mesh.get_node_or_null("PostBaffle") != null, "a lugger wears a cowl, a maw, a bounty plate, and an ambush baffle")
	var small := Node3D.new()
	stage.call("_fill_ship", small, "skiff", [], [], [], "ambush")
	check(small.get_node_or_null("LuggerCowl") == null and small.get_node_or_null("BountyPlate") != null and small.get_node_or_null("PostBaffle") != null, "an ambush skiff keeps the plate and the baffle without the lugger cowl")
