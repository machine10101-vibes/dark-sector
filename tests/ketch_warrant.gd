extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("KETCH WARRANT PASS")
	else:
		print("KETCH WARRANT FAIL %d" % fails)
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
	var ketch: Dictionary = defs.ships.ketch
	var skiff: Dictionary = defs.ships.skiff
	var brig: Dictionary = defs.ships.brig
	var yawl: Dictionary = defs.ships.yawl
	var lugger: Dictionary = defs.ships.lugger
	var pinnace: Dictionary = defs.ships.pinnace
	check(int(ketch.bounty) == 52, "a Red Keel ketch posts 52 GRT")
	check(bool(ketch.playable) == false, "the ketch stays an outlaw hull")
	var gun: Dictionary = ketch.gun
	check(str(gun.family) == "bullet" and str(gun.kind) == "turret", "the ketch fights with a bullet turret")
	check(float(gun.range) < float(lugger.gun.range) and float(gun.optimal) < float(lugger.gun.optimal) and float(gun.optimal) > 80.0, "the pocket gun is shorter than the lugger shot")
	check(float(gun.arc) > float(pinnace.gun.arc) and float(gun.cooldown) > float(lugger.gun.cooldown) and float(gun.get("drop", 0.0)) == 0.0, "the pocket gun is wide and slow and does not drop")
	check(float(gun.damage) > float(brig.gun.damage) and float(gun.damage) < float(lugger.gun.damage), "the pocket gun hits harder than the brig and softer than the lugger")
	check(str(skiff.gun.family) == "missile" and int(skiff.bounty) == 24, "the skiff keeps the rack and the 24 GRT bounty")
	check(str(brig.gun.kind) == "turret" and int(brig.bounty) == 64, "the brig keeps the turret and the 64 GRT bounty")
	check(str(yawl.gun.family) == "laser" and int(yawl.bounty) == 36, "the yawl keeps the beam and the 36 GRT bounty")
	check(int(lugger.bounty) == 48 and float(lugger.gun.drop) > 0.0, "the lugger keeps the dropping shot and the 48 GRT bounty")
	check(int(pinnace.bounty) == 40 and float(pinnace.gun.optimal) >= 200.0, "the pinnace keeps the chase gun and the 40 GRT bounty")
	var home := SectorSim.new(defs)
	home.new_game("vesper")
	home.hold_npc = true
	var helion_ketch := 0
	var helion_skiff := 0
	for actor in home.actors:
		if str(actor.team) != "red_keel":
			continue
		if str(actor.class_id) == "ketch":
			helion_ketch += 1
		if str(actor.class_id) == "skiff":
			helion_skiff += 1
	check(helion_ketch == 0 and helion_skiff == 3, "Helion's pack stays on three skiffs")
	var choir := SectorSim.new(defs)
	choir.new_game("vesper")
	choir._arrive("HC-V1-R2-S3", "")
	choir.hold_npc = true
	var jumper: Dictionary = {}
	var flank: Dictionary = {}
	for actor in choir.actors:
		if str(actor.team) != "red_keel":
			continue
		if str(actor.ai.role) == "claim_jumper":
			jumper = actor
		elif str(actor.ai.role) == "kite":
			flank = actor
	check(not jumper.is_empty() and str(jumper.class_id) == "ketch", "Ore Choir's claim jumper is a ketch")
	check(jumper.home.distance_to(choir.pocket_pos) < 40.0, "the ketch still sits the pocket")
	check(not flank.is_empty() and str(flank.class_id) == "yawl", "Ore Choir's kite stays a yawl")
	if jumper.is_empty():
		return
	var ship_name := str(jumper.name)
	var listed := false
	var line := ""
	for raw in DockBoard.wanted(choir):
		var posted: Dictionary = raw
		if str(posted.id) == str(jumper.agent_id):
			listed = int(posted.bounty) == 52 and str(posted.role) == "claim_jumper" and str(posted.hull) == "Ketch" and str(posted.name) == ship_name
			line = DockBoard.warrant_line(posted)
	check(listed, "the warrant board names the ketch, the job, and 52 GRT")
	check(line.find(ship_name) >= 0 and line.find("Ketch") >= 0 and line.find("claim_jumper") >= 0 and line.find("bounty 52") >= 0, "the warrant line names hull, job, and bounty (%s)" % line)
	choir.player.pos = jumper.pos + Vector2(200, 0)
	var caption: String = choir.lock_caption(jumper)
	check(caption == "LOCK  %s  ·  200 m  ·  bounty 52" % ship_name, "the lock line posts the ketch bounty (%s)" % caption)
	var red0 := float(choir.heat.get("red_keel", 0.0))
	var purse0 := DockBoard.purse(choir)
	_break(choir, jumper)
	check(not bool(jumper.alive), "the ketch breaks")
	check(DockBoard.purse(choir) == purse0 + 52, "the captain collects 52 GRT")
	check(absf(float(choir.heat.get("red_keel", 0.0)) - (red0 + 10.0)) < 0.1, "the pack heat stays the same step")
	var wreck: Dictionary = choir.wrecks[choir.wrecks.size() - 1]
	check(int(wreck.cargo.get("scrap", 0)) == 1 and int(wreck.cargo.get("hull_plate", 0)) == 1, "the ketch wreck keeps scrap and plate")
	choir.player.pos = wreck.pos + Vector2(80, 0)
	var held: String = choir.wreck_caption(wreck)
	check(held.find("scrap ×1") >= 0 and held.find("Hull plate ×1") >= 0 and held.find("strip keel salvage and scrap") >= 0, "the ketch wreck names the strip (%s)" % held)
	var stage: Node = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	var mesh := Node3D.new()
	stage.call("_fill_ship", mesh, "ketch", [], [], [], "claim_jumper")
	check(mesh.get_node_or_null("KetchBin") != null and mesh.get_node_or_null("KetchBinS") != null and mesh.get_node_or_null("BountyPlate") != null and mesh.get_node_or_null("PostStake") != null and mesh.get_node_or_null("PostBeacon") != null, "a ketch wears ore bins, a bounty plate, and a claim stake")
	var small := Node3D.new()
	stage.call("_fill_ship", small, "skiff", [], [], [], "claim_jumper")
	check(small.get_node_or_null("KetchBin") == null and small.get_node_or_null("BountyPlate") != null and small.get_node_or_null("PostStake") != null, "a claim skiff keeps the plate and the stake without the ore bins")
