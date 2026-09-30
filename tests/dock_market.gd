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
