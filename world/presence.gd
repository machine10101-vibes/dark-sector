extends RefCounted

## Band traffic is authored per system, plus the keels actually in the sim.


static func here(sim) -> int:
	var n := 0
	if bool(sim.player.get("alive", false)):
		n += 1
	for mate in sim.captains:
		if bool(mate.get("alive", false)):
			n += 1
	return n


static func band(sim) -> int:
	var sid := str(sim.defs.system.id)
	var base := 3 + int(absi(hash(sid)) % 6)
	var book = sim.defs.get("presence", {})
	if typeof(book) == TYPE_DICTIONARY and book.has(sid):
		var row = book[sid]
		if typeof(row) == TYPE_DICTIONARY:
			base = int(row.get("keels", base))
	var bucket := str(int(float(sim.time) / 40.0))
	var wobble := int(absi(hash(sid + bucket)) % 3)
	return base + wobble


static func line(sim) -> String:
	return "%d keel here · %d on the band" % [here(sim), band(sim)]
