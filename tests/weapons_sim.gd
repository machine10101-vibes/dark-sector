extends SceneTree

var defs: Dictionary = {}
var fails := 0
var frames := 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	_run()
	if fails == 0:
		print("WEAPONS PASS")
	else:
		print("WEAPONS FAIL %d" % fails)
	quit(fails)
	return true


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func _run() -> void:
	defs = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": Serde.load_json("res://data/system.json"),
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
	}
	_meshes()
	_families()
	_fights()
	_purse()


func _meshes() -> void:
	var stage: Node = load("res://world/stage3d.gd").new()
	stage.call("_ready")
	var worn := Node3D.new()
	stage.call("_fill_ship", worn, "vesper", [], [], ["gun_sponson", "laser_bank", "missile_rack"])
	var gun := worn.get_node_or_null("gun_sponson") as Node3D
	var beam := worn.get_node_or_null("laser_bank") as Node3D
	var rack := worn.get_node_or_null("missile_rack") as Node3D
	check(gun != null and beam != null and rack != null, "Needle wears turret, bank, and rack")
	if gun != null and beam != null and rack != null:
		check(gun.position.distance_to(beam.position) > 4.0, "turret and bank sit apart")
		check(gun.position.distance_to(rack.position) > 4.0, "turret and rack sit apart")
		check(beam.position.distance_to(rack.position) > 4.0, "bank and rack sit apart")
		check(gun.get_node_or_null("BarrelP") != null, "turret has barrels")
		check(beam.get_node_or_null("LensP") != null, "bank has a lens")
		check(rack.get_node_or_null("Tube0") != null, "rack has a tube")
	var bare := Node3D.new()
	stage.call("_fill_ship", bare, "vesper", [], [], [])
	check(bare.get_node_or_null("gun_sponson") == null, "undo clears the turret")
	check(bare.get_node_or_null("laser_bank") == null, "undo clears the bank")
	check(bare.get_node_or_null("missile_rack") == null, "undo clears the rack")
	var barn := Node3D.new()
	stage.call("_fill_ship", barn, "anvil", [], [], ["heavy_turret", "missile_rack"])
	var beak := Node3D.new()
	stage.call("_fill_ship", beak, "kestrel", [], [], ["gun_sponson", "laser_bank"])
	var barn_gun := barn.get_node_or_null("heavy_turret") as Node3D
	var beak_gun := beak.get_node_or_null("gun_sponson") as Node3D
	check(barn_gun != null and beak_gun != null, "Barn and Beak grow their own mounts")
	if barn_gun != null and beak_gun != null:
		check(barn_gun.position.distance_to(beak_gun.position) > 4.0, "Barn turret and Beak cheek do not share a seat")


func _families() -> void:
	var iron: Dictionary = HelmCombat.layer_bias({"family": "bullet", "load": "iron", "signature": 0.4})
	var tungsten: Dictionary = HelmCombat.layer_bias({"family": "bullet", "load": "tungsten", "signature": 0.4})
	var incendiary: Dictionary = HelmCombat.layer_bias({"family": "bullet", "load": "incendiary", "signature": 0.4})
	check(float(iron.hull) > float(tungsten.hull), "iron prefers hull")
	check(float(tungsten.armor) > float(iron.armor), "tungsten prefers armor")
	check(float(incendiary.shield) < float(iron.shield) and float(incendiary.heat) > 0.0, "incendiary is weak on shields and leaves heat")
	var ultraviolet: Dictionary = HelmCombat.layer_bias({"family": "laser", "load": "ultraviolet", "signature": 0.4})
	var infrared: Dictionary = HelmCombat.layer_bias({"family": "laser", "load": "infrared", "signature": 0.4})
	check(float(ultraviolet.shield) > float(infrared.shield), "ultraviolet shreds shields")
	var splinter: Dictionary = HelmCombat.layer_bias({"family": "missile", "load": "splinter", "signature": 0.32})
	var siege: Dictionary = HelmCombat.layer_bias({"family": "missile", "load": "siege", "signature": 0.32})
	check(float(splinter.hull) > float(siege.hull), "siege is poor against a frigate")
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	var bare: Dictionary = Fit.stats(defs, sim.player)
	check(sim.install("gun_sponson").ok, "cheek gun bolts")
	check(sim.install("laser_bank").ok, "beam bank bolts")
	check(sim.install("missile_rack").ok, "missile rack bolts")
	var worn: Dictionary = Fit.stats(defs, sim.player)
	check(float(worn.signature) > float(bare.signature), "the three mounts raise signature")
	check(float(worn.mass) > float(bare.mass), "the three mounts raise mass")
	var names: Array = []
	for mount in Fit.mounts(defs, sim.player):
		names.append(str(mount.socket))
	check(names.has("gun_sponson") and names.has("laser_bank") and names.has("missile_rack"), "three sockets are live")
	sim.uninstall("gun_sponson")
	sim.uninstall("laser_bank")
	sim.uninstall("missile_rack")
	check(Fit.mounts(defs, sim.player).is_empty(), "pulling the mounts restores a clean fit")


func _fights() -> void:
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.hold_npc = true
	sim.player.moored = false
	sim.player.pos = Vector2(8000, 8000)
	sim.player.vel = Vector2.ZERO
	sim.player.rot = 0.0
	var skiff: Dictionary = sim._blank_ship("skiff", "Skiff", "agent:red_keel:test", "npc", "red_keel")
	skiff.pos = sim.player.pos + Vector2(280, 0)
	skiff.vel = Vector2.ZERO
	skiff.alive = true
	sim.actors.append(skiff)
	HelmCombat.set_lock(sim, sim.player, str(skiff.agent_id))
	sim.player.lock_ok = true
	sim.player.lock_t = 4.0
	check(sim.install("gun_sponson").ok, "the turret is the test gun")
	var turret: Dictionary = Fit.mounts(defs, sim.player)[0]
	var stopped := _marks(sim, turret, skiff, Vector2.ZERO)
	var orbit := _marks(sim, turret, skiff, Vector2(0, 560))
	check(stopped > orbit, "the turret marks a stopped skiff more often than an orbit (%d vs %d)" % [stopped, orbit])
	skiff.pos = sim.player.pos + Vector2(280, 0)
	skiff.vel = Vector2.ZERO
	var still_chance := HelmCombat.hit_chance(sim.player, skiff, turret)
	skiff.vel = Vector2(0, 560)
	var orbit_chance := HelmCombat.hit_chance(sim.player, skiff, turret)
	check(orbit_chance < still_chance * 0.55, "orbit chance is much worse (%.2f vs %.2f)" % [orbit_chance, still_chance])
	sim.uninstall("gun_sponson")
	check(sim.install("laser_bank").ok, "the bank is the test gun")
	var bank: Dictionary = Fit.mounts(defs, sim.player)[0]
	skiff.vel = Vector2.ZERO
	skiff.pos = sim.player.pos + Vector2(280, 0)
	sim.player.cap = 0.0
	sim.player.mount_cd = {}
	sim.beams = []
	check(not sim.try_fire(sim.player, bank), "a dry capacitor holds the beam")
	check(sim.beams.is_empty(), "a dry bank draws no beam")
	sim.player.cap = 40.0
	var shield_before := float(skiff.shield)
	var hull_before := float(skiff.hp)
	check(sim.try_fire(sim.player, bank), "the bank fires while the capacitor holds")
	check(float(sim.player.cap) < 40.0, "the beam spends capacitor")
	check(not sim.beams.is_empty(), "the beam is a visible segment")
	check(float(skiff.shield) < shield_before or float(skiff.hp) < hull_before, "the beam reaches the skiff")
	sim.player.cap = 0.0
	sim.player.mount_cd = {}
	check(not sim.try_fire(sim.player, bank), "the bank cuts out again at empty")
	sim.uninstall("laser_bank")
	_missile_flak(sim, skiff)
	_missile_run(sim, skiff)


func _marks(sim: SectorSim, gun: Dictionary, skiff: Dictionary, vel: Vector2) -> int:
	var hits := 0
	skiff.pos = sim.player.pos + Vector2(280, 0)
	for i in 20:
		skiff.vel = vel
		sim.player.fire_cd = 0.0
		sim.player.mount_cd = {}
		sim.player.cap = 80.0
		sim.player.therm = 0.0
		sim.player.overheat = false
		sim.projectiles.clear()
		if sim.try_fire(sim.player, gun) and not sim.projectiles.is_empty():
			if str(sim.projectiles[-1].get("mark", "")) != "":
				hits += 1
	return hits


func _missile_flak(sim: SectorSim, skiff: Dictionary) -> void:
	sim.player.modules = ["point_defense"]
	sim.player.module_hp = {"point_defense": 22.0}
	sim.player.pos = Vector2(9000, 9000)
	sim.player.cap = 40.0
	sim.player.mount_cd = {}
	sim.impacts = []
	sim.projectiles = [{
		"family": "missile",
		"load": "splinter",
		"blast": 30.0,
		"steer": 0.4,
		"target": "",
		"pos": sim.player.pos + Vector2(70, 0),
		"vel": Vector2(-30, 0),
		"damage": 20.0,
		"team": "red_keel",
		"ttl": 3.0,
		"agent_id": str(skiff.agent_id),
		"mark": "",
	}]
	sim._step_projectiles(0.05)
	check(sim.projectiles.is_empty(), "point defense shoots the missile down")
	var flak := false
	for row in sim.impacts:
		if str(row.get("kind", "")) == "flak":
			flak = true
	check(flak, "the intercept leaves flak")


func _missile_run(sim: SectorSim, skiff: Dictionary) -> void:
	sim.player.modules = []
	sim.player.pos = Vector2(-4000, -4000)
	skiff.pos = Vector2(160, 0)
	skiff.vel = Vector2.ZERO
	skiff.alive = true
	skiff.hp = 80.0
	skiff.shield = 0.0
	skiff.armor_hp = 0.0
	var caught := _chase(sim, skiff, Vector2(210, 0), 2.4)
	check(caught, "a stopped hull cannot walk away from the missile")
	skiff.pos = Vector2(420, 0)
	skiff.vel = Vector2(0, 720)
	skiff.hp = 80.0
	skiff.shield = 0.0
	var escaped := not _chase(sim, skiff, Vector2(210, 0), 2.6)
	check(escaped, "a hard sideways burn leaves the missile behind")


func _chase(sim: SectorSim, skiff: Dictionary, vel: Vector2, seconds: float) -> bool:
	var start := float(skiff.hp)
	sim.projectiles = [{
		"family": "missile",
		"load": "splinter",
		"blast": 28.0,
		"steer": 1.05,
		"target": str(skiff.agent_id),
		"pos": Vector2.ZERO,
		"vel": vel,
		"damage": 30.0,
		"team": "captain",
		"ttl": seconds,
		"agent_id": "agent:captain",
		"mark": "",
	}]
	var steps := int(seconds / 0.05)
	for _i in steps:
		if sim.projectiles.is_empty():
			return float(skiff.hp) < start
		sim._step_projectiles(0.05)
		skiff.pos += skiff.vel * 0.05
	return float(skiff.hp) < start


func _purse() -> void:
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.player.pos = sim.beacon_pos
	sim.player.moored = true
	sim.quest_flags.purse = DockBoard.SCAN_PAY
	check(DockBoard.at_pad(sim), "the counter is the Helion pad")
	check(DockBoard.buy_kit(sim, "gun_sponson") == "", "the first slip buys one mount")
	check(DockBoard.purse(sim) == 0, "one mount spends the slip")
	check(DockBoard.paid_mount(sim, "gun_sponson"), "the cheek gun is paid")
	var second := DockBoard.buy_kit(sim, "laser_bank")
	check(second != "", "the same purse cannot buy a second family")
	check(not DockBoard.paid_mount(sim, "laser_bank"), "the bank stays unpaid")
	sim.quest_flags.purse = DockBoard.KIT.iron_belt.price + DockBoard.KIT.splinter_pack.price
	check(DockBoard.buy_kit(sim, "iron_belt") == "", "the pad sells an iron belt")
	check(DockBoard.buy_kit(sim, "splinter_pack") == "", "the pad sells a splinter reload")
	check(int(sim.player.rounds.iron) > 40, "iron lands in the hold")
	check(int(sim.player.rounds.splinter) > 8, "splinter lands in the hold")
