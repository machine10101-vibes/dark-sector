extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("BOUNTY SLATE PASS")
	else:
		print("BOUNTY SLATE FAIL %d" % fails)
	quit(fails)
	return true


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func _heard(sim, needle: String) -> bool:
	for raw in sim.lines:
		var line: Dictionary = raw
		if str(line.text).find(needle) >= 0:
			return true
	return false


func _first(sim, team: String) -> Dictionary:
	for actor in sim.actors:
		if str(actor.team) == team and bool(actor.alive):
			return actor
	return {}


func _break(sim, unit: Dictionary, attacker: String) -> void:
	unit.pos = Vector2(50000, 50000)
	unit.vel = Vector2.ZERO
	unit.hp = 1.0
	unit.shield = 0.0
	unit.armor_hp = 0.0
	unit.ai.fired_on_captain = false
	sim.damage_unit(unit, 40.0, attacker)


func _run() -> void:
	var defs := Catalog.boot()
	var skiff: Dictionary = defs.ships.skiff
	var cutter: Dictionary = defs.ships.cutter
	check(int(skiff.bounty) == 24, "a Red Keel skiff posts 24 GRT")
	check(int(cutter.bounty) == 0, "a Compact cutter posts no bounty")
	check(int(defs.ships.anvil.get("bounty", 0)) == 0, "a Barn posts no bounty")
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.hold_npc = true
	var pirate := _first(sim, "red_keel")
	check(not pirate.is_empty(), "Helion still launches a skiff")
	if pirate.is_empty():
		return
	var ship_name := str(pirate.name)
	var red0 := float(sim.heat.get("red_keel", 0.0))
	var slate0 := float(sim.heat.get(sim._pdo_id(), 0.0))
	var scrap_before := int(pirate.cargo.get("scrap", 0))
	_break(sim, pirate, "agent:captain")
	check(not bool(pirate.alive), "the skiff breaks")
	check(DockBoard.purse(sim) == 24, "the captain collects 24 GRT")
	check(_heard(sim, "Bounty 24 on %s. Purse 24." % ship_name), "the helm names the bounty and the purse")
	check(_heard(sim, "will remember %s" % ship_name), "the pack still remembers the skiff")
	check(absf(float(sim.heat.get("red_keel", 0.0)) - (red0 + 10.0)) < 0.1, "the pack heat is unchanged by the purse")
	check(absf(float(sim.heat.get(sim._pdo_id(), 0.0)) - slate0) < 0.1, "a skiff bounty does not touch the Compact slate")
	check(int(sim.wrecks[-1].cargo.get("scrap", 0)) == scrap_before, "the bounty leaves the wreck hold alone")
	var other := _first(sim, "red_keel")
	check(not other.is_empty(), "a second skiff is still flying")
	if other.is_empty():
		return
	sim.player.pos = other.pos + Vector2(280, 0)
	var caption: String = sim.lock_caption(other)
	check(caption == "LOCK  %s  ·  280 m  ·  bounty 24" % str(other.name), "the lock line posts the bounty (%s)" % caption)
	var patrol := _first(sim, "helion_compact")
	var purse_after := DockBoard.purse(sim)
	sim.lines.clear()
	_break(sim, patrol, "agent:captain")
	check(not bool(patrol.alive), "the cutter breaks")
	check(DockBoard.purse(sim) == purse_after, "patrol blood pays no bounty")
	check(_heard(sim, "A Compact cutter is gone"), "the slate still names a lost cutter")
	check(not _heard(sim, "Bounty"), "a cutter kill does not speak a bounty")
	var mate := _first(sim, "red_keel")
	sim.lines.clear()
	_break(sim, mate, "agent:red_keel:9")
	check(not bool(mate.alive), "a packmate can still break a skiff")
	check(DockBoard.purse(sim) == purse_after, "a packmate's kill does not pay the captain")
	check(not _heard(sim, "Bounty"), "a packmate's kill stays off the bounty slate")
	var barn := SectorSim.new(defs)
	barn.new_game("anvil")
	barn.hold_npc = true
	barn.quest_flags.purse = 10
	var hull := barn._blank_ship("anvil", "Lost Barn", "agent:civilian:lost", "npc", "civilian")
	hull.cargo = {"ice_spall": 3}
	barn._kill(hull, "captain")
	check(DockBoard.purse(barn) == 10, "a civilian wreck pays no bounty")
	check(not _heard(barn, "Bounty"), "a civilian wreck does not speak a bounty")
	check(int(barn.wrecks[-1].cargo.get("ice_spall", 0)) == 3, "the civilian hold stays on the wreck")
