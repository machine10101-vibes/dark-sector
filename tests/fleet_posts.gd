extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("FLEET POSTS PASS")
	else:
		print("FLEET POSTS FAIL %d" % fails)
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
	var sentry: Dictionary = defs.craft.sentry_drone
	check(str(sentry.role) == "attack", "the Sentry is an attack drone")
	check(str(sentry.post) == "Sentry", "the Sentry names its post")
	check(float(sentry.gun.range) == 520.0, "the Sentry gun reaches 520 meters")
	check(DockBoard.attack_shop_ids().has("sentry_drone"), "the pad rack lists the Sentry")
	check(int(DockBoard.ATTACK_SHOP.sentry_drone.price) == 96, "the Sentry costs 96 GRT")
	check(int(DockBoard.ATTACK_SHOP.sentry_drone.cap) == 1, "the rack holds one Sentry")
	check(DockBoard.recipe_ids().has("sentry_drone"), "the yard has a Sentry plan")
	var need: Dictionary = DockBoard.recipe_need("sentry_drone")
	check(int(need.aluminum_bar) == 2 and int(need.steel_bar) == 1, "a Sentry takes two aluminum and one steel")
	var lead := Vector2(0, 800)
	var mark := Vector2.ZERO
	var dart: Vector2 = CraftOrders._attack_slot(0, mark, lead, "dart_drone")
	var sting: Vector2 = CraftOrders._attack_slot(0, mark, lead, "sting_drone")
	var fang: Vector2 = CraftOrders._attack_slot(0, mark, lead, "fang_drone")
	var lance: Vector2 = CraftOrders._attack_slot(0, mark, lead, "lance_drone")
	var screen: Vector2 = CraftOrders._attack_slot(0, mark, lead, "fighter")
	check(dart.length() < 90.0, "a Dart crosses the bow")
	check(absf(sting.x) > 160.0 and absf(sting.y) < 20.0, "a Sting holds the beam")
	check(fang.length() > lance.length() + 80.0, "a Fang keeps longer range than a Lance")
	check(screen.length() > dart.length() + 40.0, "a fighter still holds the screen")
	var sim := SectorSim.new(defs)
	sim.new_game("kestrel")
	sim.hold_npc = true
	var craft: Dictionary = sim._make_craft("sentry_drone", 1)
	sim.craft.append(craft)
	check(CraftOrders.launch(sim, "sentry_drone") == "", "the Sentry launches onto the wing")
	var sky := Vector2(40000, 40000)
	sim.player.pos = sky
	sim.player.vel = Vector2.ZERO
	sim.player.rot = 0.0
	craft.state = "escort"
	craft.order = "escort"
	craft.pos = sky
	craft.vel = Vector2.ZERO
	craft.battery = 140.0
	for actor in sim.actors:
		actor.pos = Vector2(90000, 0)
	for _i in 8:
		CraftOrders.step(sim, craft, 0.25)
	var parked: float = craft.pos.distance_to(sim.player.pos)
	check(parked > 40.0 and parked < 220.0, "a Sentry holds aft of the keel (%.0f m)" % parked)
	var quarry := {}
	for actor in sim.actors:
		if str(actor.team) == "red_keel":
			quarry = actor
			break
	quarry.pos = sky + Vector2(180, 0)
	quarry.alive = true
	var nose := Vector2.from_angle(sim.player.rot)
	var beam := Vector2(-nose.y, nose.x)
	var seat := 0
	var index := 0
	for item in sim.craft:
		if item == craft:
			seat = index
		index += 1
	var flank := 1.0 if seat % 2 == 0 else -1.0
	craft.pos = sim.player.pos - nose * 70.0 + beam * flank * (90.0 + float(seat) * 28.0)
	craft.vel = Vector2.ZERO
	craft.fire_cd = 0.0
	craft.rot = (quarry.pos - craft.pos).angle()
	var shots := sim.projectiles.size()
	CraftOrders.step(sim, craft, 0.2)
	check(sim.projectiles.size() > shots, "a Sentry fires the ship in range and does not chase it")
	check(craft.pos.distance_to(sim.player.pos) < 220.0, "the Sentry is still on its point after the shot")
	var stage: Node = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	var pen: Node3D = stage.call("pose_craft", "livestock_lighter")
	check(pen.get_node_or_null("Pen") != null and pen.get_node_or_null("Stall") != null and pen.get_node_or_null("Ramp") != null, "the livestock lighter wears a pen, a stall, and a ramp")
	var gun: Node3D = stage.call("pose_craft", "sentry_drone")
	check(gun.get_node_or_null("Turret") != null and gun.get_node_or_null("Barrel") != null, "the Sentry wears a turret and a barrel")
	var skiff := Node3D.new()
	stage.call("_fill_ship", skiff, "skiff", [], [], [], "interceptor")
	check(skiff.get_node_or_null("PostSpike") != null, "an interceptor skiff wears a spike")
	var kite := Node3D.new()
	stage.call("_fill_ship", kite, "skiff", [], [], [], "kite")
	check(kite.get_node_or_null("PostFinP") != null, "a kite skiff wears long fins")
	var raider := Node3D.new()
	stage.call("_fill_ship", raider, "skiff", [], [], [], "raider")
	check(raider.get_node_or_null("PostClawP") != null, "a raider skiff wears claws")
	var cutter := Node3D.new()
	stage.call("_fill_ship", cutter, "cutter", [], [], [], "range")
	check(cutter.get_node_or_null("RangeRail") != null, "a range cutter wears a firing rail")
	var writ := Node3D.new()
	stage.call("_fill_ship", writ, "cutter", [], [], [], "bailiff")
	check(writ.get_node_or_null("WritBoard") != null, "a bailiff cutter wears the writ board")
	var clerk := Node3D.new()
	stage.call("_fill_ship", clerk, "cutter", [], [], [], "clerk")
	check(clerk.get_node_or_null("ScalePan") != null, "a clerk cutter wears the scale")
