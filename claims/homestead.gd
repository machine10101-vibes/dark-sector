class_name Homestead
extends RefCounted

const GROW := 20.0
const WATER_MAX := 8.0
const STARVE := 14.0
const RAID_EVERY := 48.0
const PEN_MASS := 3
const CRACK_NEED := 8.0
const CROPS := ["glasswheat", "voidbean", "ember_kale", "ghost_gourd"]
const ANIMALS := ["ash_hen", "rock_crab"]


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
	if not sim.claim.has("stock"):
		sim.claim.stock = []
	sim.claim.raid_t = float(sim.claim.get("raid_t", 0.0))


static func step(sim, dt: float) -> void:
	if not bool(sim.claim.get("owned", false)):
		return
	if bool(sim.claim.get("frozen", false)):
		return
	_step_plot(sim, dt)
	_step_kine(sim, dt)
	_step_stock(sim, dt)
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
	var crop := str(plot.get("crop", "glasswheat"))
	if state == "ripe" and crop != "glasswheat":
		return _gather_named(sim, crop)
	if state == "growing" and crop != "glasswheat":
		return _tend_named(sim, plot, crop)
	if state == "ripe":
		return _gather(sim)
	if state == "failed" or state == "empty":
		plot.state = "growing"
		plot.crop = "glasswheat"
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
	var stock_line := _stock_line(sim)
	var turret := "parked" if bool(sim.claim.get("turret", false)) else "aboard"
	var crack: Dictionary = sim.claim.get("crack", {})
	var crack_line := "Core quiet."
	if bool(crack.get("active", false)):
		crack_line = "CORE CRACK %.0f / %.0f. Loud on the chart." % [float(crack.get("t", 0.0)), CRACK_NEED]
	var owner := str(sim.claim.get("owner_name", sim.claim.get("agent_id", "")))
	var body := "Claim %s (%s).\nSlot %s. Owner %s.\n%s\nDome %s (%d).\nGlasswheat %s. Age %.0f. Water %.0f.\nHold-kine %s. Hunger %.0f. Milk %.0f. Fodder %d.\nCrate food %d.\nTurret %s.\nG tend  N feed  U load the kine  T turret.\nV cracks a core you do not own. X hails if you have standing and you are not in the red.\nA raid comes if the pocket is empty and the gun is aboard." % [
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
	if stock_line != "":
		body += "\n" + stock_line
	return body


static func _block_reason(sim) -> String:
	if str(sim.defs.system.id) == "HC-V1-R1-S1":
		return "Helion Compact law. A core does not go down on Aegis Prime or anywhere in Helion Dock."
	var pocket: Dictionary = sim.defs.system.pocket
	if not bool(pocket.get("plantable", false)):
		return "%s is closed. Compact exclusion. The core stays in the hold." % str(pocket.get("name", "This pocket"))
	if bool(pocket.get("exclusion", false)):
		return "Compact exclusion covers this pocket. The core stays in the hold."
	if sim.defs.has("claim_slots"):
		var book = sim.defs.get("claim_slots", {})
		if typeof(book) == TYPE_DICTIONARY:
			var slots = book.get("slots", [])
			if typeof(slots) == TYPE_ARRAY and not slots.is_empty():
				var filed := false
				var sys_id := str(sim.defs.system.id)
				var pocket_id := str(pocket.get("id", ""))
				for slot in slots:
					if typeof(slot) != TYPE_DICTIONARY:
						continue
					if str(slot.get("system_id", "")) == sys_id and str(slot.get("pocket_id", "")) == pocket_id:
						filed = true
						break
				if not filed:
					return "No claim slot is filed for this pocket."
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
	var crop := str(plot.get("crop", "glasswheat"))
	if crop != "glasswheat":
		_step_named_crop(sim, plot, crop, dt)
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


static func sow(sim, crop_id: String) -> String:
	var data_crop := _data_crop(sim, crop_id)
	if (not CROPS.has(crop_id) and data_crop.is_empty()) or crop_id == "glasswheat":
		return "That is not a new crop."
	var blocked := _owner_block(sim)
	if blocked != "":
		return blocked
	if not _here(sim):
		return "Sow from inside the claim."
	if bool(sim.claim.get("ruptured", false)):
		return "The dome is open. Nothing will take."
	var plot: Dictionary = sim.claim.plot
	plot.crop = crop_id
	plot.state = "growing"
	plot.age = 0.0
	plot.light = 1.0
	plot.shade = 0.0
	plot.gone = 0.0
	plot.tend_age = 0.0
	if crop_id == "voidbean":
		plot.water = 5.0
		sim.say("Voidbean is sown. It wants shade. Open light kills it.")
	elif crop_id == "ember_kale":
		plot.water = 3.0
		sim.say("Ember kale is sown. It wants heat, and it rots if you drown it.")
	elif not data_crop.is_empty():
		plot.water = float(data_crop.get("water", WATER_MAX))
		plot.motion = 0.0
		sim.say(str(data_crop.get("line", "%s is sown." % str(data_crop.get("name", crop_id)))))
	else:
		plot.water = WATER_MAX
		sim.say("Ghost gourd is sown. Leave the pocket and it collapses.")
	return ""


static func stock(sim, kind: String) -> String:
	var animal_def := _data_animal(sim, kind)
	if not ANIMALS.has(kind) and animal_def.is_empty():
		return "That animal is not on the slate."
	var blocked := _owner_block(sim)
	if blocked != "":
		return blocked
	if not bool(sim.claim.get("owned", false)):
		return "No claim to stock."
	if int(sim.player.cargo.get("food_mass", 0)) < 1 and int(sim.claim.get("crate", {}).get("food", 0)) < 1:
		return "Stock wants a unit of food mass."
	if int(sim.player.cargo.get("food_mass", 0)) > 0:
		sim.spend_cargo("food_mass", 1)
	else:
		sim.claim.crate.food = int(sim.claim.crate.food) - 1
	var herd: Array = sim.claim.get("stock", [])
	var stock_name := "Ash hen" if kind == "ash_hen" else "Rock crab"
	if not animal_def.is_empty():
		stock_name = str(animal_def.get("name", kind))
	herd.append({
		"kind": kind,
		"alive": true,
		"hunger": 0.0,
		"yield": 0.0,
		"name": stock_name,
	})
	sim.claim.stock = herd
	if kind == "ash_hen":
		sim.say("An ash hen is in the coop. She wants grit. Hunger kills her.")
	elif kind == "rock_crab":
		sim.say("A rock crab is in the cage. It drinks the plot. A dry plot kills it.")
	else:
		sim.say(str(animal_def.get("line", "%s is in the pen." % stock_name)))
	return ""


static func lighter_transfer(sim) -> String:
	if not bool(sim.claim.get("owned", false)) or bool(sim.claim.get("frozen", false)):
		sim.say("The lighter finds no living claim.")
		return "none"
	if str(sim.claim.get("system_id", "")) != str(sim.defs.system.id):
		sim.say("The lighter is in the wrong system for this claim.")
		return "away"
	var pen: Dictionary = sim.claim.pen
	if bool(pen.get("aboard", false)):
		pen.aboard = false
		sim.player.kine_aboard = false
		sim.say("The lighter sets the hold-kine back in the pen.")
		sim.sfx("dock")
		return "unloaded"
	if not bool(pen.get("alive", false)):
		sim.say("The lighter finds no living hold-kine.")
		return "dead"
	pen.aboard = true
	sim.player.kine_aboard = true
	sim.say("The lighter brings the hold-kine onto the keel.")
	sim.sfx("dock")
	return "loaded"


static func _tend_named(sim, plot: Dictionary, crop: String) -> String:
	if crop == "voidbean":
		plot.light = 0.0
		plot.shade = 0.0
		sim.say("Shade on the voidbean.")
		return ""
	if crop == "ember_kale":
		plot.water = float(plot.get("water", 0.0)) + 2.0
		plot.tend_age = 0.0
		if float(plot.water) > 8.0:
			_fail_crop(sim, "Ember kale rots in the wet.")
			return ""
		sim.say("Ember kale takes a little water and keeps its heat.")
		return ""
	var tended := _data_crop(sim, crop)
	if not tended.is_empty():
		plot.motion = 0.0
		sim.say(str(tended.get("tend_line", "You sit with the %s." % str(tended.get("name", crop)))))
		return ""
	plot.gone = 0.0
	sim.say("You stay with the ghost gourd.")
	return ""


static func _step_named_crop(sim, plot: Dictionary, crop: String, dt: float) -> void:
	if bool(sim.claim.get("ruptured", false)):
		_fail_crop(sim, "The open dome kills the %s." % crop.replace("_", " "))
		return
	if crop == "voidbean":
		plot.water = maxf(0.0, float(plot.water) - dt * 0.35)
		if float(plot.light) > 0.5:
			plot.shade = float(plot.get("shade", 0.0)) + dt
		if float(plot.shade) > 6.0:
			_fail_crop(sim, "Voidbean scorches in the open light.")
			return
		if float(plot.water) <= 0.0:
			_fail_crop(sim, "Voidbean dries out.")
			return
		if float(plot.water) > 9.0:
			_fail_crop(sim, "Voidbean drowns.")
			return
	elif crop == "ember_kale":
		plot.water = maxf(0.0, float(plot.water) - dt * 1.4)
		plot.tend_age = float(plot.get("tend_age", 0.0)) + dt
		if float(plot.water) <= 0.0:
			_fail_crop(sim, "Ember kale freezes dry.")
			return
		if float(plot.tend_age) > 7.0:
			_fail_crop(sim, "Ember kale loses its heat.")
			return
	elif not _data_crop(sim, crop).is_empty():
		_step_data_crop(sim, plot, _data_crop(sim, crop), dt)
		return
	else:
		plot.water = maxf(0.0, float(plot.water) - dt)
		if not _here(sim):
			plot.gone = float(plot.get("gone", 0.0)) + dt
		else:
			plot.gone = 0.0
		if float(plot.gone) > 8.0:
			_fail_crop(sim, "Ghost gourd collapses without a keeper.")
			return
		if float(plot.water) <= 0.0:
			_fail_crop(sim, "Ghost gourd dries out.")
			return
	plot.age = float(plot.age) + dt
	if float(plot.age) >= GROW:
		plot.state = "ripe"
		sim.say("%s is ready under the dome." % crop.replace("_", " ").capitalize())


static func _gather_named(sim, crop: String) -> String:
	var plot: Dictionary = sim.claim.plot
	plot.state = "empty"
	plot.age = 0.0
	plot.crop = "glasswheat"
	var cargo_id := crop
	var gathered := _data_crop(sim, crop)
	if not gathered.is_empty():
		cargo_id = str(gathered.get("yield", crop))
	sim.claim.crate.food = int(sim.claim.crate.get("food", 0)) + 1
	var stats := Fit.stats(sim.defs, sim.player)
	if Fit.cargo_used(sim.player) < int(stats.cargo_cap):
		sim._add_cargo(cargo_id, 1)
	sim.say("%s comes off the plot." % crop.replace("_", " ").capitalize())
	sim.sfx("extract")
	return ""


static func _step_stock(sim, dt: float) -> void:
	if not sim.claim.has("stock"):
		return
	var plot: Dictionary = sim.claim.get("plot", {})
	for row in sim.claim.stock:
		var animal: Dictionary = row
		if not bool(animal.get("alive", false)):
			continue
		animal.hunger = float(animal.get("hunger", 0.0)) + dt
		var kind := str(animal.get("kind", ""))
		if kind == "ash_hen":
			if float(animal.hunger) > 4.0 and int(sim.claim.get("crate", {}).get("food", 0)) > 0:
				sim.claim.crate.food = int(sim.claim.crate.food) - 1
				animal.hunger = 0.0
				sim.say("The ash hen takes grit from the crate.")
			if bool(sim.claim.get("ruptured", false)):
				animal.alive = false
				sim.say("The ash hen dies in the open dome.")
				sim.sfx("destroyed")
				continue
			if float(animal.hunger) >= 8.0:
				animal.alive = false
				sim.say("The ash hen starves for grit.")
				sim.sfx("destroyed")
				continue
			if float(animal.hunger) < 3.0:
				animal.yield = float(animal.get("yield", 0.0)) + dt
				if float(animal.yield) >= 10.0:
					animal.yield = 0.0
					sim.claim.crate["eggs"] = int(sim.claim.crate.get("eggs", 0)) + 1
					sim.say("The ash hen lays. An egg is in the crate.")
		elif kind == "rock_crab":
			var water := float(plot.get("water", 0.0))
			if water < 1.0:
				animal.alive = false
				sim.say("The rock crab dries. The plot had no brine.")
				sim.sfx("destroyed")
				continue
			if sim.claim.has("plot"):
				plot.water = maxf(0.0, water - dt * 0.35)
			if float(animal.hunger) >= 12.0:
				animal.alive = false
				sim.say("The rock crab starves.")
				sim.sfx("destroyed")
				continue
			if float(animal.hunger) < 4.0:
				animal.yield = float(animal.get("yield", 0.0)) + dt
				if float(animal.yield) >= 12.0:
					animal.yield = 0.0
					var stats := Fit.stats(sim.defs, sim.player)
					if Fit.cargo_used(sim.player) < int(stats.cargo_cap):
						sim._add_cargo("crab_meat", 1)
					sim.say("The rock crab yields meat.")
		else:
			_step_data_animal(sim, animal, dt)


static func _data_crop(sim, crop_id: String) -> Dictionary:
	var book = sim.defs.get("crops", {})
	if typeof(book) != TYPE_DICTIONARY:
		return {}
	var row = book.get(crop_id, {})
	if typeof(row) != TYPE_DICTIONARY:
		return {}
	return row


static func _data_animal(sim, kind: String) -> Dictionary:
	var book = sim.defs.get("animals", {})
	if typeof(book) != TYPE_DICTIONARY:
		return {}
	var row = book.get(kind, {})
	if typeof(row) != TYPE_DICTIONARY:
		return {}
	return row


static func _step_data_crop(sim, plot: Dictionary, spec: Dictionary, dt: float) -> void:
	var crop_name := str(spec.get("name", "crop"))
	if bool(sim.claim.get("ruptured", false)) and bool(spec.get("open_dome_kills", true)):
		_fail_crop(sim, "The open dome kills the %s." % crop_name)
		return
	if str(spec.get("dies_if", "")) == "motion":
		if sim.player.vel.length() > 8.0:
			plot.motion = float(plot.get("motion", 0.0)) + dt
		else:
			plot.motion = 0.0
		if float(plot.motion) > float(spec.get("die_after", 5.0)):
			_fail_crop(sim, "%s dies when the keel will not sit still." % crop_name)
			return
	plot.water = maxf(0.0, float(plot.get("water", 0.0)) - dt * 0.4)
	if float(plot.water) <= 0.0:
		_fail_crop(sim, "%s dries out." % crop_name)
		return
	plot.age = float(plot.age) + dt
	if float(plot.age) >= GROW:
		plot.state = "ripe"
		sim.say("%s is ready under the dome." % crop_name)


static func _step_data_animal(sim, animal: Dictionary, dt: float) -> void:
	var spec := _data_animal(sim, str(animal.get("kind", "")))
	if spec.is_empty():
		return
	var label := str(spec.get("name", "stock"))
	if bool(sim.claim.get("ruptured", false)) and bool(spec.get("open_dome_kills", true)):
		animal.alive = false
		sim.say("The %s dies in the open dome." % label)
		sim.sfx("destroyed")
		return
	if float(animal.hunger) > 4.0 and int(sim.claim.get("crate", {}).get("food", 0)) > 0:
		sim.claim.crate.food = int(sim.claim.crate.food) - 1
		animal.hunger = 0.0
		sim.say("The %s takes food from the crate." % label)
	if str(spec.get("dies_if", "")) == "hunger" and float(animal.hunger) >= float(spec.get("hunger_death", 8.0)):
		animal.alive = false
		sim.say("The %s starves." % label)
		sim.sfx("destroyed")
		return
	if float(animal.hunger) < 3.0:
		animal.yield = float(animal.get("yield", 0.0)) + dt
		if float(animal.yield) >= float(spec.get("yield_after", 10.0)):
			animal.yield = 0.0
			var cargo_id := str(spec.get("yield", "ribbon"))
			var stats := Fit.stats(sim.defs, sim.player)
			if Fit.cargo_used(sim.player) < int(stats.cargo_cap):
				sim._add_cargo(cargo_id, 1)
			sim.say("The %s yields %s." % [label, cargo_id.replace("_", " ")])


static func _stock_line(sim) -> String:
	var herd: Array = sim.claim.get("stock", [])
	if herd.is_empty():
		return ""
	var bits: Array = []
	for row in herd:
		var animal: Dictionary = row
		var state := "alive" if bool(animal.get("alive", false)) else "dead"
		bits.append("%s %s hunger %.0f" % [str(animal.get("name", "stock")), state, float(animal.get("hunger", 0.0))])
	return " ".join(bits)


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
