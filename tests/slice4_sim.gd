extends SceneTree

var defs: Dictionary = {}
var fails := 0


func _init() -> void:
	defs = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": Serde.load_json("res://data/system.json"),
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
	}
	_pack()
	_hunt_and_break()
	_heat_ladder()
	_hangar_and_repair()
	_death_and_save()
	_still_works()
	if fails == 0:
		print("SLICE4 PASS")
	else:
		print("SLICE4 FAIL %d" % fails)
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


func _pack() -> void:
	var sim := make("vesper")
	var aegis = sim.planet("aegis_prime")
	var green_r := float(sim.defs.system.zones.green.radius)
	var pirates: Array = []
	var roles := {}
	var parts := {}
	for actor in sim.actors:
		if str(actor.team) != "red_keel":
			continue
		pirates.append(actor)
		roles[str(actor.ai.role)] = true
		parts[str(actor.modules[0])] = true
		check(actor.pos.distance_to(aegis.pos) > green_r + 80.0, "%s sits outside the green lane" % actor.name)
	check(pirates.size() >= 2 and pirates.size() <= 4, "the pack is two to four hulls")
	check(bool(roles.get("interceptor", false)) and bool(roles.get("kite", false)), "the pack has an interceptor and a kite")
	check(parts.size() >= 2, "the hulls wear different scavenged parts")
	var shot_at: Vector2 = sim.player.pos
	sim.player.fire_cd = 0.0
	var before := float(sim.heat.helion_compact)
	sim.try_fire(sim.player, Fit.stats(defs, sim.player).gun)
	check(float(sim.heat.helion_compact) == before + 12.0, "a shot in sight of the patrol raises heat")
	check(not sim.pdo_alert, "the first shot does not open fire from the patrol")
	var travel: Vector2 = sim.projectiles[0].pos
	sim.hold_npc = true
	sim.tick(0.15, {})
	var traveled := sim.projectiles.is_empty()
	if not traveled:
		traveled = sim.projectiles[0].pos.distance_to(travel) > 20.0
	check(traveled, "a shot travels or lands")
	var quiet := make("vesper")
	for actor in quiet.actors:
		if str(actor.team) == "helion_compact":
			actor.pos = Vector2(9000, 9000)
	quiet.player.pos = quiet.pack_pos
	quiet.player.fire_cd = 0.0
	var parked := float(quiet.heat.helion_compact)
	quiet.try_fire(quiet.player, Fit.stats(defs, quiet.player).gun)
	check(float(quiet.heat.helion_compact) == parked, "a shot at the pack, out of patrol sight, adds no heat")


func _hunt_and_break() -> void:
	var sim := make("kestrel")
	var interceptor := {}
	var kite := {}
	for actor in sim.actors:
		if str(actor.team) != "red_keel":
			continue
		if str(actor.ai.role) == "interceptor":
			interceptor = actor
		elif str(actor.ai.role) == "kite":
			kite = actor
	var probe := {}
	for item in sim.craft:
		if str(item.def_id) == "survey_probe":
			probe = item
	probe.state = "working"
	probe.order = "scan"
	probe.target = "seized_hold"
	probe.speed = 0.0
	probe.pos = interceptor.pos + Vector2(180, 20)
	sim.player.pos = interceptor.home + Vector2(2200, 0)
	sim.player.fight_cd = 0.0
	var probe_d: float = interceptor.pos.distance_to(probe.pos)
	sim.tick(0.7, {})
	check(interceptor.pos.distance_to(probe.pos) < probe_d - 15.0, "the interceptor closes on the probe")
	check(interceptor.pos.distance_to(probe.pos) < interceptor.pos.distance_to(sim.player.pos), "the probe stays the quarry")
	var hold := make("kestrel")
	var holder := {}
	for actor in hold.actors:
		if str(actor.team) == "red_keel" and str(actor.ai.role) == "kite":
			holder = actor
	hold.player.pos = holder.home + Vector2(180, 0)
	holder.pos = holder.home
	holder.rot = PI
	hold.player.fight_cd = 0.0
	var open_d: float = holder.pos.distance_to(hold.player.pos)
	hold.tick(0.55, {})
	var kite_after: float = holder.pos.distance_to(hold.player.pos)
	check(kite_after > open_d + 10.0, "the kite backs out of close range (%.1f -> %.1f)" % [open_d, kite_after])
	var flee := make("vesper")
	var chaser := {}
	for actor in flee.actors:
		if str(actor.team) == "red_keel" and str(actor.ai.role) == "interceptor":
			chaser = actor
	var aegis = flee.planet("aegis_prime")
	var lane := float(aegis.radius) + 80.0
	flee.player.pos = aegis.pos + Vector2(lane, 0)
	flee.player.fight_cd = 0.0
	chaser.pos = aegis.pos + Vector2(lane, 320)
	chaser.rot = (chaser.home - chaser.pos).angle()
	var leave: float = chaser.pos.distance_to(flee.player.pos)
	flee.tick(0.55, {})
	var left: float = chaser.pos.distance_to(flee.player.pos)
	check(left > leave + 15.0, "deep in the green with guns quiet, the pack breaks off")
	var press := make("vesper")
	var hunter := {}
	for actor in press.actors:
		if str(actor.team) == "red_keel" and str(actor.ai.role) == "interceptor":
			hunter = actor
	var press_lane := float(aegis.radius) + 80.0
	press.player.pos = aegis.pos + Vector2(press_lane, 0)
	press.player.fight_cd = 3.0
	hunter.pos = aegis.pos + Vector2(press_lane, 320)
	hunter.rot = (press.player.pos - hunter.pos).angle()
	var closing: float = hunter.pos.distance_to(press.player.pos)
	press.tick(0.6, {})
	check(hunter.pos.distance_to(press.player.pos) < closing - 10.0, "keeping fire up holds the chase inside the lane")


func _heat_ladder() -> void:
	var hailed := make("anvil")
	hailed.heat.helion_compact = 14.0
	hailed.hold_npc = true
	hailed.tick(0.1, {})
	check(hailed.hailed, "heat 14 draws a hail")
	check("Heave to" in hailed.banner, "the hail is on the banner")
	check(hailed.heat_stage() == "hail", "the slate stage is hail")
	var fined := make("anvil")
	fined.heat.helion_compact = 30.0
	fined.player.cargo["raw_mass"] = 3
	fined.hold_npc = true
	fined.tick(0.1, {})
	check(fined.fined, "heat 30 fines the hold")
	check(int(fined.player.cargo.get("raw_mass", 0)) == 2, "the fine takes one unit of cargo")
	check(fined.heat_stage() == "fine", "the slate stage is fine")
	var guns := make("kestrel")
	guns.heat.helion_compact = 45.0
	var patrol := {}
	for actor in guns.actors:
		if str(actor.team) == "helion_compact":
			patrol = actor
			break
	patrol.pos = guns.player.pos + Vector2(220, 0)
	patrol.vel = Vector2.ZERO
	patrol.rot = PI
	patrol.fire_cd = 0.0
	guns.tick(0.12, {})
	var guard_shot := false
	for shot in guns.projectiles:
		if str(shot.team) == "helion_compact":
			guard_shot = true
	check(guard_shot, "heat at the gun line makes the patrol fire")
	check(guns.pdo_alert, "the gun line raises the patrol")
	check(guns.heat_stage() == "guns", "the slate stage is guns")
	var spike := make("vesper")
	var cutter := {}
	for actor in spike.actors:
		if str(actor.team) == "helion_compact":
			cutter = actor
			break
	var base := float(spike.heat.helion_compact)
	spike.damage_unit(cutter, 1.0, "agent:captain")
	check(float(spike.heat.helion_compact) >= base + 28.0, "shooting the patrol spikes heat")
	check(spike.pdo_alert, "shooting the patrol makes them hostile")
	var provoked := make("vesper")
	var pirate := {}
	for actor in provoked.actors:
		if str(actor.team) == "red_keel":
			pirate = actor
			break
	pirate.ai.fired_on_captain = true
	provoked.heat.helion_compact = 10.0
	pirate.hp = 1.0
	provoked.damage_unit(pirate, 8.0, "agent:captain")
	check(float(provoked.heat.helion_compact) == 5.0, "a pirate who fired first costs no heat and eases the slate")
	var seized := make("vesper")
	var loot := {}
	for actor in seized.actors:
		if str(actor.team) == "red_keel":
			loot = actor
			break
	loot.pos = seized.trash_pos
	loot.ai.fired_on_captain = false
	loot.hp = 1.0
	seized.damage_unit(loot, 8.0, "agent:captain")
	check(absf(float(seized.heat.helion_compact) - 6.0) < 0.1, "an unprovoked kill in the trash field adds a little heat")
	check(int(seized.wrecks[-1].cargo.get("scrap", 0)) == 1, "the wreck keeps a scrap, not a jackpot")


func _hangar_and_repair() -> void:
	var sim := make("vesper")
	check(sim.install("gun_sponson").ok, "the cheek gun still bolts")
	var live := float(Fit.stats(defs, sim.player).gun.damage)
	sim.player.module_hp["gun_sponson"] = 0.0
	var dark := float(Fit.stats(defs, sim.player).gun.damage)
	check(dark < live - 0.5, "a dark module stops lending its gun")
	var probe := ""
	for item in sim.craft:
		if str(item.def_id) == "survey_probe":
			probe = str(item.uid)
			item.state = "working"
			item.pos = sim.player.pos + Vector2(400, 0)
			item.speed = 0.0
	sim.player.hangar_hp = 0.0
	var blocked := CraftOrders.order(sim, probe, "return", "")
	check("hangar" in blocked.to_lower(), "a down hangar refuses recall")
	var craft = {}
	for item in sim.craft:
		if str(item.uid) == probe:
			craft = item
	check(str(craft.state) != "returning", "recall does not start while the hangar is down")
	craft.state = "returning"
	craft.pos = sim.player.pos
	craft.speed = 400.0
	sim.hold_npc = true
	sim.tick(0.4, {})
	check(str(craft.state) != "docked", "a down hangar does not take the craft aboard")
	sim.player.pos = sim.beacon_pos
	sim.player.hp = 20.0
	sim.player.cargo["raw_mass"] = 2
	check(sim.try_repair() == "", "the dock beacon welds")
	check(int(sim.player.cargo.get("raw_mass", 0)) == 1, "repair spends one harvested mass")
	check(float(sim.player.hangar_hp) == float(sim.player.hangar_max), "repair restores the hangar")
	check(float(sim.player.hp) == 48.0, "repair restores hull")
	check(float(sim.player.module_hp.gun_sponson) == 22.0, "repair restores the dark module")
	var home := CraftOrders.order(sim, probe, "return", "")
	check(home == "", "recall works again after the weld")


func _death_and_save() -> void:
	var sim := make("anvil")
	check(sim.install("cargo_blister").ok, "the blister is on the keel")
	sim.player.cargo["raw_mass"] = 4
	sim.player.hp = 1.0
	var dock = sim.planet("aegis_prime")
	var spawn: Vector2 = dock.pos + Vector2(float(dock.radius) + SectorSim.DOCK_GAP, 40.0)
	sim.player.pos = sim.pack_pos
	sim.damage_unit(sim.player, 80.0, "agent:red_keel:0")
	check(bool(sim.player.alive), "the captain wakes")
	check(sim.player.modules.has("cargo_blister"), "the layout stays bolted")
	check(sim.player.pos.distance_to(spawn) < 8.0, "respawn is Helion Dock")
	check(int(sim.player.cargo.get("raw_mass", 0)) == 2, "some cargo stays aboard")
	check(sim.wrecks.size() == 1, "the break leaves a wreck")
	check(int(sim.wrecks[0].cargo.get("raw_mass", 0)) == 2, "the wreck holds the rest of the cargo")
	sim.heat.helion_compact = 18.0
	sim.fined = true
	sim.hailed = true
	sim.player.hangar_hp = 7.0
	sim.player.hp = 40.0
	var data := sim.to_dict()
	var copy := SectorSim.new(defs)
	copy.from_dict(data)
	check(absf(float(copy.heat.helion_compact) - 18.0) < 0.1, "reload keeps heat")
	check(copy.fined and copy.hailed, "reload keeps the slate marks")
	check(absf(float(copy.player.hangar_hp) - 7.0) < 0.1, "reload keeps hangar damage")
	check(absf(float(copy.player.hp) - 40.0) < 0.1, "reload keeps hull damage")
	check(copy.wrecks.size() == 1, "reload keeps the wreck")
	check(copy.player.modules.has("cargo_blister"), "reload keeps the layout")


func _still_works() -> void:
	var sim := make("anvil")
	sim.hold_npc = true
	var probe := ""
	for item in sim.craft:
		if str(item.def_id) == "survey_probe":
			probe = str(item.uid)
	check(CraftOrders.order(sim, probe, "scan", "aegis_ring") == "", "the probe still takes a scan")
	var guard := 0
	while not sim.dossier_complete("aegis_ring") and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	check(sim.dossier_complete("aegis_ring"), "the probe still seals a dossier")
	sim.player.pos = sim.survey_node("aegis_ring").pos + Vector2(160, 20)
	var drone := ""
	for item in sim.craft:
		if str(item.def_id) == "harvest_drone":
			drone = str(item.uid)
	var before := int(sim.player.cargo.get("raw_mass", 0))
	check(CraftOrders.order(sim, drone, "launch", "aegis_ring") == "", "the drone still launches")
	guard = 0
	while int(sim.player.cargo.get("raw_mass", 0)) == before and guard < 900:
		sim.tick(0.05, {})
		guard += 1
	check(int(sim.player.cargo.get("raw_mass", 0)) == before + 1, "harvest still returns mass")
	check(sim.install("sensor_mast").ok, "a module still bolts after the fight systems")
