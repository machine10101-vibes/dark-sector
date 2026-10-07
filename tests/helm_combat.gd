extends SceneTree

var defs: Dictionary = {}
var fails := 0
var reached := 0


func _init() -> void:
	defs = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": Serde.load_json("res://data/system.json"),
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
	}
	_tank_layers()
	_capacitor_and_heat()
	_locks()
	_turrets()
	_orders()
	_kill_the_cutter()
	check(reached == 6, "every section ran to the end (%d of 6)" % reached)
	if fails == 0:
		print("HELM COMBAT PASS")
	else:
		print("HELM COMBAT FAIL %d" % fails)
	quit(fails)


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func make(class_id: String) -> SectorSim:
	var sim := SectorSim.new(defs)
	sim.new_game(class_id)
	return sim


func _free(sim: SectorSim) -> void:
	sim.player.moored = false
	sim.quest_flags.moor_latch = 0.0
	sim.hold_npc = true
	var dock = sim.planet(str(sim.defs.system.pdo.home))
	var out: Vector2 = (sim.player.pos - dock.pos).normalized()
	sim.player.pos += out * 900.0
	sim.player.rot = out.angle()
	sim.player.vel = Vector2.ZERO


func _actor(sim: SectorSim, team: String) -> Dictionary:
	for actor in sim.actors:
		if str(actor.team) == team and bool(actor.alive):
			return actor
	return {}


func _park(sim: SectorSim, unit: Dictionary, offset: Vector2) -> void:
	var nose := Vector2.from_angle(float(sim.player.rot))
	unit.pos = sim.player.pos + nose.rotated(offset.angle()) * offset.length()
	unit.vel = Vector2.ZERO


func _tank_layers() -> void:
	var sim := make("vesper")
	var p: Dictionary = sim.player
	check(float(p.shield) == 40.0 and float(p.armor_hp) == 24.0 and float(p.hp) == 64.0, "the Needle starts with shield, plate, and hull")
	check(float(p.cap) == 60.0, "the Needle starts with a full capacitor")
	sim.damage_unit(p, 50.0, "world")
	check(float(p.shield) == 0.0 and absf(float(p.armor_hp) - 14.0) < 0.01 and float(p.hp) == 64.0, "a big hit spends shield, then plate, and spares the hull")
	sim.damage_unit(p, 20.0, "world")
	check(float(p.armor_hp) == 0.0 and absf(float(p.hp) - 58.0) < 0.01, "the hull only takes what the plate could not")
	var stats := Fit.stats(defs, p)
	HelmCombat.step_systems(sim, p, stats, 1.0, false)
	check(float(p.shield) == 0.0, "shields wait after a hit")
	HelmCombat.step_systems(sim, p, stats, 3.0, false)
	check(float(p.shield) > 0.0, "shields climb back once the hits stop")
	var belted := make("anvil")
	var before := float(belted.player.armor_max)
	check(belted.install("armor_belt").ok, "the armor belt bolts")
	belted.tick(0.05, {})
	check(float(belted.player.armor_max) > before + 30.0 and float(belted.player.armor_hp) >= float(belted.player.armor_max) - 0.1, "the belt adds plate you can see")
	var guard := make("vesper")
	var cutter := _actor(guard, "helion_compact")
	check(float(cutter.get("shield", 0.0)) > 0.0 and float(cutter.get("armor_hp", 0.0)) > 0.0, "the cutter runs the same tank layers")
	reached += 1


func _capacitor_and_heat() -> void:
	var sim := make("vesper")
	var p: Dictionary = sim.player
	var gun: Dictionary = Fit.stats(defs, p).gun
	p.fire_cd = 0.0
	var cap0 := float(p.cap)
	check(sim.try_fire(p, gun), "the starter gun fires")
	check(float(p.cap) < cap0 and float(p.therm) > 0.0, "a shot costs capacitor and heat")
	p.fire_cd = 0.0
	p.cap = 1.0
	check(not sim.try_fire(p, gun), "a dry capacitor holds the gun")
	p.cap = 60.0
	p.fire_cd = 0.0
	p.therm = 99.0
	var sig_cold := HelmCombat.effective_signature(sim, {"class_id": "vesper", "modules": [], "therm": 0.0})
	check(HelmCombat.effective_signature(sim, p) > sig_cold * 1.3, "heat widens the signature")
	sim.try_fire(p, gun)
	check(bool(p.overheat), "a hot volley forces a shutdown")
	p.fire_cd = 0.0
	check(not sim.try_fire(p, gun), "an overheated gun stays cold")
	HelmCombat.step_systems(sim, p, Fit.stats(defs, p), 9.0, false)
	check(not bool(p.overheat), "the plates cool and the guns come back")
	reached += 1


func _locks() -> void:
	var sim := make("vesper")
	_free(sim)
	var cutter := _actor(sim, "helion_compact")
	var skiff := _actor(sim, "red_keel")
	_park(sim, cutter, Vector2(420, 0))
	_park(sim, skiff, Vector2(260, 120))
	sim.tick(0.05, {"lock_cycle": 1})
	check(str(sim.player.lock_id) == str(skiff.agent_id), "Tab picks the nearest contact first")
	sim.tick(0.05, {"lock_cycle": 1})
	check(str(sim.player.lock_id) == str(cutter.agent_id), "Tab again steps to the next contact")
	var need := Fit.lock_time(Fit.stats(defs, sim.player).scan_res, HelmCombat.effective_signature(sim, cutter))
	check(need > 1.0 and need < 2.4, "the Needle locks a cutter in under two and a half seconds (%.2f)" % need)
	check(not bool(sim.player.lock_ok), "a lock takes time")
	for i in int(need / 0.1) + 3:
		sim.tick(0.1, {})
	check(bool(sim.player.lock_ok), "the lock lands after the scan time")
	var barn := make("anvil")
	var barn_need := Fit.lock_time(Fit.stats(defs, barn.player).scan_res, 0.6)
	check(barn_need > need + 0.6, "the Barn's coarse scan locks slower")
	cutter.pos = sim.player.pos + Vector2(Fit.stats(defs, sim.player).sensor * 1.4, 0)
	sim.tick(0.1, {})
	check(not bool(sim.player.lock_ok) and str(sim.player.lock_id) == "", "a lock breaks past sensor range")
	reached += 1


func _turrets() -> void:
	var sim := make("vesper")
	_free(sim)
	var gun: Dictionary = Fit.stats(defs, sim.player).gun
	var still := {"pos": sim.player.pos + Vector2(300, 0), "vel": Vector2.ZERO}
	check(HelmCombat.hit_chance(sim.player, still, gun) > 0.99, "a still target inside optimal is a sure hit")
	var crossing := {"pos": sim.player.pos + Vector2(300, 0), "vel": Vector2(0, 340)}
	check(HelmCombat.hit_chance(sim.player, crossing, gun) < 0.6, "high transversal spoils the shot")
	var far := {"pos": sim.player.pos + Vector2(gun.optimal + gun.falloff, 0), "vel": Vector2.ZERO}
	var far_chance := HelmCombat.hit_chance(sim.player, far, gun)
	check(absf(far_chance - 0.5) < 0.02, "one falloff past optimal is a coin flip")
	var skiff := _actor(sim, "red_keel")
	_park(sim, skiff, Vector2.from_angle(0.8) * 320.0)
	HelmCombat.set_lock(sim, sim.player, str(skiff.agent_id))
	sim.player.lock_ok = true
	sim.player.fire_cd = 0.0
	sim.projectiles.clear()
	sim.try_fire(sim.player, gun)
	var shot: Dictionary = sim.projectiles[-1]
	var off: float = absf(Vector2(shot.vel).angle_to(skiff.pos - sim.player.pos))
	check(bool(shot.turret) and off < 0.15, "a locked turret traverses off the nose to the target")
	reached += 1


func _orders() -> void:
	var sim := make("vesper")
	_free(sim)
	var skiff := _actor(sim, "red_keel")
	_park(sim, skiff, Vector2(900, 0))
	sim.tick(0.05, {"order": {"kind": "approach", "target": str(skiff.agent_id)}})
	for i in 160:
		sim.tick(0.05, {})
	check(sim.player.pos.distance_to(skiff.pos) < 320.0, "approach closes on the target (%.0f m)" % sim.player.pos.distance_to(skiff.pos))
	sim.tick(0.05, {"order": {"kind": "orbit", "target": str(skiff.agent_id), "range": 320.0}})
	var spread: Array = []
	for i in 600:
		sim.tick(0.05, {})
		if i > 300:
			spread.append(sim.player.pos.distance_to(skiff.pos))
	var lo: float = spread.min()
	var hi: float = spread.max()
	check(lo > 180.0 and hi < 480.0, "orbit holds the ring (%.0f to %.0f m)" % [lo, hi])
	check(sim.player.vel.length() > 60.0, "orbit keeps the keel moving")
	sim.tick(0.05, {"order": {"kind": "keep", "target": str(skiff.agent_id), "range": 600.0}})
	for i in 300:
		sim.tick(0.05, {})
	var kept: float = sim.player.pos.distance_to(skiff.pos)
	check(absf(kept - 600.0) < 140.0, "keep at range sits near the range (%.0f m)" % kept)
	sim.tick(0.05, {"order": {"kind": "stop"}})
	for i in 200:
		sim.tick(0.05, {})
	check(sim.player.vel.length() < 10.0 and sim.player.order.is_empty(), "all stop brings the keel to rest")
	sim.tick(0.05, {"order": {"kind": "approach", "target": str(skiff.agent_id)}})
	sim.tick(0.05, {"thrust": 1.0})
	check(sim.player.order.is_empty(), "manual thrust takes the helm back")
	reached += 1


func _kill_the_cutter() -> void:
	var sim := make("vesper")
	_free(sim)
	var cutter := _actor(sim, "helion_compact")
	_park(sim, cutter, Vector2(380, 0))
	sim.tick(0.05, {"lock": str(cutter.agent_id)})
	for i in 40:
		sim.tick(0.05, {})
	check(bool(sim.player.lock_ok), "the cutter is locked")
	sim.tick(0.05, {"order": {"kind": "orbit", "target": str(cutter.agent_id), "range": 300.0}})
	sim.hold_npc = false
	cutter.home = cutter.pos
	cutter.ai.radius = 0.0
	for actor in sim.actors:
		if actor != cutter and str(actor.team) != "civilian":
			actor.pos = sim.player.pos + Vector2(40000, 40000)
			actor.home = actor.pos
	var turret_shots := 0
	var shield_hit := false
	var took_shield := false
	for i in 1600:
		sim.tick(0.05, {"fire": true})
		for shot in sim.projectiles:
			if bool(shot.get("turret", false)) and str(shot.team) == str(sim.player.team):
				turret_shots += 1
		if float(cutter.get("shield", 1.0)) < float(cutter.get("shield_max", 0.0)):
			shield_hit = true
		if str(sim.player.get("hit_layer", "")) == "shield":
			took_shield = true
		if not bool(cutter.alive):
			break
	print("fight: %.1fs, Needle shield %.0f plate %.0f hull %.0f" % [sim.time, sim.player.shield, sim.player.armor_hp, sim.player.hp])
	check(took_shield, "the cutter's return fire lands on the Needle's shield")
	check(shield_hit, "the cutter's shield takes the first hits")
	check(turret_shots > 0, "the Needle returns fire with the turret while orbiting")
	check(not bool(cutter.alive), "the cutter breaks")
	var wreck: Dictionary = {}
	for row in sim.wrecks:
		if str(row.agent_id) == str(cutter.agent_id):
			wreck = row
	check(not wreck.is_empty(), "the cutter leaves a wreck")
	if wreck.is_empty():
		reached += 1
		return
	sim.tick(0.05, {"order": {"kind": "approach", "target": str(wreck.id), "range": 40.0}})
	for i in 300:
		sim.tick(0.05, {})
	var line: String = sim.try_salvage(str(wreck.id))
	check(line == "ok" and int(sim.player.cargo.get("salvage_parts", 0)) >= 1, "the wreck is looted into the hold (%s)" % line)

	reached += 1
