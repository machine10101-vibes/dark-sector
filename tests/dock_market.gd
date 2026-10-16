extends SceneTree

var defs: Dictionary = {}
var fails := 0


func _init() -> void:
	var helion: Dictionary = Serde.load_json("res://data/system.json")
	var soil: Dictionary = Serde.load_json("res://data/first_soil.json")
	defs = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": helion,
		"systems": {
			str(helion.id): helion,
			str(soil.id): soil,
		},
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
	}
	_trade()
	_ore()
	_board()
	_tag()
	if fails == 0:
		print("DOCK MARKET PASS")
	else:
		print("DOCK MARKET FAIL %d" % fails)
	quit(fails)


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func make() -> SectorSim:
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.hold_npc = true
	return sim


func _leave(sim) -> void:
	sim.player.moored = false
	sim.player.pos = sim.beacon_pos + Vector2(900.0, 0.0)


func _trade() -> void:
	var sim := make()
	var posted := int(sim.market.glasswheat)
	check(DockBoard.at_pad(sim), "a fresh needle is on the pad")
	check(DockBoard.purse(sim) == 0, "a fresh purse is empty")
	check(DockBoard.holding(sim) == 0, "the hold starts without glasswheat")
	var refused := DockBoard.buy_good(sim)
	check(refused != "", "an empty purse refuses the buy")
	check(DockBoard.purse(sim) == 0, "a refused buy does not charge")
	check(DockBoard.holding(sim) == 0, "a refused buy does not load the hold")
	_leave(sim)
	check(DockBoard.at_pad(sim) == false, "leaving the bubble stands off the pad")
	sim.quest_flags.purse = 80
	var off := DockBoard.buy_good(sim)
	check("pad" in off, "the market stands on the pad")
	check(DockBoard.purse(sim) == 80, "an off-pad buy does not charge")
	check(DockBoard.sell_good(sim) != "", "an off-pad sell does not pay")
	check(DockBoard.purse(sim) == 80, "an off-pad sell leaves the purse")
	sim.player.moored = true
	sim.player.pos = sim.beacon_pos
	check(DockBoard.at_pad(sim), "moored is back on the pad")
	var stats: Dictionary = Fit.stats(sim.defs, sim.player)
	var cap := int(stats.cargo_cap)
	sim.player.cargo["claim_core"] = cap
	check(DockBoard.buy_good(sim) == "The hold is full.", "a full hold refuses glasswheat")
	check(DockBoard.purse(sim) == 80, "a full hold does not charge")
	sim.player.cargo["claim_core"] = 1
	check(DockBoard.buy_good(sim) == "", "the pad sells one glasswheat")
	check(DockBoard.purse(sim) == 80 - DockBoard.BUY_PRICE, "buy charges the purse")
	check(DockBoard.holding(sim) == 1, "buy loads one glasswheat")
	check(DockBoard.sell_good(sim) == "", "the pad buys the glasswheat back")
	check(DockBoard.holding(sim) == 0, "sell empties the glasswheat")
	check(DockBoard.purse(sim) == 80 - DockBoard.BUY_PRICE + DockBoard.SELL_PRICE, "sell pays the purse")
	check(DockBoard.sell_good(sim) == "No glasswheat in the hold.", "an empty hold does not sell")
	check(DockBoard.purse(sim) == 76, "a refused sell does not pay")
	check(int(sim.market.glasswheat) == posted, "trade does not move the posted price")
	var copy := SectorSim.new(defs)
	copy.from_dict(sim.to_dict())
	check(DockBoard.purse(copy) == 76, "a save keeps the purse")
	check(int(copy.market.glasswheat) == posted, "a save keeps the posted price")


func _ore() -> void:
	var sim := make()
	check(DockBoard.at_pad(sim), "ore trade stands on the pad")
	sim.player.cargo["nickel_cinder"] = 1
	sim.player.cargo["raw_mass"] = 1
	var purse := DockBoard.purse(sim)
	check(DockBoard.sell_stock(sim, "nickel_cinder") == "", "the pad buys nickel cinder")
	check(int(sim.player.cargo.get("nickel_cinder", 0)) == 0, "sell spends the nickel")
	check(DockBoard.purse(sim) == purse + HelmHarvest.stock_price("nickel_cinder"), "nickel pays GRT")
	purse = DockBoard.purse(sim)
	check(DockBoard.sell_stock(sim, "raw_mass") == "", "the pad buys raw mass")
	check(DockBoard.purse(sim) == purse + HelmHarvest.stock_price("raw_mass"), "raw mass pays GRT")
	_leave(sim)
	sim.player.cargo["copper_slag"] = 1
	check(DockBoard.sell_stock(sim, "copper_slag") != "", "an off-pad ore sell refuses")
	check(int(sim.player.cargo.copper_slag) == 1, "an off-pad ore sell leaves the slag")


func _board() -> void:
	var sim := make()
	check(sim.listings.size() >= 3, "the stall posts crates")
	var stall: Dictionary = {}
	for raw in sim.listings:
		var row: Dictionary = raw
		if bool(row.get("stall", false)) and str(row.get("item", "")) == "ice_spall":
			stall = row
			break
	check(not stall.is_empty(), "the stall lists ice")
	sim.quest_flags.purse = 20
	var ice0 := int(sim.player.cargo.get("ice_spall", 0))
	check(HelmMarket.buy_listing(sim, sim.player, str(stall.id)) == "", "the pad sells a stall slip")
	check(int(sim.player.cargo.get("ice_spall", 0)) == ice0 + 1, "a stall buy loads the hold")
	check(DockBoard.purse(sim) == 20 - int(stall.price), "a stall buy spends GRT")
	var ice_left := 0
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("item", "")) == "ice_spall" and bool(row.get("stall", false)):
			ice_left += 1
	check(ice_left >= 1, "the stall restocks ice")
	sim.player.cargo["nickel_cinder"] = 2
	var held := int(sim.player.cargo.nickel_cinder)
	check(HelmMarket.list_item(sim, sim.player, "nickel_cinder", 9) == "", "the keel lists nickel")
	check(int(sim.player.cargo.get("nickel_cinder", 0)) == held - 1, "a list takes the crate")
	var slip: Dictionary = {}
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("seller", "")) == str(sim.player.agent_id) and str(row.get("item", "")) == "nickel_cinder":
			slip = row
			break
	check(not slip.is_empty() and int(slip.price) == 9, "the nickel slip is on the board")
	check(HelmMarket.buy_listing(sim, sim.player, str(slip.id)) != "", "the seller cannot buy their own slip")
	check(HelmMarket.list_item(sim, sim.player, "claim_core", 8) != "", "a claim core will not list")
	_leave(sim)
	check(HelmMarket.list_item(sim, sim.player, "nickel_cinder", 9) != "", "an off-pad list refuses")
	sim.player.moored = true
	sim.player.pos = sim.beacon_pos
	check(HelmMarket.pull_listing(sim, sim.player, str(slip.id)) == "", "the seller can pull the slip")
	check(int(sim.player.cargo.get("nickel_cinder", 0)) == held, "a pull returns the crate")
	check(HelmMarket.list_item(sim, sim.player, "nickel_cinder", 11) == "", "the keel lists again")
	var posted: Dictionary = {}
	for raw in sim.listings:
		var row: Dictionary = raw
		if str(row.get("seller", "")) == str(sim.player.agent_id):
			posted = row
			break
	var guest: Dictionary = sim.admit("kestrel", "buyer-1")
	guest.moored = true
	guest.pos = sim.beacon_pos
	guest.purse = 40
	guest.cargo = {}
	var seller_purse := DockBoard.purse(sim)
	check(HelmMarket.buy_listing(sim, guest, str(posted.id)) == "", "another keel buys the slip")
	check(int(guest.cargo.get("nickel_cinder", 0)) == 1, "the buyer takes the nickel")
	check(int(guest.purse) == 40 - 11, "the buyer spends GRT")
	check(DockBoard.purse(sim) == seller_purse + 11, "the seller is paid GRT")
	var copy := SectorSim.new(defs)
	copy.from_dict(sim.to_dict())
	check(copy.listings.size() == sim.listings.size(), "a save keeps the stall")


func _tag() -> void:
	var sim := make()
	check(DockBoard.tag_of(sim) == "", "a fresh keel has no corp tag")
	check(DockBoard.clip_tag("Red-Keel!!") == "Red-Keel", "punctuation drops out of a tag")
	check(DockBoard.clip_tag("  abcdefghijklm  ") == "abcdefghijkl", "a tag clips to twelve")
	check(DockBoard.set_tag(sim, "Red-Keel!!") == "Red-Keel", "set tag returns the clipped tag")
	check(str(sim.player.corp_tag) == "Red-Keel", "the tag sticks on the keel")
	_leave(sim)
	check(DockBoard.set_tag(sim, "Blue Crew") == "Blue Crew", "a tag can be set off the pad")
	check(DockBoard.tag_of(sim) == "Blue Crew", "the off-pad tag sticks")
	var copy := SectorSim.new(defs)
	copy.from_dict(sim.to_dict())
	check(DockBoard.tag_of(copy) == "Blue Crew", "a save keeps the corp tag")
	check(DockBoard.set_tag(sim, "!!!") == "", "a blank tag clears")
	check(DockBoard.tag_of(sim) == "", "a cleared tag stays empty")
