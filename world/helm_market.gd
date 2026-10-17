class_name HelmMarket
extends RefCounted

## Helion Exchange. Six offer slots, buy or sell, escrow, then Collect.
## A new offer matches the best resting opposite at that older price.
## The stall keeps posted sells so a solo pad still fills. Combat math stays off this path.

const LIST_CAP := 6
const PRICE_MIN := 1
const PRICE_MAX := 99
const COUNT_MAX := 99
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
	var ask := clip_price(price)
	var agent_id := str(unit.get("agent_id", ""))
	var found: Dictionary = _own_ask(sim, agent_id, item_id, ask)
	if not found.is_empty():
		var room := COUNT_MAX - int(found.get("count", 1))
		if room <= 0:
			return "That slip is full."
		need = mini(need, room)
		if not _take_cargo(unit, item_id, need):
			return "No %s in the hold." % sim.resource_name(item_id)
		var have := int(found.get("count", 1))
		found.count = have + need
		found.want = int(found.get("want", have)) + need
		_match_sell(sim, found)
		if need > 1:
			sim.say("Added %d %s to the %d GRT slip." % [need, sim.resource_name(item_id), ask])
		else:
			sim.say("Added %s to the %d GRT slip." % [sim.resource_name(item_id), ask])
		sim.sfx("install")
		return ""
	if _empty_slot(sim, agent_id) < 0:
		return "The stall holds %d of your slips. Pull one first." % LIST_CAP
	if not _take_cargo(unit, item_id, need):
		return "No %s in the hold." % sim.resource_name(item_id)
	var row := _blank(sim, item_id, need, ask)
	row.seller = agent_id
	row.seller_name = _name_of(unit)
	row.stall = false
	row.side = "sell"
	row.slot = _empty_slot(sim, agent_id)
	sim.listings.append(row)
	_match_sell(sim, row)
	if need > 1:
		sim.say("Sell offer: %d %s at %d GRT each." % [need, sim.resource_name(item_id), ask])
	else:
		sim.say("Sell offer: %s at %d GRT." % [sim.resource_name(item_id), ask])
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
	var side := str(row.get("side", "sell"))
	var leftover := int(row.get("count", 0)) + int(row.get("collect_item", 0))
	if side == "sell" or leftover > 0:
		var stats: Dictionary = Fit.stats(sim.defs, unit)
		if Fit.cargo_used(unit) + leftover > int(stats.cargo_cap):
			return "The hold is full."
	if leftover > 0:
		_give_cargo(unit, str(row.item), leftover)
	var coins_back := int(row.get("collect_coins", 0))
	if side == "buy":
		coins_back += unit_price(row) * maxi(0, int(row.get("count", 0)))
	if coins_back > 0:
		set_coins(sim, unit, coins(sim, unit) + coins_back)
	_drop(sim, listing_id)
	if side == "buy":
		sim.say("Aborted the buy offer.")
	else:
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
	var other: Dictionary = _own_ask(sim, str(unit.get("agent_id", "")), str(row.item), ask, str(row.get("id", "")))
	if not other.is_empty():
		var room := COUNT_MAX - int(other.get("count", 1))
		var move := mini(int(row.get("count", 1)), room)
		other.count = int(other.get("count", 1)) + move
		_drop(sim, str(row.get("id", "")))
		sim.say("Merged %s onto the %d GRT slip." % [sim.resource_name(str(row.item)), ask])
		sim.sfx("install")
		return ""
	if str(row.get("side", "sell")) == "buy":
		_match_buy(sim, row)
	else:
		_match_sell(sim, row)
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


static func buy_offer(sim, unit: Dictionary, item_id: String, price: int, count: int = 1) -> String:
	if sim == null or unit.is_empty():
		return "No keel is live."
	if not on_pad(sim, unit):
		return "The Helion market stands on the pad."
	if not listable(item_id):
		return "The stall will not take that crate."
	var want := clip_count(count)
	var ask := clip_price(price)
	var paid := ask * want
	if coins(sim, unit) < paid:
		return "GRT is short of %d for that offer." % paid
	var agent_id := str(unit.get("agent_id", ""))
	var slot := _empty_slot(sim, agent_id)
	if slot < 0:
		return "The stall holds %d of your slips. Pull one first." % LIST_CAP
	set_coins(sim, unit, coins(sim, unit) - paid)
	var row := _blank(sim, item_id, want, ask)
	row.seller = agent_id
	row.seller_name = _name_of(unit)
	row.stall = false
	row.side = "buy"
	row.slot = slot
	sim.listings.append(row)
	_match_buy(sim, row)
	if int(row.get("filled", 0)) > 0:
		sim.say("Buy offer: %s at %d GRT. %d filled." % [sim.resource_name(item_id), ask, int(row.filled)])
	else:
		sim.say("Buy offer: %d %s at %d GRT each." % [want, sim.resource_name(item_id), ask])
	sim.sfx("install")
	return ""


static func collect_offer(sim, unit: Dictionary, listing_id: String) -> String:
	if sim == null or unit.is_empty():
		return "No keel is live."
	if not on_pad(sim, unit):
		return "The Helion market stands on the pad."
	var row: Dictionary = find_listing(sim, listing_id)
	if row.is_empty():
		return "That slip is gone."
	if str(row.get("seller", "")) != str(unit.get("agent_id", "")):
		return "That slip is not yours."
	var crates := int(row.get("collect_item", 0))
	if crates > 0 and hold_room(sim, unit) < crates:
		return "The hold is full."
	if crates > 0:
		_give_cargo(unit, str(row.item), crates)
		row.collect_item = 0
	var pay := int(row.get("collect_coins", 0))
	if pay > 0:
		set_coins(sim, unit, coins(sim, unit) + pay)
		row.collect_coins = 0
	if int(row.get("count", 0)) <= 0:
		_drop(sim, listing_id)
	sim.say("Collected from the exchange.")
	sim.sfx("dock")
	return ""


static func collect_all(sim, unit: Dictionary) -> String:
	if sim == null or unit.is_empty():
		return "No keel is live."
	var ids: Array = []
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("seller", "")) != str(unit.get("agent_id", "")):
			continue
		if int(row.get("collect_item", 0)) <= 0 and int(row.get("collect_coins", 0)) <= 0:
			continue
		ids.append(str(row.get("id", "")))
	if ids.is_empty():
		return "Nothing to collect."
	var last := ""
	for raw_id in ids:
		last = collect_offer(sim, unit, str(raw_id))
		if last != "":
			return last
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
		if str(row.get("side", "sell")) == "buy":
			continue
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


static func best_ask(sim, item_id: String, skip_agent: String = "") -> int:
	var best := 0
	if sim == null:
		return 0
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("side", "sell")) == "buy":
			continue
		if str(row.get("item", "")) != item_id:
			continue
		if int(row.get("count", 0)) <= 0:
			continue
		if skip_agent != "" and str(row.get("seller", "")) == skip_agent:
			continue
		var ask := unit_price(row)
		if best == 0 or ask < best:
			best = ask
	return best


static func depth(sim, item_id: String) -> int:
	var n := 0
	if sim == null:
		return 0
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("side", "sell")) == "buy":
			continue
		if str(row.get("item", "")) == item_id:
			n += maxi(0, int(row.get("count", 0)))
	return n


static func default_ask(sim, item_id: String, skip_agent: String = "") -> int:
	var last := last_tick(sim, item_id)
	if last > 0:
		return last
	var best := best_ask(sim, item_id, skip_agent)
	if best > 0:
		return best
	return ask_price(item_id)


static func quote_line(sim, item_id: String, skip_agent: String = "") -> String:
	var bits: PackedStringArray = PackedStringArray()
	var best := best_ask(sim, item_id, skip_agent)
	var last := last_tick(sim, item_id)
	var n := depth(sim, item_id)
	if best > 0:
		bits.append("best %d" % best)
	if last > 0:
		bits.append("last %d" % last)
	if n > 0:
		bits.append("×%d" % n)
	return " · ".join(bits)


static func depth_line(sim) -> String:
	if sim == null or sim.listings.is_empty():
		return "LIVE  —"
	var seen: Dictionary = {}
	var ids: Array = []
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("side", "sell")) == "buy":
			continue
		var item_id := str(row.get("item", ""))
		if item_id == "" or int(row.get("count", 0)) <= 0:
			continue
		var have := maxi(1, int(row.get("count", 1)))
		var ask := unit_price(row)
		if not seen.has(item_id):
			ids.append(item_id)
			seen[item_id] = {"ask": ask, "n": have}
		else:
			var slot: Dictionary = seen[item_id]
			if ask < int(slot.ask):
				slot.ask = ask
			slot.n = int(slot.n) + have
			seen[item_id] = slot
	ids.sort()
	var bits: PackedStringArray = PackedStringArray()
	for raw_id in ids:
		var item_id := str(raw_id)
		var slot: Dictionary = seen[item_id]
		bits.append("%s %d×%d" % [_short(sim, item_id), int(slot.ask), int(slot.n)])
	return "LIVE  " + " · ".join(bits)


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
		return "GRT 0 · hold 0/0 · slots 0/%d" % LIST_CAP
	var stats: Dictionary = Fit.stats(sim.defs, unit)
	return "GRT %d · hold %d/%d · slots %d/%d" % [
		coins(sim, unit),
		Fit.cargo_used(unit),
		int(stats.cargo_cap),
		_owned_count(sim, str(unit.get("agent_id", ""))),
		LIST_CAP,
	]


static func hold_room(sim, unit: Dictionary) -> int:
	if sim == null or unit.is_empty():
		return 0
	var stats: Dictionary = Fit.stats(sim.defs, unit)
	return maxi(0, int(stats.cargo_cap) - Fit.cargo_used(unit))


static func buy_block(sim, unit: Dictionary, row: Dictionary, take: int = 0) -> String:
	if sim == null or unit.is_empty() or row.is_empty():
		return "No keel"
	if not on_pad(sim, unit):
		return "On pad"
	if str(row.get("seller", "")) == str(unit.get("agent_id", "")):
		return "Yours"
	var have := maxi(1, int(row.get("count", 1)))
	var want := have if int(take) <= 0 else mini(have, maxi(1, int(take)))
	var paid := unit_price(row) * want
	if coins(sim, unit) < paid:
		return "Need %d" % paid
	if hold_room(sim, unit) < want:
		return "Hold full"
	return ""


static func list_block(sim, unit: Dictionary, item_id: String, price: int = 0, count: int = 1) -> String:
	if sim == null or unit.is_empty():
		return "No keel"
	if not on_pad(sim, unit):
		return "On pad"
	if not listable(item_id):
		return "Won't list"
	var held := int(unit.cargo.get(item_id, 0))
	if held <= 0:
		return "None"
	var ask := clip_price(price) if int(price) > 0 else ask_price(item_id)
	var found: Dictionary = _own_ask(sim, str(unit.get("agent_id", "")), item_id, ask)
	if found.is_empty() and _owned_count(sim, str(unit.get("agent_id", ""))) >= LIST_CAP:
		return "Slips full"
	if clip_count(count, held) > held:
		return "None"
	return ""


static func board_items(sim) -> Array:
	var ids: Array = []
	var seen: Dictionary = {}
	if sim == null:
		return ids
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("side", "sell")) == "buy":
			continue
		var item_id := str(row.get("item", ""))
		if item_id == "" or seen.has(item_id):
			continue
		seen[item_id] = true
		ids.append(item_id)
	ids.sort()
	return ids


static func short_name(sim, item_id: String) -> String:
	return _short(sim, item_id)


static func board_sig(sim) -> String:
	if sim == null:
		return ""
	var bits: PackedStringArray = PackedStringArray()
	for raw in sim.listings:
		var row: Dictionary = raw
		bits.append("%s:%s:%s:%d:%d:%d:%d:%s" % [
			str(row.get("id", "")),
			str(row.get("item", "")),
			str(row.get("side", "sell")),
			int(row.get("price", 0)),
			int(row.get("count", 0)),
			int(row.get("collect_item", 0)),
			int(row.get("collect_coins", 0)),
			str(row.get("seller", "")),
		])
	bits.append(tape_line(sim))
	return "|".join(bits)


static func _own_ask(sim, agent_id: String, item_id: String, price: int, skip_id: String = "") -> Dictionary:
	if sim == null:
		return {}
	var want := clip_price(price)
	for raw in sim.listings:
		var row: Dictionary = raw
		if bool(row.get("stall", false)):
			continue
		if str(row.get("side", "sell")) == "buy":
			continue
		if str(row.get("seller", "")) != agent_id:
			continue
		if str(row.get("item", "")) != item_id:
			continue
		if unit_price(row) != want:
			continue
		if skip_id != "" and str(row.get("id", "")) == skip_id:
			continue
		return row
	return {}


static func catalog() -> Array:
	var ids: Array = HelmHarvest.stock_ids().duplicate()
	ids.append("glasswheat")
	return ids


static func guide_price(sim, item_id: String, skip_agent: String = "") -> int:
	return default_ask(sim, item_id, skip_agent)


static func has_slot(sim, unit: Dictionary) -> bool:
	if sim == null or unit.is_empty():
		return false
	return _empty_slot(sim, str(unit.get("agent_id", ""))) >= 0


static func own_desk(sim, agent_id: String) -> Array:
	var slots: Array = []
	var used: Dictionary = {}
	if sim != null:
		for raw in sim.listings:
			var row: Dictionary = raw
			if bool(row.get("stall", false)):
				continue
			if str(row.get("seller", "")) != agent_id:
				continue
			if _slot_done(row):
				continue
			var at := int(row.get("slot", -1))
			if at < 0:
				at = _first_free(used)
				row.slot = at
			used[at] = row
	for i in LIST_CAP:
		if used.has(i):
			slots.append(used[i])
		else:
			slots.append({})
	return slots


static func offer_left(row: Dictionary) -> int:
	return maxi(0, int(row.get("count", 0)))


static func offer_want(row: Dictionary) -> int:
	return maxi(1, int(row.get("want", row.get("count", 1))))


static func offer_filled(row: Dictionary) -> int:
	var filled := int(row.get("filled", 0))
	if filled > 0:
		return filled
	return maxi(0, offer_want(row) - offer_left(row))


static func can_collect(row: Dictionary) -> bool:
	return int(row.get("collect_item", 0)) > 0 or int(row.get("collect_coins", 0)) > 0


static func _owned_count(sim, agent_id: String) -> int:
	var n := 0
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("seller", "")) != agent_id:
			continue
		if bool(row.get("stall", false)):
			continue
		if _slot_done(row):
			continue
		n += 1
	return n


static func _slot_done(row: Dictionary) -> bool:
	if int(row.get("count", 0)) > 0:
		return false
	if int(row.get("collect_item", 0)) > 0:
		return false
	if int(row.get("collect_coins", 0)) > 0:
		return false
	return true


static func _empty_slot(sim, agent_id: String) -> int:
	var used: Dictionary = {}
	if sim != null:
		for raw in sim.listings:
			var row: Dictionary = raw
			if bool(row.get("stall", false)):
				continue
			if str(row.get("seller", "")) != agent_id:
				continue
			if _slot_done(row):
				continue
			used[int(row.get("slot", 0))] = true
	return _first_free(used)


static func _first_free(used: Dictionary) -> int:
	for i in LIST_CAP:
		if not used.has(i):
			return i
	return -1


static func _age(row: Dictionary) -> int:
	var id := str(row.get("id", "l0"))
	if id.begins_with("l") and id.length() > 1:
		return int(id.substr(1))
	return int(row.get("seq", 0))


static func _match_buy(sim, buy: Dictionary) -> void:
	if sim == null or buy.is_empty():
		return
	var item_id := str(buy.get("item", ""))
	var buyer := str(buy.get("seller", ""))
	var sells: Array = []
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("side", "sell")) == "buy":
			continue
		if str(row.get("item", "")) != item_id:
			continue
		if str(row.get("seller", "")) == buyer:
			continue
		if int(row.get("count", 0)) <= 0:
			continue
		if unit_price(row) > unit_price(buy):
			continue
		sells.append(row)
	sells.sort_custom(_by_ask_age)
	for raw in sells:
		if int(buy.get("count", 0)) <= 0:
			break
		var sell: Dictionary = raw
		_cross(sim, buy, sell)


static func _match_sell(sim, sell: Dictionary) -> void:
	if sim == null or sell.is_empty():
		return
	var item_id := str(sell.get("item", ""))
	var owner := str(sell.get("seller", ""))
	var buys: Array = []
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("side", "sell")) != "buy":
			continue
		if str(row.get("item", "")) != item_id:
			continue
		if str(row.get("seller", "")) == owner:
			continue
		if int(row.get("count", 0)) <= 0:
			continue
		if unit_price(row) < unit_price(sell):
			continue
		buys.append(row)
	buys.sort_custom(_by_bid)
	for raw in buys:
		if int(sell.get("count", 0)) <= 0:
			break
		var buy: Dictionary = raw
		_cross(sim, buy, sell)


static func _cross(sim, buy: Dictionary, sell: Dictionary) -> void:
	var qty := mini(int(buy.get("count", 0)), int(sell.get("count", 0)))
	if qty <= 0:
		return
	var bid := unit_price(buy)
	var ask := unit_price(sell)
	var trade := ask
	if _age(buy) < _age(sell):
		trade = bid
	buy.count = int(buy.get("count", 0)) - qty
	sell.count = int(sell.get("count", 0)) - qty
	buy.filled = int(buy.get("filled", 0)) + qty
	sell.filled = int(sell.get("filled", 0)) + qty
	buy.collect_item = int(buy.get("collect_item", 0)) + qty
	if bid > trade:
		buy.collect_coins = int(buy.get("collect_coins", 0)) + (bid - trade) * qty
	if not bool(sell.get("stall", false)):
		sell.collect_coins = int(sell.get("collect_coins", 0)) + trade * qty
	var item_id := str(sell.get("item", ""))
	note_sale(sim, item_id, trade, qty)
	if int(sell.get("count", 0)) <= 0 and bool(sell.get("stall", false)):
		_drop(sim, str(sell.get("id", "")))
		_post_stall(sim, item_id, ask)


static func _by_ask_age(a, b) -> bool:
	var left: Dictionary = a
	var right: Dictionary = b
	var lp := int(left.get("price", 0))
	var rp := int(right.get("price", 0))
	if lp != rp:
		return lp < rp
	return _age(left) < _age(right)


static func _by_bid(a, b) -> bool:
	var left: Dictionary = a
	var right: Dictionary = b
	var lp := int(left.get("price", 0))
	var rp := int(right.get("price", 0))
	if lp != rp:
		return lp > rp
	return _age(left) < _age(right)


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
		"side": "sell",
		"want": count,
		"filled": 0,
		"slot": -1,
		"collect_item": 0,
		"collect_coins": 0,
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
