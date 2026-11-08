extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("HAWSER TOW PASS")
	else:
		print("HAWSER TOW FAIL %d" % fails)
	quit(fails)
	return true


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func _off(sim, kind: String, index: int) -> Vector2:
	var craft := {"uid": "%s_%d" % [kind, index + 1], "def_id": kind}
	var pose: Dictionary = CraftOrders.escort_pose(sim, craft, index)
	return Vector2(pose.pos) - sim.player.pos


func _run() -> void:
	var defs := Catalog.boot()
	var spec: Dictionary = defs.craft.hawser_drone
	check(str(spec.role) == "tractor", "the Hawser is a tractor")
	check(str(spec.post) == "Hawser", "the Hawser names its post")
	check(not spec.has("gun"), "the Hawser carries no gun")
	check(DockBoard.support_shop_ids().has("hawser_drone"), "the pad rack lists the Hawser")
	check(int(DockBoard.SUPPORT_SHOP.hawser_drone.price) == 52, "the Hawser costs 52 GRT")
	check(int(DockBoard.SUPPORT_SHOP.hawser_drone.cap) == 1, "the rack holds one Hawser")
	var need: Dictionary = DockBoard.recipe_need("hawser_drone")
	check(int(need.aluminum_bar) == 1 and int(need.hull_plate) == 1, "a Hawser takes one aluminum and one plate")
	var sim := SectorSim.new(defs)
	sim.new_game("anvil")
	sim.hold_npc = true
	var wing_before := DockBoard.attack_count(sim)
	sim.quest_flags.purse = 52
	check(DockBoard.buy_support(sim, "hawser_drone") == "", "the pad sells a Hawser")
	check(DockBoard.attack_count(sim) == wing_before, "a Hawser does not fill the attack wing")
	check(not CraftOrders.is_attack(sim, "hawser_drone"), "a Hawser is not an attack drone")
	var craft = null
	for item in sim.craft:
		if str(item.def_id) == "hawser_drone":
			craft = item
	check(craft != null, "the Hawser is on the rack")
	if craft == null:
		return
	var sky := Vector2(40000, 40000)
	sim.player.pos = sky
	sim.player.vel = Vector2.ZERO
	sim.player.rot = 0.0
	var parked_note: String = CraftOrders.launch(sim, "salvage_tender")
	check(parked_note.find("parked") >= 0, "the tender stays parked with no wreck in reach")
	var hull := sim._blank_ship("anvil", "Lost Barn", "agent:civilian:lost", "npc", "civilian")
	hull.pos = sky + Vector2(900, 0)
	hull.cargo = {"ice_spall": 3}
	var ice_before := int(sim.player.cargo.get("ice_spall", 0))
	sim._kill(hull, "captain")
	check(sim.wrecks.size() > 0, "the barn leaves a wreck")
	var wreck: Dictionary = sim.wrecks[sim.wrecks.size() - 1]
	check(wreck.pos.distance_to(sim.player.pos) > 720.0, "the wreck starts outside the tender reach")
	var still: String = CraftOrders.launch(sim, "salvage_tender")
	check(still.find("parked") >= 0, "a far wreck still leaves the tender parked")
	check(CraftOrders.launch(sim, "hawser_drone") == "", "the Hawser launches")
	craft.state = "escort"
	craft.order = "hawser"
	craft.tow_id = ""
	craft.said_tow = ""
	craft.pos = sky
	craft.vel = Vector2.ZERO
	craft.battery = 150.0
	var shots := sim.projectiles.size()
	var heard := ""
	for _i in 80:
		CraftOrders.step(sim, craft, 0.25)
		if not sim.lines.is_empty() and str(sim.lines[0].text).find("alongside") >= 0:
			heard = str(sim.lines[0].text)
			break
	check(heard.find("Hawser") >= 0 and heard.find("Lost Barn") >= 0, "a Hawser names the wreck it brings in")
	var brought: float = wreck.pos.distance_to(sim.player.pos)
	check(brought <= 130.0, "the wreck comes inside the salvage ring (%.0f m)" % brought)
	check(int(wreck.cargo.get("ice_spall", 0)) == 3, "the tow leaves the hold on the wreck")
	check(not bool(wreck.get("stripped", false)), "the tow does not strip the wreck")
	check(int(sim.player.cargo.get("ice_spall", 0)) == ice_before, "the tow does not move goods into the keel")
	check(sim.projectiles.size() == shots, "a Hawser does not shoot")
	check(str(craft.state) == "returning", "a Hawser turns for home once the wreck is alongside")
	var reach := float(Fit.stats(sim.defs, sim.player).hit_radius)
	var span := maxf(reach * 9.0, 280.0)
	var body = sim.planet(str(sim.body_id))
	sim.player.pos = Vector2(80000, 80000)
	sim.time = 2.0
	if body != null:
		var away: Vector2 = sim.player.pos - body.pos
		sim.player.rot = away.angle()
	var nose := Vector2.from_angle(sim.player.rot)
	var side := Vector2(-nose.y, nose.x)
	var dart := _off(sim, "dart_drone", 0)
	var lance := _off(sim, "lance_drone", 0)
	var sting := _off(sim, "sting_drone", 0)
	var fang := _off(sim, "fang_drone", 0)
	var wasp := _off(sim, "wasp_drone", 0)
	var fighter := _off(sim, "fighter", 0)
	var floor_dist := span * 1.85
	check(dart.length() > floor_dist and dart.normalized().dot(nose) > 0.85, "a Dart forms ahead of the bow")
	check(lance.length() > floor_dist and lance.length() < dart.length() and lance.normalized().dot(nose) > 0.85, "a Lance forms on the near bow")
	check(sting.length() > floor_dist and absf(sting.normalized().dot(side)) > 0.9, "a Sting forms on the beam")
	check(fang.length() > floor_dist and fang.normalized().dot(side) < -0.8, "a Fang forms on the far beam")
	check(wasp.length() > floor_dist and wasp.normalized().dot(side) > 0.75 and wasp.normalized().dot(nose) < sting.normalized().dot(nose), "a Wasp forms on the far quarter")
	check(fighter.length() > floor_dist and fighter.distance_to(dart) > 120.0, "a fighter keeps its own screen")
	var sting_far := _off(sim, "sting_drone", 4)
	check(sting.distance_to(sting_far) > 120.0, "two Stings take two stations")
	var pose: Dictionary = CraftOrders.escort_pose(sim, {"uid": "dart_drone_1", "def_id": "dart_drone"}, 0)
	check(absf(wrapf(float(pose.rot) - sim.player.rot, -PI, PI)) > 0.15, "a formed Dart flies its own heading")
	for item in sim.wrecks:
		item.pos = Vector2(140000, 140000)
	craft.state = "escort"
	craft.order = "hawser"
	craft.tow_id = ""
	craft.pos = sky
	craft.vel = Vector2.ZERO
	craft.battery = 150.0
	sim.player.pos = sky
	sim.player.rot = 0.0
	for _k in 8:
		CraftOrders.step(sim, craft, 0.25)
	var aft: float = craft.pos.distance_to(sky - Vector2(160, 0))
	check(aft < 30.0, "with no wreck in reach the Hawser holds aft (%.0f m)" % aft)
	var stage: Node = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	var tug: Node3D = stage.call("pose_craft", "hawser_drone")
	check(tug.get_node_or_null("Boom") != null and tug.get_node_or_null("Collar") != null and tug.get_node_or_null("LampTow") != null, "the Hawser wears a boom, a collar, and a tow lamp")
