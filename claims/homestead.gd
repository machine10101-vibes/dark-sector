class_name Homestead
extends RefCounted

const GROW := 20.0
const WATER_MAX := 8.0
const STARVE := 14.0
const RAID_EVERY := 48.0
const PEN_MASS := 3
const CRACK_NEED := 8.0


static func normalize(sim) -> void:
	if not sim.claim.has("owned"):
		sim.claim.owned = false
	if not sim.claim.has("frozen"):
		sim.claim.frozen = false
	if not sim.claim.has("core"):
		sim.claim.core = false
	if sim.claim.has("plot") and sim.claim.plot is Dictionary:
		sim.claim.plot.age = float(sim.claim.plot.get("age", 0.0))
		sim.claim.plot.water = float(sim.claim.plot.get("water", 0.0))
	if sim.claim.has("pen") and sim.claim.pen is Dictionary:
		sim.claim.pen.hunger = float(sim.claim.pen.get("hunger", 0.0))
		sim.claim.pen.milk = float(sim.claim.pen.get("milk", 0.0))
	sim.claim.raid_t = float(sim.claim.get("raid_t", 0.0))


static func step(sim, dt: float) -> void:
	if not bool(sim.claim.get("owned", false)):
		return
	if bool(sim.claim.get("frozen", false)):
		return
	_step_plot(sim, dt)
	_step_kine(sim, dt)
	_step_miner(sim, dt)
	sim.claim.raid_t = float(sim.claim.get("raid_t", 0.0)) + dt
	if float(sim.claim.raid_t) >= RAID_EVERY and not _miner_out(sim):
		sim.claim.raid_t = 0.0
		_summon(sim)
	_step_crack(sim, dt)


static func try_plant(sim) -> String:
	if int(sim.player.cargo.get("claim_core", 0)) < 1:
		return "No Claim Core in the hold."
	var locked: Array = sim.claim.get("locked_out", [])
	if locked.has(str(sim.player.agent_id)) and bool(sim.claim.get("owned", false)) and not bool(sim.claim.get("frozen", false)):
		return "You are locked out of this homestead. Crack the core, or plant elsewhere."
	if bool(sim.claim.get("owned", false)) and not bool(sim.claim.get("frozen", false)):
		return "A core is already in the ground."
	var blocked := _block_reason(sim)
	if blocked != "":
		return blocked
	var pocket: Dictionary = sim.defs.system.pocket
	if sim.player.pos.distance_to(sim.pocket_pos) > float(pocket.radius):
		return "The core wants the claimable pocket, not open space."
	sim.spend_cargo("claim_core", 1)
	_anchor(sim)
	sim.say("The core takes. A dome, a plot, a pen, a crate, and a weak beacon sit on the hollow.")
	sim.sfx("install")
	return ""


static func try_make_core(sim) -> String:
	if int(sim.player.cargo.get("claim_core", 0)) >= 1:
		return "A Claim Core is already in the hold."
	if int(sim.player.cargo.get("raw_mass", 0)) < 4:
		return "A Claim Core wants four units of harvested mass."
	sim.spend_cargo("raw_mass", 4)
	sim._add_cargo("claim_core", 1)
	sim.say("A Claim Core is fabricated from harvested mass.")
	sim.sfx("install")
	return ""


static func tend(sim) -> String:
	var blocked := _owner_block(sim)
	if blocked != "":
		return blocked
	if not _here(sim):
		return "Tend the plot from inside the claim."
	if bool(sim.claim.get("frozen", false)) or not bool(sim.claim.get("core", false)):
		return "The homestead is frozen. There is no living plot."
	var plot: Dictionary = sim.claim.plot
	if bool(sim.claim.get("ruptured", false)):
		return "The dome is open. Glasswheat will not take."
	var state := str(plot.get("state", "empty"))
	if state == "ripe":
		return _gather(sim)
	if state == "failed" or state == "empty":
		plot.state = "growing"
		plot.age = 0.0
		plot.water = WATER_MAX
		plot.light = 1.0
		sim.say("Glasswheat is sown under the dome.")
		return ""
	plot.water = WATER_MAX
	sim.say("The plot takes water.")
	return ""


static func feed(sim) -> String:
	var blocked := _owner_block(sim)
	if blocked != "":
		return blocked
	if not bool(sim.claim.get("owned", false)) or bool(sim.claim.get("frozen", false)):
		return "No living pen on a claim of yours."
	var pen: Dictionary = sim.claim.pen
	if not bool(pen.get("alive", false)):
		return "The hold-kine is dead."
	if not bool(pen.get("aboard", false)) and not _here(sim):
		return "Feed the kine at the pen, or while it is aboard."
	if int(sim.player.cargo.get("food_mass", 0)) > 0:
		sim.spend_cargo("food_mass", 1)
	elif int(sim.claim.crate.get("food", 0)) > 0:
		sim.claim.crate.food = int(sim.claim.crate.food) - 1
	elif int(pen.get("fodder", 0)) > 0:
		pen.fodder = int(pen.fodder) - 1
	else:
		return "The kine wants glasswheat or starter fodder."
	pen.hunger = 0.0
	sim.say("The hold-kine feeds.")
	return ""


static func haul(sim) -> String:
	var blocked := _owner_block(sim)
	if blocked != "":
		return blocked
	if not bool(sim.claim.get("owned", false)):
		return "No homestead to take a kine from."
	var pen: Dictionary = sim.claim.pen
	if bool(pen.get("aboard", false)):
		return _debark(sim)
	if not bool(pen.get("alive", false)):
		return "The hold-kine is dead."
	if not _here(sim):
		return "The kine is in the pen. Come to the claim to load it."
	var reason := _haul_block(sim)
	if reason != "":
		return reason
	pen.aboard = true
	sim.player.kine_aboard = true
	sim.say("The hold-kine is aboard.")
	sim.sfx("dock")
	return ""


static func toggle_turret(sim) -> String:
	var blocked := _owner_block(sim)
	if blocked != "":
		return blocked
	if not _here(sim) or bool(sim.claim.get("frozen", false)):
		return "Park the turret inside a living claim."
	sim.claim.turret = not bool(sim.claim.get("turret", false))
	if bool(sim.claim.turret):
		sim.say("A small gun is parked on the perimeter.")
	else:
		sim.say("The perimeter gun is back aboard.")
	return ""


static func fit_pen(sim) -> String:
	if sim.player.modules.has("livestock_pen"):
		return "A livestock pen is already on the keel."
	if int(sim.player.cargo.get("raw_mass", 0)) < PEN_MASS:
		return "A pen module wants three units of harvested mass."
	if not sim.player.yard.has("livestock_pen"):
		sim.player.yard.append("livestock_pen")
	sim.spend_cargo("raw_mass", PEN_MASS)
	var result: Dictionary = sim.install("livestock_pen")
	if not bool(result.get("ok", false)):
		sim._add_cargo("raw_mass", PEN_MASS)
		return str(result.get("reason", "The pen would not bolt."))
	return ""


static func resolve_raid(sim) -> String:
	if not bool(sim.claim.get("owned", false)) or bool(sim.claim.get("frozen", false)):
		return "quiet"
	sim.claim.erase("miner")
	if _defended(sim):
		var how := "the keel" if _player_in_pocket(sim) else "the perimeter gun"
		sim.say("A feral miner passes. %s turns it away." % how.capitalize())
		return "held"
	if not bool(sim.claim.get("ruptured", false)):
		sim.claim.dome_hp = 0.0
		sim.claim.ruptured = true
		_fail_crop(sim, "The dome is cut. Glasswheat fails.")
		sim.say("A feral miner ruptures the dome.")
		sim.sfx("hit")
		return "dome"
	var pen: Dictionary = sim.claim.pen
	if bool(pen.get("alive", false)) and not bool(pen.get("aboard", false)):
		pen.alive = false
		pen.stolen = true
		sim.say("A feral miner takes the hold-kine.")
		sim.sfx("hail")
		return "kine"
	_freeze(sim)
	sim.say("The core is cracked. The homestead freezes. The keel is still under you.")
	sim.sfx("destroyed")
	return "core"


static func text(sim) -> String:
	if not bool(sim.claim.get("owned", false)):
		return "No core in the ground.\nC plants a Claim Core inside a claimable pocket.\nM fabricates one from four harvested mass.\nHelion Dock and Aegis Prime refuse a core."
	var where := str(sim.claim.get("pocket_name", "the pocket"))
	var sys := str(sim.claim.get("system_id", ""))
	if bool(sim.claim.get("frozen", false)):
		return "Homestead at %s is frozen. The core is gone. The keel was not taken.\nSystem %s." % [where, sys]
	var plot: Dictionary = sim.claim.get("plot", {})
	var pen: Dictionary = sim.claim.get("pen", {})
	var dome := "sealed"
	if bool(sim.claim.get("ruptured", false)):
		dome = "ruptured"
	var animal := "dead"
	if bool(pen.get("stolen", false)):
		animal = "stolen"
	elif bool(pen.get("alive", false)):
		animal = "aboard" if bool(pen.get("aboard", false)) else "in the pen"
	var turret := "parked" if bool(sim.claim.get("turret", false)) else "aboard"
	var crack: Dictionary = sim.claim.get("crack", {})
	var crack_line := "Core quiet."
	if bool(crack.get("active", false)):
		crack_line = "CORE CRACK %.0f / %.0f. Loud on the chart." % [float(crack.get("t", 0.0)), CRACK_NEED]
	var owner := str(sim.claim.get("owner_name", sim.claim.get("agent_id", "")))
	return "Claim %s (%s).\nSlot %s. Owner %s.\n%s\nDome %s (%d).\nGlasswheat %s. Age %.0f. Water %.0f.\nHold-kine %s. Hunger %.0f. Milk %.0f. Fodder %d.\nCrate food %d.\nTurret %s.\nG tend  N feed  U load the kine  T turret.\nV cracks a core you do not own. X hails if you have standing and you are not in the red.\nA raid comes if the pocket is empty and the gun is aboard." % [
		where,
		sys,
		str(sim.claim.get("slot_id", "")),
		owner,
		crack_line,
		dome,
		int(sim.claim.get("dome_hp", 0)),
		str(plot.get("state", "empty")),
		float(plot.get("age", 0.0)),
		float(plot.get("water", 0.0)),
		animal,
		float(pen.get("hunger", 0.0)),
		float(pen.get("milk", 0.0)),
		int(pen.get("fodder", 0)),
		int(sim.claim.get("crate", {}).get("food", 0)),
		turret,
	]


static func _block_reason(sim) -> String:
	if str(sim.defs.system.id) == "HC-V1-R1-S1":
		return "Helion Compact law. A core does not go down on Aegis Prime or anywhere in Helion Dock."
	var pocket: Dictionary = sim.defs.system.pocket
	if not bool(pocket.get("plantable", false)):
		return "%s is closed. Compact exclusion. The core stays in the hold." % str(pocket.get("name", "This pocket"))
	if bool(pocket.get("exclusion", false)):
		return "Compact exclusion covers this pocket. The core stays in the hold."
	return ""


static func try_crack(sim, unit: Dictionary = {}) -> String:
	if unit.is_empty():
		unit = sim.player
	if not bool(sim.claim.get("owned", false)) or bool(sim.claim.get("frozen", false)) or not bool(sim.claim.get("core", false)):
		return "No living core to crack."
	if str(sim.claim.get("system_id", "")) != str(sim.defs.system.id):
		return "The core is in another system."
	if str(unit.get("agent_id", "")) == str(sim.claim.get("agent_id", "")):
		return "The core is already yours."
	if not _unit_in_pocket(sim, unit):
		return "Crack the core from inside the pocket."
	var crack: Dictionary = sim.claim.get("crack", {})
	if bool(crack.get("active", false)) and str(crack.get("agent_id", "")) == str(unit.get("agent_id", "")):
		return "The crack is already loud."
	sim.claim.crack = {"active": true, "agent_id": str(unit.agent_id), "t": 0.0}
	sim.claim.flare = true
	sim.say("%s starts cracking the core. The beacon flares." % str(unit.name))
	sim.sfx("hail")
	return ""


static func try_hail(sim, unit: Dictionary = {}) -> String:
	if unit.is_empty():
		unit = sim.player
	var crack: Dictionary = sim.claim.get("crack", {})
	if not bool(crack.get("active", false)):
		return "No one is cracking the core."
	if str(unit.get("agent_id", "")) != str(sim.claim.get("agent_id", "")):
		return "Only the owner can hail."
	if Law.at(sim, unit.pos) == "red":
		return "No Compact hail in the red."
	var standing := int(sim.quest_flags.get("compact_standing", 0))
	if standing < 1:
		return "A Compact or Charter hail wants standing."
	sim.quest_flags.compact_standing = standing - 1
	abort_crack(sim, "hail")
	if str(unit.get("class_id", "")) == "anvil":
		sim.say("A Charter-adjacent factor sends the hail with the Compact slate.")
	return ""


static func abort_crack(sim, why: String) -> bool:
	var crack: Dictionary = sim.claim.get("crack", {})
	if not bool(crack.get("active", false)):
		return false
	sim.claim.crack = {"active": false, "agent_id": "", "t": 0.0}
	sim.claim.flare = false
	if why == "recall":
		sim.say("Craft recalled. The crack stops.")
	elif why == "shot":
		sim.say("The owner fires. The crack stops.")
	elif why == "hail":
		sim.say("The hail is paid. The crack stops.")
	elif why == "leave":
		sim.say("The crack loses the pocket.")
	return true


static func _step_crack(sim, dt: float) -> void:
	var crack: Dictionary = sim.claim.get("crack", {})
	if not bool(crack.get("active", false)):
		sim.claim.flare = false
		return
	var unit = sim.human_by_agent(str(crack.get("agent_id", "")))
	if unit == null or not bool(unit.get("alive", false)) or not _unit_in_pocket(sim, unit):
		abort_crack(sim, "leave")
		return
	crack.t = float(crack.get("t", 0.0)) + dt
	sim.claim.crack = crack
	sim.claim.flare = true
	if float(crack.t) < CRACK_NEED:
		return
	_transfer(sim, unit)


static func _transfer(sim, unit: Dictionary) -> void:
	var prev := str(sim.claim.get("agent_id", ""))
	var locked: Array = sim.claim.get("locked_out", [])
	if prev != "" and not locked.has(prev):
		locked.append(prev)
	var nid := str(unit.get("agent_id", ""))
	locked.erase(nid)
	sim.claim.locked_out = locked
	sim.claim.agent_id = nid
	sim.claim.owner_name = str(unit.get("name", nid))
	sim.claim.crack = {"active": false, "agent_id": "", "t": 0.0}
	sim.claim.flare = false
	sim.say("The core changes hands. The dome, the plot, and the kine stay. The loser is locked out. The keel was not taken.")
	sim.sfx("install")


static func _unit_in_pocket(sim, unit: Dictionary) -> bool:
	if str(sim.claim.get("system_id", "")) != str(sim.defs.system.id):
		return false
	var reach := float(sim.defs.system.pocket.get("radius", 0.0))
	return unit.pos.distance_to(sim.pocket_pos) <= reach


static func _owner_block(sim) -> String:
	if not bool(sim.claim.get("owned", false)):
		return ""
	var locked: Array = sim.claim.get("locked_out", [])
	if locked.has(str(sim.player.agent_id)):
		return "You are locked out until you recapture the core or plant elsewhere."
	if str(sim.claim.get("agent_id", "")) != str(sim.player.agent_id):
		return "The homestead answers to someone else."
	return ""


static func _anchor(sim) -> void:
	var pocket: Dictionary = sim.defs.system.pocket
	sim.claim.owned = true
	sim.claim.frozen = false
	sim.claim.core = true
	sim.claim.agent_id = str(sim.player.agent_id)
	sim.claim.owner_name = str(sim.player.name)
	sim.claim.system_id = str(sim.defs.system.id)
	sim.claim.pocket_id = str(pocket.id)
	sim.claim.slot_id = "%s:%s:%s" % [str(sim.defs.system.id), str(pocket.get("anchor", "")), str(pocket.id)]
	sim.claim.pocket_name = str(pocket.name)
	sim.claim.locked_out = []
	sim.claim.crack = {"active": false, "agent_id": "", "t": 0.0}
	sim.claim.flare = false
	sim.claim.plantable = true
	sim.claim.x = sim.player.pos.x
	sim.claim.y = sim.player.pos.y
	sim.claim.dome_hp = 28.0
	sim.claim.dome_max = 28.0
	sim.claim.ruptured = false
	sim.claim.turret = false
	sim.claim.raid_t = 0.0
	sim.claim.plot = {"state": "growing", "age": 0.0, "water": WATER_MAX, "light": 1.0}
	sim.claim.pen = {
		"alive": true,
		"hunger": 0.0,
		"milk": 0.0,
		"aboard": false,
		"stolen": false,
		"fodder": 3,
	}
	sim.claim.crate = {"food": 0, "milk": 0}
	sim.player.kine_aboard = false


static func _step_plot(sim, dt: float) -> void:
	if not sim.claim.has("plot"):
		return
	var plot: Dictionary = sim.claim.plot
	if str(plot.get("state", "")) != "growing":
		return
	if bool(sim.claim.get("ruptured", false)):
		_fail_crop(sim, "The open dome kills the glasswheat.")
		return
	plot.light = 1.0
	plot.water = maxf(0.0, float(plot.water) - dt)
	if float(plot.water) <= 0.0:
		_fail_crop(sim, "Glasswheat dries out. The plot failed.")
		return
	plot.age = float(plot.age) + dt
	if float(plot.age) >= GROW:
		plot.state = "ripe"
		sim.say("Glasswheat is ready under the dome.")


static func _step_kine(sim, dt: float) -> void:
	if not sim.claim.has("pen"):
		return
	var pen: Dictionary = sim.claim.pen
	if not bool(pen.get("alive", false)):
		return
	pen.hunger = float(pen.get("hunger", 0.0)) + dt
	if float(pen.hunger) >= STARVE:
		pen.alive = false
		pen.aboard = false
		sim.player.kine_aboard = false
		sim.say("The hold-kine starves.")
		sim.sfx("destroyed")
		return
	if float(pen.hunger) < 5.0:
		pen.milk = float(pen.get("milk", 0.0)) + dt


static func _gather(sim) -> String:
	var plot: Dictionary = sim.claim.plot
	plot.state = "empty"
	plot.age = 0.0
	sim.claim.crate.food = int(sim.claim.crate.get("food", 0)) + 2
	var stats := Fit.stats(sim.defs, sim.player)
	if Fit.cargo_used(sim.player) < int(stats.cargo_cap):
		sim._add_cargo("food_mass", 1)
	if Fit.cargo_used(sim.player) < int(stats.cargo_cap):
		sim._add_cargo("food_mass", 1)
	sim.say("Glasswheat comes off the plot. Food mass is in the crate and the hold.")
	sim.sfx("extract")
	return ""


static func _fail_crop(sim, why: String) -> void:
	if not sim.claim.has("plot"):
		return
	if str(sim.claim.plot.get("state", "")) == "failed":
		return
	sim.claim.plot.state = "failed"
	sim.claim.plot.water = 0.0
	sim.say(why)


static func _debark(sim) -> String:
	if not _here(sim):
		return "Put the kine down inside the claim."
	sim.claim.pen.aboard = false
	sim.player.kine_aboard = false
	sim.say("The hold-kine is back in the pen.")
	return ""


static func _haul_block(sim) -> String:
	if str(sim.player.class_id) == "anvil":
		return ""
	if sim.player.modules.has("farm_cassette") or sim.player.modules.has("livestock_pen"):
		return ""
	return "The hold-kine needs a farm cassette or a livestock pen. Anvil can carry one bare. Anyone else bolts the cassette or spends mass on a pen."


static func _here(sim) -> bool:
	if not bool(sim.claim.get("owned", false)):
		return false
	if str(sim.claim.get("system_id", "")) != str(sim.defs.system.id):
		return false
	var pocket: Dictionary = sim.defs.system.pocket
	return sim.player.pos.distance_to(sim.pocket_pos) <= float(pocket.get("radius", 0.0))


static func _player_in_pocket(sim) -> bool:
	return _here(sim)


static func _defended(sim) -> bool:
	if bool(sim.claim.get("turret", false)):
		return true
	return _player_in_pocket(sim)


static func _freeze(sim) -> void:
	sim.claim.frozen = true
	sim.claim.core = false
	sim.claim.ruptured = true
	sim.claim.dome_hp = 0.0
	sim.claim.turret = false
	if sim.claim.has("plot"):
		sim.claim.plot.state = "failed"


static func _summon(sim) -> void:
	if str(sim.defs.system.id) != str(sim.claim.get("system_id", "")):
		resolve_raid(sim)
		return
	var edge: Vector2 = sim.pocket_pos + Vector2.from_angle(sim.time) * (float(sim.defs.system.pocket.radius) + 80.0)
	sim.claim.miner = {"x": edge.x, "y": edge.y}
	sim.say("A feral miner is on the hollow.")


static func _miner_out(sim) -> bool:
	return sim.claim.has("miner")


static func _step_miner(sim, dt: float) -> void:
	if not sim.claim.has("miner"):
		return
	if str(sim.defs.system.id) != str(sim.claim.get("system_id", "")):
		resolve_raid(sim)
		return
	var miner: Dictionary = sim.claim.miner
	var pos := Vector2(float(miner.x), float(miner.y))
	var dest := Vector2(float(sim.claim.get("x", sim.pocket_pos.x)), float(sim.claim.get("y", sim.pocket_pos.y)))
	var to := dest - pos
	var dist := to.length()
	if _defended(sim):
		resolve_raid(sim)
		return
	if dist < 28.0:
		resolve_raid(sim)
		return
	var step: float = 90.0 * dt
	if step > dist:
		step = dist
	var next: Vector2 = pos + to / dist * step
	miner.x = next.x
	miner.y = next.y
