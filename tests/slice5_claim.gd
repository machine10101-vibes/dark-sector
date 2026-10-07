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
		"claim": Serde.load_json("res://data/claim.json"),
		"harvest": Serde.load_json("res://data/harvest.json"),
	}
	_gates()
	_garden()
	_hen_dies()
	_hen_fed()
	_turret()
	_crack()
	if fails == 0:
		print("SLICE5 PASS")
	else:
		print("SLICE5 FAIL %d" % fails)
	quit(fails)


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func make() -> SectorSim:
	var sim := SectorSim.new(defs)
	sim.new_game("anvil")
	sim.hold_npc = true
	sim.player.vel = Vector2.ZERO
	return sim


func _gates() -> void:
	var sim := make()
	check(PocketRules.print_core(sim) != "" and int(sim.player.cargo.get("claim_core", 0)) == 0, "core print refuses an empty hold")
	sim.player.cargo["cinder_ore"] = 4
	sim.player.pos = sim.pocket_pos + Vector2(900, 0)
	check(sim.zone_at(sim.player.pos) != "pocket", "test print happens outside the Latch")
	check(PocketRules.print_core(sim) != "", "core prints from cinder-ore")
	check(int(sim.player.cargo.get("cinder_ore", 0)) == 2, "print spends two ore")
	check(int(sim.player.cargo.get("claim_core", 0)) == 1, "core sits in the hold")
	var ship_name := str(sim.player.name)
	check(PocketRules.plant(sim).find("will not bite") >= 0 or not bool(sim.claim.core), "core will not plant outside the Latch")
	check(not bool(sim.claim.core), "outside plant leaves the stake empty")
	sim.player.pos = sim.pocket_pos + Vector2(40, 20)
	check(PocketRules.plant(sim) != "", "core plants inside Hollow Latch")
	check(bool(sim.claim.core) and bool(sim.claim.owned) and not bool(sim.claim.frozen), "stake is owned and live")
	check(str(sim.claim.agent_id) == "agent:captain", "core keeps the captain agent id")
	check(bool(sim.player.alive) and str(sim.player.name) == ship_name, "planting does not replace the ship")


func _garden() -> void:
	var sim := _planted(6)
	check(PocketRules.raise_dome(sim) != "", "ash dome rises")
	check(bool(sim.claim.dome), "dome flag is up")
	check(PocketRules.sow(sim) != "", "ember kale is sown")
	check(str(sim.claim.crop.id) == "ember_kale", "crop id is ember kale")
	for _i in 400:
		sim.tick(0.05, {})
	check(bool(sim.claim.crop.ready), "kale ripens on the sim clock")
	check(PocketRules.harvest(sim) != "", "kale comes aboard")
	check(int(sim.player.cargo.get("ember_kale", 0)) == 1, "hold has ember kale")
	check(not bool(sim.claim.crop.ready), "the same sowing starts another season")
	check(bool(sim.player.alive), "harvest leaves the keel")


func _hen_dies() -> void:
	var sim := _planted(4)
	PocketRules.raise_dome(sim)
	PocketRules.stock_animal(sim)
	check(bool(sim.claim.animal.alive), "ash hen is stocked")
	for _i in 500:
		sim.tick(0.05, {})
	check(not bool(sim.claim.animal.alive), "unfed hen dies")
	check(str(sim.claim.animal.id) == "ash_hen", "dead hen stays on the slate")
	check(bool(sim.claim.core), "her death does not crack the core")
	check(bool(sim.player.alive), "her death does not delete the ship")


func _hen_fed() -> void:
	var sim := _planted(4)
	PocketRules.raise_dome(sim)
	PocketRules.sow(sim)
	for _i in 400:
		sim.tick(0.05, {})
	PocketRules.harvest(sim)
	PocketRules.stock_animal(sim)
	sim.claim.animal.hunger = 20.0
	check(PocketRules.feed_animal(sim) != "", "kale feeds the hen")
	check(float(sim.claim.animal.hunger) == 0.0, "feeding clears hunger")
	for _i in 80:
		sim.tick(0.05, {})
	check(bool(sim.claim.animal.alive), "a fed hen survives the next stretch")


func _turret() -> void:
	var sim := _planted(2)
	sim.player.cargo["salvage_parts"] = 1
	sim.player.pos = sim.pocket_pos + Vector2(-200, 0)
	check(PocketRules.stake_turret(sim) != "", "turret stakes from keel salvage")
	check(bool(sim.claim.defense.online), "turret is online")
	var pirate := _pirate(sim)
	pirate.pos = sim.pocket_pos + Vector2(180, 0)
	pirate.vel = Vector2.ZERO
	pirate.hp = 40.0
	var before := float(pirate.hp)
	for _i in 80:
		sim.tick(0.05, {})
	check(float(pirate.hp) < before, "stake turret hits a Red Keel in the Latch")
	check(bool(sim.claim.core) and not bool(sim.claim.frozen), "a defended core stays live")


func _crack() -> void:
	var sim := _planted(4)
	PocketRules.raise_dome(sim)
	PocketRules.sow(sim)
	var before_pos: Vector2 = sim.player.pos
	var klass := str(sim.player.class_id)
	var pirate := _pirate(sim)
	pirate.pos = sim.pocket_pos + Vector2(36, 0)
	pirate.vel = Vector2.ZERO
	pirate.hp = 800.0
	for _i in 160:
		sim.tick(0.05, {})
	check(bool(sim.claim.frozen) and not bool(sim.claim.core), "a skiff on an undefended stake cracks the core")
	check(bool(sim.claim.owned), "the frozen pocket stays on the slate")
	check(bool(sim.claim.dome), "the dome is not deleted")
	check(str(sim.claim.crop.id) == "ember_kale", "the sowing survives the freeze")
	check(bool(sim.player.alive), "core loss does not wreck the ship")
	check(str(sim.player.class_id) == klass, "the same keel is still the player")
	check(sim.player.pos.distance_to(before_pos) < 80.0, "the ship is not removed from the sector")
	sim.player.cargo["cinder_ore"] = 2
	sim.player.pos = sim.pocket_pos
	PocketRules.print_core(sim)
	PocketRules.plant(sim)
	check(bool(sim.claim.core) and not bool(sim.claim.frozen), "replant wakes the same stake")
	check(bool(sim.claim.dome), "the dome is still the one that froze")
	var raw := sim.to_dict()
	var copy := SectorSim.new(defs)
	copy.from_dict(raw)
	check(bool(copy.claim.core) and bool(copy.claim.dome), "claim core and dome survive the log")
	check(str(copy.claim.crop.id) == "ember_kale", "sowing survives the log")
	check(str(copy.claim.agent_id) == "agent:captain", "claim agent survives the log")
	check(bool(copy.player.alive), "the loaded keel is the same ship")


func _planted(ore: int) -> SectorSim:
	var sim := make()
	sim.player.cargo["cinder_ore"] = ore
	sim.player.pos = sim.pocket_pos + Vector2(30, 10)
	PocketRules.print_core(sim)
	PocketRules.plant(sim)
	return sim


func _pirate(sim: SectorSim) -> Dictionary:
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			return actor
	return {}
