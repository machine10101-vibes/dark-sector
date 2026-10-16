class_name HelmMarket
extends RefCounted

## Player slips on the Helion pad. A crate leaves the hold when it is listed.
## Another keel on the pad buys it for GRT. The stall keeps a few posted crates
## so the board is never empty. Combat math stays off this path.

const LIST_CAP := 6
const PRICE_MIN := 1
const PRICE_MAX := 99
const TAPE_CAP := 8
const STALL := "stall"
const BLOCKED := ["claim_core", "dock_crate"]


static func listable(id: String) -> bool:
	if id == "" or BLOCKED.has(id):
		return false
	if HelmHarvest.stock_price(id) > 0:
		return true
	return id == "glasswheat"


static func ask_price(id: String) -> int:
	if id == "glasswheat":
		return DockBoard.SELL_PRICE
	var pay := HelmHarvest.stock_price(id)
	if pay > 0:
		return pay
	return 4


static func clip_price(raw) -> int:
	return clampi(int(raw), PRICE_MIN, PRICE_MAX)


static func clip_count(raw, cap: int = 99) -> int:
	var top := clampi(int(cap), 1, 99)
	return clampi(int(raw), 1, top)


static func unit_price(row: Dictionary) -> int:
	return clip_price(row.get("price", 0))


static func slip_cost(row: Dictionary, take: int = 0) -> int:
	var have := maxi(1, int(row.get("count", 1)))
	var want := have if int(take) <= 0 else mini(have, maxi(1, int(take)))
	return unit_price(row) * want


static func on_pad(sim, unit: Dictionary) -> bool:
	if sim == null or unit.is_empty():
		return false
	if str(sim.defs.system.id) != "HC-V1-R1-S1":
		return false
	if bool(unit.get("moored", false)):
		return true
	if sim.beacon_pos == Vector2.ZERO:
		return false
	return unit.pos.distance_to(sim.beacon_pos) <= DockBoard.PAD


static func seed_stall(sim) -> void:
	if sim == null:
		return
	if not sim.listings.is_empty():
		return
	_post_stall(sim, "ice_spall", 7)
	_post_stall(sim, "nickel_cinder", 8)
	_post_stall(sim, "glasswheat", 10)
	_post_stall(sim, "copper_slag", 9)


static func list_item(sim, unit: Dictionary, item_id: String, price: int, count: int = 1) -> String:
	if sim == null or unit.is_empty():
		return "No keel is live."
	if not on_pad(sim, unit):
		return "The Helion market stands on the pad."
	if not listable(item_id):
		return "The stall will not take that crate."
	var held := int(unit.cargo.get(item_id, 0))
	if held <= 0:
		return "No %s in the hold." % sim.resource_name(item_id)
	var need := clip_count(count, held)
	if _owned_count(sim, str(unit.get("agent_id", ""))) >= LIST_CAP:
		return "The stall holds %d of your slips. Pull one first." % LIST_CAP
	var ask := clip_price(price)
	if not _take_cargo(unit, item_id, need):
		return "No %s in the hold." % sim.resource_name(item_id)
	var row := _blank(sim, item_id, need, ask)
	row.seller = str(unit.get("agent_id", ""))
	row.seller_name = _name_of(unit)
	row.stall = false
	sim.listings.append(row)
	if need > 1:
		sim.say("Listed %d %s at %d GRT each." % [need, sim.resource_name(item_id), ask])
	else:
		sim.say("Listed %s for %d GRT." % [sim.resource_name(item_id), ask])
	sim.sfx("install")
	return ""


static func pull_listing(sim, unit: Dictionary, listing_id: String) -> String:
	if sim == null or unit.is_empty():
		return "No keel is live."
	if not on_pad(sim, unit):
		return "The Helion market stands on the pad."
	var row: Dictionary = find_listing(sim, listing_id)
	if row.is_empty():
		return "That slip is gone."
	if bool(row.get("stall", false)):
		return "The stall keeps its own crates."
	if str(row.get("seller", "")) != str(unit.get("agent_id", "")):
		return "That slip is not yours."
	var stats: Dictionary = Fit.stats(sim.defs, unit)
	if Fit.cargo_used(unit) + int(row.get("count", 1)) > int(stats.cargo_cap):
		return "The hold is full."
	_give_cargo(unit, str(row.item), int(row.get("count", 1)))
	_drop(sim, listing_id)
	sim.say("Pulled %s off the stall." % sim.resource_name(str(row.item)))
	sim.sfx("dock")
	return ""


static func reprice_listing(sim, unit: Dictionary, listing_id: String, price: int) -> String:
	if sim == null or unit.is_empty():
		return "No keel is live."
	if not on_pad(sim, unit):
		return "The Helion market stands on the pad."
	var row: Dictionary = find_listing(sim, listing_id)
	if row.is_empty():
		return "That slip is gone."
	if bool(row.get("stall", false)):
		return "The stall keeps its own crates."
	if str(row.get("seller", "")) != str(unit.get("agent_id", "")):
		return "That slip is not yours."
	var ask := clip_price(price)
	row.price = ask
	sim.say("Reposted %s at %d GRT each." % [sim.resource_name(str(row.item)), ask])
	sim.sfx("install")
	return ""


static func buy_listing(sim, unit: Dictionary, listing_id: String, take: int = 0) -> String:
	if sim == null or unit.is_empty():
		return "No keel is live."
	if not on_pad(sim, unit):
		return "The Helion market stands on the pad."
	var row: Dictionary = find_listing(sim, listing_id)
	if row.is_empty():
		return "That slip is gone."
	if str(row.get("seller", "")) == str(unit.get("agent_id", "")):
		return "That slip is yours. Pull it."
	var have := maxi(1, int(row.get("count", 1)))
	var want := have if take <= 0 else mini(have, maxi(1, take))
	var ask := unit_price(row)
	var paid := ask * want
	if coins(sim, unit) < paid:
		return "GRT is short of %d for that slip." % paid
	var stats: Dictionary = Fit.stats(sim.defs, unit)
	if Fit.cargo_used(unit) + want > int(stats.cargo_cap):
		return "The hold is full."
	set_coins(sim, unit, coins(sim, unit) - paid)
	_give_cargo(unit, str(row.item), want)
	var seller_id := str(row.get("seller", ""))
	if seller_id != "" and seller_id != STALL:
		var seller = sim.human_by_agent(seller_id)
		if seller != null:
			set_coins(sim, seller, coins(sim, seller) + paid)
	var item_id := str(row.item)
	var stall := bool(row.get("stall", false))
	if want < have:
		row.count = have - want
	else:
		_drop(sim, listing_id)
		if stall:
			_post_stall(sim, item_id, ask)
	note_sale(sim, item_id, ask, want)
	if want > 1:
		sim.say("Bought %d %s for %d GRT." % [want, sim.resource_name(item_id), paid])
	else:
		sim.say("Bought %s for %d GRT." % [sim.resource_name(item_id), paid])
	sim.sfx("dock")
	return ""


static func find_listing(sim, listing_id: String) -> Dictionary:
	if sim == null:
		return {}
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("id", "")) == listing_id:
			return row
	return {}


static func split_board(sim, agent_id: String) -> Dictionary:
	var stall: Array = []
	var pad: Array = []
	var mine: Array = []
	if sim == null:
		return {"stall": stall, "pad": pad, "mine": mine}
	for raw in sim.listings:
		var row: Dictionary = raw
		if bool(row.get("stall", false)):
			stall.append(row)
		elif str(row.get("seller", "")) == agent_id:
			mine.append(row)
		else:
			pad.append(row)
	stall.sort_custom(_by_ask)
	pad.sort_custom(_by_ask)
	mine.sort_custom(_by_ask)
	return {"stall": stall, "pad": pad, "mine": mine}


static func coins(sim, unit: Dictionary) -> int:
	if sim == null or unit.is_empty():
		return 0
	if str(unit.get("agent_id", "")) == str(sim.player.get("agent_id", "")):
		return DockBoard.purse(sim)
	return int(unit.get("purse", 0))


static func set_coins(sim, unit: Dictionary, amount: int) -> void:
	if sim == null or unit.is_empty():
		return
	var next := maxi(0, amount)
	if str(unit.get("agent_id", "")) == str(sim.player.get("agent_id", "")):
		sim.quest_flags.purse = next
	else:
		unit.purse = next


static func note_sale(sim, item_id: String, price: int, count: int) -> void:
	if sim == null:
		return
	var tick := {
		"item": item_id,
		"price": clip_price(price),
		"count": maxi(1, count),
	}
	var tape: Array = sim.market_tape
	tape.push_front(tick)
	while tape.size() > TAPE_CAP:
		tape.pop_back()
	sim.market_tape = tape


static func last_tick(sim, item_id: String) -> int:
	if sim == null:
		return 0
	for raw in sim.market_tape:
		var row: Dictionary = raw
		if str(row.get("item", "")) == item_id:
			return int(row.get("price", 0))
	return 0


static func tape_line(sim) -> String:
	if sim == null or sim.market_tape.is_empty():
		return "LAST  —"
	var bits: PackedStringArray = PackedStringArray()
	for raw in sim.market_tape:
		var row: Dictionary = raw
		bits.append("%s %d" % [_short(sim, str(row.get("item", ""))), int(row.get("price", 0))])
	return "LAST  " + " · ".join(bits)


static func desk_line(sim, unit: Dictionary) -> String:
	if sim == null or unit.is_empty():
		return "GRT 0 · hold 0/0 · slips 0/%d" % LIST_CAP
	var stats: Dictionary = Fit.stats(sim.defs, unit)
	return "GRT %d · hold %d/%d · slips %d/%d" % [
		coins(sim, unit),
		Fit.cargo_used(unit),
		int(stats.cargo_cap),
		_owned_count(sim, str(unit.get("agent_id", ""))),
		LIST_CAP,
	]


static func board_sig(sim) -> String:
	if sim == null:
		return ""
	var bits: PackedStringArray = PackedStringArray()
	for raw in sim.listings:
		var row: Dictionary = raw
		bits.append("%s:%s:%d:%d:%s" % [
			str(row.get("id", "")),
			str(row.get("item", "")),
			int(row.get("price", 0)),
			int(row.get("count", 0)),
			str(row.get("seller", "")),
		])
	bits.append(tape_line(sim))
	return "|".join(bits)


static func _owned_count(sim, agent_id: String) -> int:
	var n := 0
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("seller", "")) == agent_id and not bool(row.get("stall", false)):
			n += 1
	return n


static func _blank(sim, item_id: String, count: int, price: int) -> Dictionary:
	sim.listing_seq = int(sim.listing_seq) + 1
	return {
		"id": "l%d" % int(sim.listing_seq),
		"item": item_id,
		"count": count,
		"price": price,
		"seller": STALL,
		"seller_name": "Helion stall",
		"stall": true,
	}


static func _post_stall(sim, item_id: String, price: int) -> void:
	sim.listings.append(_blank(sim, item_id, 1, price))


static func _drop(sim, listing_id: String) -> void:
	var kept: Array = []
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("id", "")) != listing_id:
			kept.append(row)
	sim.listings = kept


static func _take_cargo(unit: Dictionary, id: String, count: int) -> bool:
	if int(unit.cargo.get(id, 0)) < count:
		return false
	unit.cargo[id] = int(unit.cargo[id]) - count
	if int(unit.cargo[id]) <= 0:
		unit.cargo.erase(id)
	return true


static func _give_cargo(unit: Dictionary, id: String, count: int) -> void:
	unit.cargo[id] = int(unit.cargo.get(id, 0)) + count


static func _name_of(unit: Dictionary) -> String:
	var tag := str(unit.get("corp_tag", "")).strip_edges()
	if tag != "":
		return tag
	return str(unit.get("name", "Keel"))


static func _short(sim, item_id: String) -> String:
	var name := str(sim.resource_name(item_id)).strip_edges().to_lower()
	var cut := name.find(" ")
	if cut > 0:
		return name.substr(0, cut)
	return name


static func _by_ask(a, b) -> bool:
	var left: Dictionary = a
	var right: Dictionary = b
	var lp := int(left.get("price", 0))
	var rp := int(right.get("price", 0))
	if lp != rp:
		return lp < rp
	return str(left.get("item", "")) < str(right.get("item", ""))
