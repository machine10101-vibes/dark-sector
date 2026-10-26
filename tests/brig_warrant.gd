extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("BRIG WARRANT PASS")
	else:
		print("BRIG WARRANT FAIL %d" % fails)
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
	var brig: Dictionary = defs.ships.brig
	var skiff: Dictionary = defs.ships.skiff
	check(int(brig.bounty) == 64, "a Red Keel brig posts 64 GRT")
	check(bool(brig.playable) == false, "the brig stays an outlaw hull")
	check(str(brig.gun.family) == "bullet" and str(brig.gun.kind) == "turret", "the brig fights with a turret")
	check(str(skiff.gun.family) == "missile" and int(skiff.bounty) == 24, "the skiff keeps the rack and the 24 GRT bounty")
	var home := SectorSim.new(defs)
	home.new_game("vesper")
	home.hold_npc = true
	var helion_brig := 0
	var helion_skiff := 0
	for actor in home.actors:
		if str(actor.team) != "red_keel":
			continue
		if str(actor.class_id) == "brig":
			helion_brig += 1
		if str(actor.class_id) == "skiff":
			helion_skiff += 1
	check(helion_brig == 0 and helion_skiff == 3, "Helion's pack stays on three skiffs")
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim._arrive("HC-V1-R2-S6", "")
	sim.hold_npc = true
	var heavy: Dictionary = {}
	var light := 0
	for actor in sim.actors:
		if str(actor.team) != "red_keel":
			continue
		if str(actor.ai.role) == "raider":
			heavy = actor
		elif str(actor.class_id) == "skiff":
			light += 1
	check(not heavy.is_empty() and str(heavy.class_id) == "brig", "Fine Print's raider is a brig")
	check(light == 2, "the ambush and the kite stay skiffs")
	if heavy.is_empty():
		return
	var ship_name := str(heavy.name)
	var listed := false
	for raw in DockBoard.wanted(sim):
		var row: Dictionary = raw
		if str(row.id) == str(heavy.agent_id):
			listed = int(row.bounty) == 64 and str(row.role) == "raider" and str(row.name) == ship_name
	check(listed, "the warrant board names the brig, the job, and 64 GRT")
	sim.player.pos = heavy.pos + Vector2(200, 0)
	var caption: String = sim.lock_caption(heavy)
	check(caption == "LOCK  %s  ·  200 m  ·  bounty 64" % ship_name, "the lock line posts the brig bounty (%s)" % caption)
	var red0 := float(sim.heat.get("red_keel", 0.0))
	var purse0 := DockBoard.purse(sim)
	_break(sim, heavy)
	check(not bool(heavy.alive), "the brig breaks")
	check(DockBoard.purse(sim) == purse0 + 64, "the captain collects 64 GRT")
	check(absf(float(sim.heat.get("red_keel", 0.0)) - (red0 + 10.0)) < 0.1, "the pack heat stays the same step")
	var wreck: Dictionary = sim.wrecks[sim.wrecks.size() - 1]
	check(int(wreck.cargo.get("scrap", 0)) == 1 and int(wreck.cargo.get("hull_plate", 0)) == 1, "the brig wreck keeps scrap and plate")
	sim.player.pos = wreck.pos + Vector2(80, 0)
	var held: String = sim.wreck_caption(wreck)
	check(held.find("scrap ×1") >= 0 and held.find("Hull plate ×1") >= 0 and held.find("strip keel salvage and scrap") >= 0, "the brig wreck names the strip (%s)" % held)
	var stage: Node = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	var mesh := Node3D.new()
	stage.call("_fill_ship", mesh, "brig", [], [], [], "raider")
	check(mesh.get_node_or_null("BrigSpine") != null and mesh.get_node_or_null("BountyPlate") != null and mesh.get_node_or_null("PostClawP") != null, "a brig wears a spine, a bounty plate, and raider claws")
	var small := Node3D.new()
	stage.call("_fill_ship", small, "skiff", [], [], [], "raider")
	check(small.get_node_or_null("BrigSpine") == null and small.get_node_or_null("BountyPlate") != null and small.get_node_or_null("PostClawP") != null, "a skiff keeps the plate and the claws without the brig spine")
