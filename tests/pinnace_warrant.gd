extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("PINNACE WARRANT PASS")
	else:
		print("PINNACE WARRANT FAIL %d" % fails)
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
	var pinnace: Dictionary = defs.ships.pinnace
	var skiff: Dictionary = defs.ships.skiff
	var brig: Dictionary = defs.ships.brig
	var yawl: Dictionary = defs.ships.yawl
	var lugger: Dictionary = defs.ships.lugger
	check(int(pinnace.bounty) == 40, "a Red Keel pinnace posts 40 GRT")
	check(bool(pinnace.playable) == false, "the pinnace stays an outlaw hull")
	var gun: Dictionary = pinnace.gun
	check(str(gun.family) == "bullet" and str(gun.kind) == "turret", "the pinnace fights with a bullet turret")
	check(float(gun.range) >= 260.0 and float(gun.optimal) >= 200.0 and float(gun.optimal) <= 260.0, "the chase gun lives in the 200 to 260 meter band")
	check(float(gun.cooldown) < float(brig.gun.cooldown) and float(gun.get("drop", 0.0)) == 0.0, "the chase gun is faster than the brig and does not drop like a lugger")
	check(str(skiff.gun.family) == "missile" and int(skiff.bounty) == 24, "the skiff keeps the rack and the 24 GRT bounty")
	check(str(brig.gun.kind) == "turret" and int(brig.bounty) == 64, "the brig keeps the turret and the 64 GRT bounty")
	check(str(yawl.gun.family) == "laser" and int(yawl.bounty) == 36, "the yawl keeps the beam and the 36 GRT bounty")
	check(int(lugger.bounty) == 48 and float(lugger.gun.drop) > 0.0, "the lugger keeps the dropping shot and the 48 GRT bounty")
	var home := SectorSim.new(defs)
	home.new_game("vesper")
	home.hold_npc = true
	var helion_pinnace := 0
	var helion_skiff := 0
	var helion_row: Dictionary = {}
	for actor in home.actors:
		if str(actor.team) != "red_keel":
			continue
		if str(actor.class_id) == "pinnace":
			helion_pinnace += 1
		if str(actor.class_id) == "skiff":
			helion_skiff += 1
	check(helion_pinnace == 0 and helion_skiff == 3, "Helion's pack stays on three skiffs")
	for raw in DockBoard.wanted(home):
		var row: Dictionary = raw
		if str(row.get("hull", "")) == "Skiff" and int(row.bounty) == 24:
			helion_row = row
			break
	check(not helion_row.is_empty() and DockBoard.warrant_line(helion_row).find("Skiff") >= 0, "a Helion warrant names the skiff hull")
	var guest := SectorSim.new(defs)
	guest.new_game("vesper")
	guest._arrive("HC-V1-R3-S3", "")
	guest.hold_npc = true
	var chase: Dictionary = {}
	for actor in guest.actors:
		if str(actor.team) == "red_keel" and str(actor.ai.role) == "interceptor":
			chase = actor
	check(not chase.is_empty() and str(chase.class_id) == "pinnace", "Guest Lamp's interceptor is a pinnace")
	if chase.is_empty():
		return
	var ship_name := str(chase.name)
	var listed := false
	var line := ""
	for raw in DockBoard.wanted(guest):
		var posted: Dictionary = raw
		if str(posted.id) == str(chase.agent_id):
			listed = int(posted.bounty) == 40 and str(posted.role) == "interceptor" and str(posted.hull) == "Pinnace" and str(posted.name) == ship_name
			line = DockBoard.warrant_line(posted)
	check(listed, "the warrant board names the pinnace, the job, and 40 GRT")
	check(line.find(ship_name) >= 0 and line.find("Pinnace") >= 0 and line.find("interceptor") >= 0 and line.find("bounty 40") >= 0, "the warrant line names hull, job, and bounty (%s)" % line)
	guest.player.pos = chase.pos + Vector2(200, 0)
	var caption: String = guest.lock_caption(chase)
	check(caption == "LOCK  %s  ·  200 m  ·  bounty 40" % ship_name, "the lock line posts the pinnace bounty (%s)" % caption)
	var red0 := float(guest.heat.get("red_keel", 0.0))
	var purse0 := DockBoard.purse(guest)
	_break(guest, chase)
	check(not bool(chase.alive), "the pinnace breaks")
	check(DockBoard.purse(guest) == purse0 + 40, "the captain collects 40 GRT")
	check(absf(float(guest.heat.get("red_keel", 0.0)) - (red0 + 10.0)) < 0.1, "the pack heat stays the same step")
	var wreck: Dictionary = guest.wrecks[guest.wrecks.size() - 1]
	check(int(wreck.cargo.get("scrap", 0)) == 1 and int(wreck.cargo.get("hull_plate", 0)) == 1, "the pinnace wreck keeps scrap and plate")
	guest.player.pos = wreck.pos + Vector2(80, 0)
	var held: String = guest.wreck_caption(wreck)
	check(held.find("scrap ×1") >= 0 and held.find("Hull plate ×1") >= 0 and held.find("strip keel salvage and scrap") >= 0, "the pinnace wreck names the strip (%s)" % held)
	var stage: Node = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	var mesh := Node3D.new()
	stage.call("_fill_ship", mesh, "pinnace", [], [], [], "interceptor")
	check(mesh.get_node_or_null("PinnaceRam") != null and mesh.get_node_or_null("BountyPlate") != null and mesh.get_node_or_null("PostSpike") != null, "a pinnace wears a ram, a bounty plate, and an interceptor spike")
	var small := Node3D.new()
	stage.call("_fill_ship", small, "skiff", [], [], [], "interceptor")
	check(small.get_node_or_null("PinnaceRam") == null and small.get_node_or_null("BountyPlate") != null and small.get_node_or_null("PostSpike") != null, "an interceptor skiff keeps the plate and the spike without the ram")
