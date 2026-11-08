extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("LANE PICKET PASS")
	else:
		print("LANE PICKET FAIL %d" % fails)
	quit(fails)
	return true


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func _run() -> void:
	var defs := Catalog.boot()
	var picket: Dictionary = defs.craft.picket_drone
	check(str(picket.role) == "scout", "the Picket is a scout")
	check(str(picket.post) == "Picket", "the Picket names its post")
	check(not picket.has("gun"), "the Picket carries no gun")
	check(DockBoard.support_shop_ids().has("picket_drone"), "the pad rack lists the Picket")
	check(int(DockBoard.SUPPORT_SHOP.picket_drone.price) == 36, "the Picket costs 36 GRT")
	check(int(DockBoard.SUPPORT_SHOP.picket_drone.cap) == 1, "the rack holds one Picket")
	check(DockBoard.recipe_ids().has("picket_drone"), "the yard has a Picket plan")
	var need: Dictionary = DockBoard.recipe_need("picket_drone")
	check(int(need.aluminum_bar) == 1 and int(need.ice_spall) == 1, "a Picket takes one aluminum and one ice")
	var lead := Vector2(0, 800)
	var mark := Vector2.ZERO
	var approach := (lead - mark).normalized()
	var wasp: Vector2 = CraftOrders._attack_slot(0, mark, lead, "wasp_drone")
	var screen: Vector2 = CraftOrders._attack_slot(0, mark, lead, "fighter")
	check(wasp.dot(approach) < -40.0, "a Wasp sits behind the lock")
	check(screen.dot(approach) > 40.0, "a fighter still holds the screen ahead of the lock")
	var sim := SectorSim.new(defs)
	sim.new_game("kestrel")
	sim.hold_npc = true
	var wing_before := DockBoard.attack_count(sim)
	sim.quest_flags.purse = 36
	check(DockBoard.buy_support(sim, "picket_drone") == "", "the pad sells a Picket")
	check(DockBoard.attack_count(sim) == wing_before, "a Picket does not fill the attack wing")
	check(not CraftOrders.is_attack(sim, "picket_drone"), "a Picket is not an attack drone")
	var craft = null
	for item in sim.craft:
		if str(item.def_id) == "picket_drone":
			craft = item
	check(craft != null, "the Picket is on the rack")
	if craft == null:
		return
	check(CraftOrders.launch(sim, "picket_drone") == "", "the Picket launches")
	var sky := Vector2(40000, 40000)
	sim.player.pos = sky
	sim.player.vel = Vector2.ZERO
	sim.player.rot = 0.0
	craft.state = "escort"
	craft.order = "picket"
	craft.pos = sky
	craft.vel = Vector2.ZERO
	craft.battery = 160.0
	for actor in sim.actors:
		actor.pos = Vector2(90000, 0)
	for _i in 8:
		CraftOrders.step(sim, craft, 0.25)
	var parked: float = craft.pos.distance_to(sim.player.pos)
	check(parked > 200.0 and parked < 360.0, "a Picket holds the bow (%.0f m)" % parked)
	var quarry := {}
	for actor in sim.actors:
		if str(actor.team) == "red_keel":
			quarry = actor
			break
	var anchor := sky + Vector2(280, 0)
	craft.pos = anchor
	craft.vel = Vector2.ZERO
	craft.called_id = ""
	quarry.pos = anchor + Vector2(180, 0)
	quarry.alive = true
	var shots := sim.projectiles.size()
	CraftOrders.step(sim, craft, 0.2)
	var heard := ""
	if not sim.lines.is_empty():
		heard = str(sim.lines[0].text)
	check(heard.find("Picket") >= 0 and heard.find(str(quarry.name)) >= 0, "a Picket calls the ship on the bow")
	check(sim.projectiles.size() == shots, "a Picket does not shoot")
	check(craft.pos.distance_to(anchor) < 80.0, "the Picket stays on the bow after the call")
	var holt := {}
	for actor in sim.actors:
		if str(actor.name) == "Hauler Holt":
			holt = actor
			break
	check(not holt.is_empty(), "Hauler Holt is on the lane")
	if holt.is_empty():
		return
	holt.pos = holt.home
	holt.vel = Vector2.ZERO
	sim.player.pos = Vector2(120000, 120000)
	var dest: Vector2 = sim._freight_dest(holt)
	var along: Vector2 = dest - holt.home
	var reach := float(holt.ai.radius)
	check(along.length() > 80.0 and along.length() <= reach + 2.0, "the freight leg stays inside the hauler radius")
	var best_dot := -1.0
	var marks: Array = [sim.pocket_pos]
	for body in sim.planets:
		marks.append(body.pos)
	for gate in sim.gates:
		marks.append(gate.pos)
	for spot in marks:
		var gap: Vector2 = Vector2(spot) - holt.home
		if gap.length() < 180.0:
			continue
		best_dot = maxf(best_dot, along.normalized().dot(gap.normalized()))
	check(best_dot > 0.98, "the freight leg points at the far world")
	holt.rot = along.angle()
	var started: Vector2 = holt.pos
	for _j in 8:
		sim._step_npc(holt, 0.25)
	check(holt.pos.distance_to(started) > 8.0, "Hauler Holt runs the freight leg")
	var stage: Node = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	var scout: Node3D = stage.call("pose_craft", "picket_drone")
	check(scout.get_node_or_null("Mast") != null and scout.get_node_or_null("Dish") != null and scout.get_node_or_null("LampBow") != null, "the Picket wears a mast, a dish, and a bow lamp")
	var barn := Node3D.new()
	stage.call("_fill_ship", barn, "anvil", [], [], [], "trader")
	check(barn.get_node_or_null("CargoCan") != null, "a trader barn wears cargo cans")
	var tug := Node3D.new()
	stage.call("_fill_ship", tug, "anvil", [], [], [], "tow")
	check(tug.get_node_or_null("TowBoom") != null, "a tug barn wears a tow boom")
	var herd := Node3D.new()
	stage.call("_fill_ship", herd, "anvil", [], [], [], "herd")
	check(herd.get_node_or_null("PenRail") != null, "a herdsman barn wears pen rails")
	var plain := Node3D.new()
	stage.call("_fill_ship", plain, "anvil", [], [], [], "")
	check(plain.get_node_or_null("CargoCan") == null, "a player's barn stays clear of hauler cans")
