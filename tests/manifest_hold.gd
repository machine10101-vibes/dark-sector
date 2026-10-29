extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("MANIFEST HOLD PASS")
	else:
		print("MANIFEST HOLD FAIL %d" % fails)
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
	var spec: Dictionary = defs.craft.manifest_drone
	check(str(spec.role) == "scanner", "the Manifest is a scanner")
	check(str(spec.post) == "Manifest", "the Manifest names its post")
	check(not spec.has("gun"), "the Manifest carries no gun")
	check(DockBoard.support_shop_ids().has("manifest_drone"), "the pad rack lists the Manifest")
	check(int(DockBoard.SUPPORT_SHOP.manifest_drone.price) == 44, "the Manifest costs 44 GRT")
	check(int(DockBoard.SUPPORT_SHOP.manifest_drone.cap) == 1, "the rack holds one Manifest")
	check(DockBoard.recipe_ids().has("manifest_drone"), "the yard has a Manifest plan")
	var need: Dictionary = DockBoard.recipe_need("manifest_drone")
	check(int(need.aluminum_bar) == 1 and int(need.copper_slag) == 1, "a Manifest takes one aluminum and one copper")
	var sim := SectorSim.new(defs)
	sim.new_game("kestrel")
	sim.hold_npc = true
	var clerk: Dictionary = sim._haul_manifest("clerk")
	var tug: Dictionary = sim._haul_manifest("tow")
	var herd: Dictionary = sim._haul_manifest("herd")
	check(int(clerk.aluminum_bar) == 1 and int(clerk.ice_spall) == 2, "a clerk hold is a bar and ice")
	check(int(tug.hull_plate) == 2 and int(tug.salvage_parts) == 1, "a tug hold is plate and salvage")
	check(int(herd.fodder) == 3 and int(herd.milk_analogue) == 1, "a herdsman hold is fodder and milk")
	var wing_before := DockBoard.attack_count(sim)
	sim.quest_flags.purse = 44
	check(DockBoard.buy_support(sim, "manifest_drone") == "", "the pad sells a Manifest")
	check(DockBoard.attack_count(sim) == wing_before, "a Manifest does not fill the attack wing")
	check(not CraftOrders.is_attack(sim, "manifest_drone"), "a Manifest is not an attack drone")
	var craft = null
	for item in sim.craft:
		if str(item.def_id) == "manifest_drone":
			craft = item
	check(craft != null, "the Manifest is on the rack")
	if craft == null:
		return
	check(CraftOrders.launch(sim, "manifest_drone") == "", "the Manifest launches")
	var sky := Vector2(40000, 40000)
	sim.player.pos = sky
	sim.player.vel = Vector2.ZERO
	sim.player.rot = 0.0
	var holt := {}
	for actor in sim.actors:
		if str(actor.name) == "Hauler Holt":
			holt = actor
		else:
			actor.pos = Vector2(90000, 0)
	check(not holt.is_empty(), "Hauler Holt is on the lane")
	if holt.is_empty():
		return
	check(int(holt.manifest.ice_spall) == 4 and int(holt.manifest.copper_slag) == 2, "Hauler Holt carries ice and copper")
	check(holt.cargo.is_empty(), "the readable hold stays off the loot cargo")
	holt.pos = sky + Vector2(400, 0)
	holt.alive = true
	craft.state = "escort"
	craft.order = "manifest"
	craft.read_id = ""
	craft.pos = sky
	craft.vel = Vector2.ZERO
	craft.battery = 140.0
	var shots := sim.projectiles.size()
	var heard := ""
	for _i in 16:
		CraftOrders.step(sim, craft, 0.25)
		if not sim.lines.is_empty() and str(sim.lines[0].text).find("Hold:") >= 0:
			heard = str(sim.lines[0].text)
			break
	check(heard.find("Manifest") >= 0 and heard.find("Hauler Holt") >= 0, "a Manifest names the hauler")
	check(heard.find("Ice spall 4") >= 0 and heard.find("Copper slag 2") >= 0, "a Manifest reads the hold")
	check(int(holt.manifest.ice_spall) == 4 and int(holt.manifest.copper_slag) == 2, "the scan leaves the goods aboard")
	check(holt.cargo.is_empty(), "the scan does not move goods into loot cargo")
	check(sim.projectiles.size() == shots, "a Manifest does not shoot")
	check(str(craft.state) == "returning", "a Manifest turns for home after the reading")
	holt.manifest = {}
	craft.state = "escort"
	craft.order = "manifest"
	craft.read_id = ""
	craft.pos = sky
	craft.vel = Vector2.ZERO
	craft.battery = 140.0
	sim.lines.clear()
	var empty := ""
	for _j in 16:
		CraftOrders.step(sim, craft, 0.25)
		if not sim.lines.is_empty() and str(sim.lines[0].text).find("Hold:") >= 0:
			empty = str(sim.lines[0].text)
			break
	check(empty.find("the hold is empty") >= 0, "an empty hold is named empty")
	for actor in sim.actors:
		if str(actor.team) == "civilian":
			actor.pos = Vector2(120000, 120000)
	craft.state = "escort"
	craft.order = "manifest"
	craft.read_id = ""
	craft.pos = sky
	craft.vel = Vector2.ZERO
	craft.battery = 140.0
	for _k in 8:
		CraftOrders.step(sim, craft, 0.25)
	var parked: float = craft.pos.distance_to(sky + Vector2(0, 140))
	check(parked < 30.0, "with no hauler in reach the Manifest holds the beam (%.0f m)" % parked)
	check(str(craft.state) == "escort", "the beam watch stays out")
	var wrecks_before := sim.wrecks.size()
	sim._kill(holt, "captain")
	check(sim.wrecks.size() == wrecks_before + 1, "a hauler still leaves a wreck")
	if sim.wrecks.size() > wrecks_before:
		var wreck: Dictionary = sim.wrecks[sim.wrecks.size() - 1]
		check((wreck.cargo as Dictionary).is_empty(), "the hauler wreck stays empty")
	var stage: Node = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	var reader: Node3D = stage.call("pose_craft", "manifest_drone")
	check(reader.get_node_or_null("Slate") != null and reader.get_node_or_null("Reader") != null and reader.get_node_or_null("LampScan") != null, "the Manifest wears a slate, a reader, and a scan lamp")
