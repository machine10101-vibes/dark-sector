class_name HelmHarvest
extends RefCounted

## Close plasma cuts and probe harvest on a seam. Combat math stays off this
## path. The purse still holds the coins; the helm names them GRT.

const CUT_REACH := 96.0
const CUT_WORK := 1.55
const PROBE_WORK := 1.75
const CUT_LIFE := 0.36
const STOCK_PAY := {
	"nickel_cinder": 6,
	"ice_spall": 5,
	"copper_slag": 7,
	"hull_plate": 8,
	"raw_mass": 4,
	"salvage_parts": 9,
}


static func ready(sim, place) -> bool:
	if sim == null or place == null:
		return false
	if int(sim.deposits.get(str(place.id), 0)) <= 0:
		return false
	var kind := str(place.get("kind", ""))
	if kind == "seam" or kind == "belt" or kind == "gravel" or kind == "stream":
		return true
	return sim.dossier_complete(str(place.id))


static func nearest_seam(sim, from: Vector2, reach: float = 1.0e12):
	if sim == null:
		return null
	var best = null
	var best_dist := reach
	for raw in sim.nodes:
		var place: Dictionary = raw
		if int(sim.deposits.get(str(place.id), 0)) <= 0:
			continue
		var dist: float = from.distance_to(place.pos)
		if dist < best_dist:
			best_dist = dist
			best = place
	return best


static func mark(sim, node_id: String) -> void:
	if sim == null or sim.player.is_empty():
		return
	var id := str(node_id)
	if id == "" or sim.survey_node(id) == null:
		return
	sim.player.harvest_id = id


static func mark_at(sim, pos: Vector2, reach: float = 280.0) -> void:
	var place = seam_at(sim, pos, reach)
	if place != null:
		mark(sim, str(place.id))


static func marked(sim):
	if sim == null or sim.player.is_empty():
		return null
	var id := str(sim.player.get("harvest_id", ""))
	if id != "":
		var place = sim.survey_node(id)
		if place != null:
			return place
	return _from_order(sim)


static func _from_order(sim):
	var order = sim.player.get("order", {})
	if typeof(order) != TYPE_DICTIONARY:
		return null
	var tid := str(order.get("target", ""))
	if tid != "":
		var named = sim.survey_node(tid)
		if named != null:
			return named
	if order.has("x"):
		return seam_at(sim, Vector2(float(order.x), float(order.y)), 280.0)
	return null


static func seam_at(sim, pos: Vector2, reach: float = 280.0):
	if sim == null:
		return null
	var best = null
	var best_dist := reach
	for raw in sim.nodes:
		var place: Dictionary = raw
		var dist: float = pos.distance_to(place.pos)
		if dist < best_dist:
			best_dist = dist
			best = place
	return best


static func next_craft_target(sim):
	if sim == null:
		return null
	var best = null
	var best_dist := 1.0e12
	for raw in sim.nodes:
		var place: Dictionary = raw
		if not ready(sim, place):
			continue
		var dist: float = sim.player.pos.distance_to(place.pos)
		if dist < best_dist:
			best_dist = dist
			best = place
	return best


static func send_craft(sim, node_id: String = "") -> String:
	if sim == null:
		return "No keel is live."
	if node_id != "":
		mark(sim, node_id)
	var place = sim.survey_node(node_id) if node_id != "" else marked(sim)
	if place == null:
		place = next_craft_target(sim)
	if place == null:
		return "No seam is ready. Scan a node, or fly the plasma onto the rock."
	var drone = _first_live(sim, "harvest_drone")
	var probe = _first_live(sim, "survey_probe")
	if ready(sim, place):
		if drone != null:
			return CraftOrders.order(sim, str(drone.uid), "launch", str(place.id))
		if probe != null:
			return CraftOrders.order(sim, str(probe.uid), "cut", str(place.id))
		return "No probe on this keel. Close on the seam and cut it with the plasma."
	if probe != null:
		return CraftOrders.order(sim, str(probe.uid), "scan", str(place.id))
	if drone != null:
		return CraftOrders.order(sim, str(drone.uid), "launch", str(place.id))
	return "Scan %s before a cut, or fly the plasma onto the rock." % place.name


static func try_cut(sim, unit: Dictionary, node_id: String = "") -> String:
	if sim == null or unit.is_empty():
		return "No keel is live."
	if not sim.cut_job.is_empty():
		return "The plasma cutter is already on a seam."
	var place = sim.survey_node(node_id) if node_id != "" else null
	if place == null:
		var aim = marked(sim)
		if aim != null and unit.pos.distance_to(aim.pos) <= CUT_REACH:
			place = aim
	if place == null:
		place = nearest_seam(sim, unit.pos, CUT_REACH)
	if place == null:
		return "No rock is in plasma reach. Close on a seam."
	if int(sim.deposits.get(str(place.id), 0)) <= 0:
		return "%s has nothing left to cut." % place.name
	var stats: Dictionary = Fit.stats(sim.defs, sim.player)
	if Fit.cargo_used(sim.player) >= int(stats.cargo_cap):
		return "Hold is full. Sell the stock for GRT, then cut again."
	var gap: float = unit.pos.distance_to(place.pos)
	if gap > CUT_REACH:
		return "Plasma reach is short. Bring the keel onto %s." % place.name
	sim.cut_job = {
		"node_id": str(place.id),
		"work": 0.0,
		"need": CUT_WORK,
		"kind": "plasma",
	}
	sim.say("Plasma cutter on %s." % place.name)
	sim.sfx("plasma")
	note_cut(sim, unit.pos, place.pos, "plasma")
	return ""


static func step(sim, dt: float) -> void:
	if sim == null:
		return
	age_cuts(sim, dt)
	if sim.cut_job.is_empty():
		return
	var job: Dictionary = sim.cut_job
	var place = sim.survey_node(str(job.get("node_id", "")))
	if place == null:
		sim.cut_job = {}
		return
	var gap: float = sim.player.pos.distance_to(place.pos)
	if gap > CUT_REACH * 1.2 or int(sim.deposits.get(str(place.id), 0)) <= 0:
		sim.cut_job = {}
		sim.say("Plasma cutter lost the seam.")
		return
	job.work = float(job.get("work", 0.0)) + dt
	sim.cut_job = job
	note_cut(sim, sim.player.pos, place.pos, "plasma")
	if float(job.work) < float(job.get("need", CUT_WORK)):
		return
	sim.cut_job = {}
	var result := str(sim.try_extract(str(place.id)))
	if result == "full":
		sim.say("Hold is full. Sell the stock for GRT on the Helion pad.")
	elif result == "empty":
		sim.say("%s's seam is worked out." % place.name)
	elif result == "ok":
		note_cut(sim, sim.player.pos, place.pos, "plasma")


static func note_cut(sim, from: Vector2, to: Vector2, kind: String) -> void:
	if sim == null:
		return
	sim.cuts.append({
		"from": from,
		"to": to,
		"kind": kind,
		"age": 0.0,
	})
	while sim.cuts.size() > 8:
		sim.cuts.pop_front()


static func age_cuts(sim, dt: float) -> void:
	if sim == null:
		return
	var kept: Array = []
	for raw in sim.cuts:
		var row: Dictionary = raw
		row.age = float(row.get("age", 0.0)) + dt
		if float(row.age) < CUT_LIFE:
			kept.append(row)
	sim.cuts = kept


static func stock_price(id: String) -> int:
	if STOCK_PAY.has(id):
		return int(STOCK_PAY[id])
	return 0


static func stock_ids() -> Array:
	return ["nickel_cinder", "ice_spall", "copper_slag", "hull_plate", "raw_mass", "salvage_parts"]


static func _first_live(sim, def_id: String):
	var parked = null
	for item in sim.craft:
		if str(item.def_id) != def_id:
			continue
		if str(item.state) == "lost":
			continue
		if str(item.state) == "docked":
			if parked == null:
				parked = item
			continue
		return item
	return parked
