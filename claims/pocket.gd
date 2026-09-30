class_name PocketRules
extends RefCounted


static func blank() -> Dictionary:
	return {
		"pocket_id": "hollow_latch",
		"owned": false,
		"frozen": false,
		"core": false,
		"agent_id": "",
		"surveyed": false,
		"integrity": 0.0,
		"dome": false,
		"crop": {"id": "", "growth": 0.0, "ready": false},
		"animal": {"id": "", "alive": false, "hunger": 0.0},
		"defense": {"online": false, "cooldown": 0.0},
	}


static func normalize(raw: Dictionary) -> Dictionary:
	var claim := blank()
	for key in ["pocket_id", "owned", "frozen", "core", "agent_id", "surveyed", "integrity", "dome"]:
		if raw.has(key):
			claim[key] = raw[key]
	_overlay(claim.crop, raw.get("crop", {}))
	_overlay(claim.animal, raw.get("animal", {}))
	_overlay(claim.defense, raw.get("defense", {}))
	claim.owned = bool(claim.owned)
	claim.frozen = bool(claim.frozen)
	claim.core = bool(claim.core)
	claim.surveyed = bool(claim.surveyed)
	claim.dome = bool(claim.dome)
	claim.integrity = float(claim.integrity)
	claim.crop.growth = float(claim.crop.growth)
	claim.crop.ready = bool(claim.crop.ready)
	claim.crop.id = str(claim.crop.id)
	claim.animal.alive = bool(claim.animal.alive)
	claim.animal.hunger = float(claim.animal.hunger)
	claim.animal.id = str(claim.animal.id)
	claim.defense.online = bool(claim.defense.online)
	claim.defense.cooldown = float(claim.defense.cooldown)
	claim.agent_id = str(claim.agent_id)
	claim.pocket_id = str(claim.pocket_id)
	return claim


static func status(sim) -> Dictionary:
	var claim: Dictionary = sim.claim
	var surveyed := bool(claim.get("surveyed", false))
	var owned := bool(claim.get("owned", false))
	var frozen := bool(claim.get("frozen", false))
	var core := bool(claim.get("core", false))
	var line := "Eligible homestead pocket. Print a Claim Core from cinder-ore, then plant it inside the pale ring."
	if surveyed and not owned:
		line = "A shuttle walked the Latch. The walk is a flag. The core is still a thing you print and plant."
	if core and not frozen:
		line = "The stake is live. The dome, the kale, the hen, and the turret are the homestead. The keel is still the ship."
	if frozen:
		line = "The core is cracked. The dome is dark and the hen is paused. The ship was not deleted. Print another core and plant it to wake the same stake."
	if not _rules(sim).is_empty() and not in_pocket(sim) and not owned:
		line += " You are not in the Latch."
	return {
		"name": "Hollow Latch",
		"eligible": true,
		"owned": owned,
		"frozen": frozen,
		"surveyed": surveyed,
		"core": core,
		"line": line,
	}


static func confirm_walk(sim) -> void:
	if bool(sim.claim.get("surveyed", false)):
		sim.say("Hollow Latch is already walked. The core is a separate planting.")
		return
	sim.claim.surveyed = true
	sim.quest_flags["hollow_latch_surveyed"] = true
	sim.say("Hollow Latch will hold a core. The garden is not planted. The keel is still the home.")
	sim.sfx("scan_done")


static func act(sim, action: String) -> String:
	match action:
		"print_core":
			return print_core(sim)
		"plant":
			return plant(sim)
		"dome":
			return raise_dome(sim)
		"sow":
			return sow(sim)
		"harvest":
			return harvest(sim)
		"stock":
			return stock_animal(sim)
		"feed":
			return feed_animal(sim)
		"turret":
			return stake_turret(sim)
		_:
			return ""


static func availability(sim) -> Dictionary:
	var rules: Dictionary = _rules(sim)
	var claim: Dictionary = sim.claim
	var crop: Dictionary = claim.crop
	var animal: Dictionary = claim.animal
	var alive_core := bool(claim.core) and not bool(claim.frozen)
	return {
		"print_core": int(sim.player.cargo.get(str(rules.core.cargo_id), 0)) < 1 and _can_pay(sim, rules.core.cost),
		"plant": in_pocket(sim) and int(sim.player.cargo.get(str(rules.core.cargo_id), 0)) >= 1 and not alive_core,
		"dome": alive_core and not bool(claim.dome) and _can_pay(sim, rules.dome.cost),
		"sow": alive_core and bool(claim.dome) and str(crop.id) == "",
		"harvest": bool(crop.ready) and alive_core,
		"stock": alive_core and bool(claim.dome) and not bool(animal.alive) and _can_pay(sim, rules.animal.cost),
		"feed": bool(animal.alive) and not bool(claim.frozen) and int(sim.player.cargo.get(str(rules.animal.feed_id), 0)) >= 1,
		"turret": alive_core and not bool(claim.defense.online) and _can_pay(sim, rules.defense.cost),
	}


static func print_core(sim) -> String:
	var rules: Dictionary = _rules(sim)
	var cargo_id := str(rules.core.cargo_id)
	if int(sim.player.cargo.get(cargo_id, 0)) >= 1:
		return _said(sim, "A Claim Core is already in the hold.")
	if not _pay(sim, rules.core.cost):
		return _said(sim, "A core wants %s." % _cost_line(sim, rules.core.cost))
	sim._add_cargo(cargo_id, 1)
	sim.sfx("install")
	return _said(sim, "Claim Core printed. Plant it inside Hollow Latch. The keel does not become the house.")


static func plant(sim) -> String:
	var rules: Dictionary = _rules(sim)
	var claim: Dictionary = sim.claim
	if bool(claim.core) and not bool(claim.frozen):
		return _said(sim, "The Latch already has a live core.")
	if not in_pocket(sim):
		return _said(sim, "Hollow Latch is the pocket. The core will not bite anywhere else.")
	var cargo_id := str(rules.core.cargo_id)
	if int(sim.player.cargo.get(cargo_id, 0)) < 1:
		return _said(sim, "No Claim Core in the hold.")
	_take(sim, cargo_id, 1)
	var waking := bool(claim.frozen) or bool(claim.owned)
	claim.core = true
	claim.owned = true
	claim.frozen = false
	claim.agent_id = str(sim.player.agent_id)
	claim.integrity = float(rules.integrity_max)
	sim.sfx("install")
	if waking:
		return _said(sim, "Core replanted. The same dome wakes. The ship was never the thing that froze.")
	return _said(sim, "Claim Core planted at Hollow Latch. This pocket is yours until the stake cracks.")


static func raise_dome(sim) -> String:
	var rules: Dictionary = _rules(sim)
	var claim: Dictionary = sim.claim
	if not _live(claim):
		return _said(sim, "The dome needs a live core.")
	if bool(claim.dome):
		return _said(sim, "The ash dome is already up.")
	if not in_pocket(sim):
		return _said(sim, "Raise the dome from inside the Latch.")
	if not _pay(sim, rules.dome.cost):
		return _said(sim, "The ash dome wants %s." % _cost_line(sim, rules.dome.cost))
	claim.dome = true
	sim.sfx("install")
	return _said(sim, "Ash dome sealed. Climate in the Latch is cinder-heat.")


static func sow(sim) -> String:
	var rules: Dictionary = _rules(sim)
	var claim: Dictionary = sim.claim
	if not _live(claim) or not bool(claim.dome):
		return _said(sim, "Ember kale needs the dome and a live core.")
	if str(claim.crop.id) != "":
		return _said(sim, "The dome already has a sowing.")
	if str(rules.crop.climate) != str(rules.climate):
		return _said(sim, "This pocket's climate will not take that seed.")
	claim.crop = {"id": str(rules.crop.id), "growth": 0.0, "ready": false}
	sim.sfx("scan_done")
	return _said(sim, "Ember kale sown. It wants the cinder-heat and a little time.")


static func harvest(sim) -> String:
	var rules: Dictionary = _rules(sim)
	var claim: Dictionary = sim.claim
	if not bool(claim.crop.ready) or not _live(claim):
		return _said(sim, "The kale is not ready.")
	var stats = Fit.stats(sim.defs, sim.player)
	if Fit.cargo_used(sim.player) >= int(stats.cargo_cap):
		return _said(sim, "The hold is full. The kale stays in the dome.")
	var yield_id := str(rules.crop.yield_id)
	sim._add_cargo(yield_id, 1)
	claim.crop.growth = 0.0
	claim.crop.ready = false
	sim.sfx("extract")
	return _said(sim, "%s aboard. The same sowing starts another season." % rules.crop.yield_name)


static func stock_animal(sim) -> String:
	var rules: Dictionary = _rules(sim)
	var claim: Dictionary = sim.claim
	if not _live(claim) or not bool(claim.dome):
		return _said(sim, "The hen needs the dome and a live core.")
	if bool(claim.animal.alive):
		return _said(sim, "An ash hen is already in the pen.")
	if not _pay(sim, rules.animal.cost):
		return _said(sim, "Stocking a hen wants %s." % _cost_line(sim, rules.animal.cost))
	claim.animal = {"id": str(rules.animal.id), "alive": true, "hunger": 0.0}
	sim.sfx("install")
	return _said(sim, "Ash hen in the pen. She eats ember kale. Hunger will kill her. A cracked core only pauses her.")


static func feed_animal(sim) -> String:
	var rules: Dictionary = _rules(sim)
	var animal: Dictionary = sim.claim.animal
	if not bool(animal.alive):
		return _said(sim, "The pen is empty.")
	if bool(sim.claim.frozen):
		return _said(sim, "The homestead is frozen. She is paused, not hungry.")
	var feed_id := str(rules.animal.feed_id)
	if int(sim.player.cargo.get(feed_id, 0)) < 1:
		return _said(sim, "She wants ember kale, and the hold has none.")
	_take(sim, feed_id, 1)
	animal.hunger = 0.0
	sim.sfx("extract")
	return _said(sim, "The ash hen ate. Hunger is back to nothing.")


static func stake_turret(sim) -> String:
	var rules: Dictionary = _rules(sim)
	var claim: Dictionary = sim.claim
	if not _live(claim):
		return _said(sim, "The turret stakes into a live core.")
	if bool(claim.defense.online):
		return _said(sim, "The stake turret is already up.")
	if not _pay(sim, rules.defense.cost):
		return _said(sim, "The turret wants %s." % _cost_line(sim, rules.defense.cost))
	claim.defense.online = true
	claim.defense.cooldown = 0.0
	sim.sfx("install")
	return _said(sim, "Stake turret up. It shoots Red Keel inside the Latch. It does not save a core that a skiff sits on.")


static func tick(sim, dt: float) -> void:
	if not sim.defs.has("claim"):
		return
	var rules: Dictionary = _rules(sim)
	var claim: Dictionary = sim.claim
	if not bool(claim.core) or bool(claim.frozen):
		return
	_grow(sim, rules, dt)
	_hunger(sim, rules, dt)
	_defend(sim, rules, dt)
	_crack(sim, rules, dt)


static func in_pocket(sim) -> bool:
	return sim.zone_at(sim.player.pos) == "pocket"


static func describe(sim) -> String:
	var rules: Dictionary = _rules(sim)
	var claim: Dictionary = sim.claim
	var info := status(sim)
	var bits: Array = []
	bits.append(str(info.name))
	bits.append(str(rules.climate_line))
	bits.append("Inside the Latch: %s." % ("yes" if in_pocket(sim) else "no"))
	if bool(claim.core) and not bool(claim.frozen):
		bits.append("Core live. Integrity %.0f / %.0f. Agent %s." % [float(claim.integrity), float(rules.integrity_max), claim.agent_id])
	elif bool(claim.frozen):
		bits.append("Core cracked. Homestead frozen. Agent on the slate: %s." % claim.agent_id)
	else:
		bits.append("No core planted. Hold has %d Claim Core." % int(sim.player.cargo.get(str(rules.core.cargo_id), 0)))
	bits.append("Dome: %s." % ("up" if bool(claim.dome) else "down"))
	bits.append(_crop_line(sim, rules))
	bits.append(_animal_line(sim, rules))
	bits.append("Stake turret: %s." % ("online" if bool(claim.defense.online) else "down"))
	bits.append("")
	bits.append(str(info.line))
	bits.append("Print costs %s. Dome costs %s. Hen costs %s. Turret costs %s." % [
		_cost_line(sim, rules.core.cost),
		_cost_line(sim, rules.dome.cost),
		_cost_line(sim, rules.animal.cost),
		_cost_line(sim, rules.defense.cost),
	])
	return "\n".join(bits)


static func _grow(sim, rules: Dictionary, dt: float) -> void:
	var crop: Dictionary = sim.claim.crop
	if str(crop.id) == "" or bool(crop.ready) or not bool(sim.claim.dome):
		return
	if str(rules.crop.climate) != str(rules.climate):
		return
	crop.growth = float(crop.growth) + dt
	if float(crop.growth) >= float(rules.crop.grow_seconds):
		crop.growth = float(rules.crop.grow_seconds)
		crop.ready = true
		sim.say("Ember kale is ready under the ash dome.")
		sim.sfx("scan_done")


static func _hunger(sim, rules: Dictionary, dt: float) -> void:
	var animal: Dictionary = sim.claim.animal
	if not bool(animal.alive):
		return
	animal.hunger = float(animal.hunger) + dt
	if float(animal.hunger) < float(rules.animal.hunger_seconds):
		return
	animal.alive = false
	animal.hunger = float(rules.animal.hunger_seconds)
	sim.say("The ash hen died hungry. The pen is empty. The core is still yours.")
	sim.sfx("destroyed")


static func _defend(sim, rules: Dictionary, dt: float) -> void:
	var defense: Dictionary = sim.claim.defense
	if not bool(defense.online):
		return
	defense.cooldown = maxf(0.0, float(defense.cooldown) - dt)
	if float(defense.cooldown) > 0.0:
		return
	var gun: Dictionary = rules.defense
	var hostile = _nearest_raider(sim, sim.pocket_pos, float(gun.range))
	if hostile == null:
		return
	var aim: Vector2 = hostile.pos - sim.pocket_pos
	if aim.length() < 8.0:
		return
	var dir := aim.normalized()
	sim.projectiles.append({
		"pos": sim.pocket_pos + dir * 18.0,
		"vel": dir * float(gun.speed),
		"damage": float(gun.damage),
		"team": "captain",
		"ttl": float(gun.ttl),
		"agent_id": "agent:claim:%s" % sim.claim.pocket_id,
	})
	defense.cooldown = float(gun.cooldown)
	sim.sfx("gun")


static func _crack(sim, rules: Dictionary, dt: float) -> void:
	var claim: Dictionary = sim.claim
	var raider = _nearest_raider(sim, sim.pocket_pos, float(rules.crack_range))
	if raider == null:
		return
	var on_stake: bool = raider.pos.distance_to(sim.pocket_pos) <= 48.0
	if bool(claim.defense.online) and not on_stake:
		return
	var rate := float(rules.crack_dps)
	if bool(claim.defense.online):
		rate *= 0.45
	claim.integrity = float(claim.integrity) - rate * dt
	if float(claim.integrity) > 0.0:
		return
	claim.integrity = 0.0
	claim.core = false
	claim.frozen = true
	claim.owned = true
	sim.banner = "Hollow Latch: the core cracked. The homestead is frozen. The keel is still yours."
	sim.banner_t = 0.0
	sim.say("Claim Core cracked. Dome dark, hen paused, ship untouched. Plant another core to wake the same stake.")
	sim.sfx("destroyed")


static func _nearest_raider(sim, pos: Vector2, radius: float):
	var best = null
	var best_dist := radius
	for actor in sim.actors:
		if not bool(actor.alive):
			continue
		if str(actor.team) != "red_keel":
			continue
		var dist: float = pos.distance_to(actor.pos)
		if dist <= best_dist:
			best_dist = dist
			best = actor
	return best


static func _crop_line(sim, rules: Dictionary) -> String:
	var crop: Dictionary = sim.claim.crop
	if str(crop.id) == "":
		return "Ember kale: not sown."
	if bool(sim.claim.frozen):
		return "Ember kale: paused with the freeze."
	if bool(crop.ready):
		return "Ember kale: ready to take aboard."
	return "Ember kale: %.0f / %.0fs." % [float(crop.growth), float(rules.crop.grow_seconds)]


static func _animal_line(sim, rules: Dictionary) -> String:
	var animal: Dictionary = sim.claim.animal
	if str(animal.id) == "":
		return "Ash hen: no stock in the pen."
	if bool(sim.claim.frozen) and bool(animal.alive):
		return "Ash hen: paused. She is not eating and she is not dead."
	if not bool(animal.alive):
		return "Ash hen: dead of hunger. Stock another if the dome is live."
	return "Ash hen: alive. Hunger %.0f / %.0fs. Feed her ember kale." % [float(animal.hunger), float(rules.animal.hunger_seconds)]


static func _live(claim: Dictionary) -> bool:
	return bool(claim.core) and not bool(claim.frozen)


static func _rules(sim) -> Dictionary:
	return sim.defs.claim


static func _can_pay(sim, cost: Dictionary) -> bool:
	for id in cost.keys():
		if int(sim.player.cargo.get(str(id), 0)) < int(cost[id]):
			return false
	return true


static func _pay(sim, cost: Dictionary) -> bool:
	if not _can_pay(sim, cost):
		return false
	for id in cost.keys():
		_take(sim, str(id), int(cost[id]))
	return true


static func _take(sim, id: String, count: int) -> void:
	var left := int(sim.player.cargo.get(id, 0)) - count
	if left <= 0:
		sim.player.cargo.erase(id)
	else:
		sim.player.cargo[id] = left


static func _cost_line(sim, cost: Dictionary) -> String:
	var bits: Array = []
	for id in cost.keys():
		bits.append("%d %s" % [int(cost[id]), sim.resource_name(str(id))])
	return ", ".join(bits)


static func _said(sim, text: String) -> String:
	sim.say(text)
	return text


static func _overlay(dest: Dictionary, raw) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key in dest.keys():
		if raw.has(key):
			dest[key] = raw[key]
