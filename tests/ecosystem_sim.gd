extends SceneTree

var defs: Dictionary = {}
var fails := 0

const FRESH := [
	"HC-V1-R2-S4",
	"HC-V1-R2-S5",
	"HC-V1-R2-S6",
	"HC-V1-R5-S3",
	"HC-V1-R5-S5",
]


func _init() -> void:
	defs = Catalog.boot()
	_chart()
	_lanes()
	_mobs()
	_water_lease()
	_print_yard()
	_cue()
	if fails == 0:
		print("ECOSYSTEM PASS")
	else:
		print("ECOSYSTEM FAIL %d" % fails)
	quit(fails)


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func make(class_id: String) -> SectorSim:
	var sim := SectorSim.new(defs)
	sim.new_game(class_id)
	sim.hold_npc = true
	sim.quest_flags.shakedown_beat = "done"
	return sim


func ride(sim: SectorSim, gate_id: String) -> String:
	for row in sim.gates:
		var gate: Dictionary = row
		if str(gate.get("id", "")) == gate_id:
			sim.player.pos = gate.pos
			return sim.try_lane()
	return "missing gate %s" % gate_id


func _chart() -> void:
	for system_id in FRESH:
		check(defs.systems.has(system_id), "%s is on the board" % system_id)
	var skipped := false
	for line in Catalog.errors:
		var text := str(line)
		for system_id in FRESH:
			if text.contains(system_id):
				skipped = true
				print("FAIL: catalog %s" % text)
	check(not skipped, "the new systems pass the catalog check")


func _lanes() -> void:
	var tow := make("anvil")
	tow._arrive("HC-V1-R2-S2", "")
	check(ride(tow, "towline_to_ice") == "", "Clock Lane leaves Towline")
	check(str(tow.defs.system.id) == "HC-V1-R2-S4", "Stamped Ice is flyable")
	check(ride(tow, "ice_from_towline") == "", "the clock lane returns to Towline")
	var copy := make("anvil")
	copy._arrive("HC-V1-R2-S2", "")
	check(ride(copy, "towline_to_copy") == "", "Print Lane leaves Towline")
	check(str(copy.defs.system.name) == "Second Copy", "Second Copy is flyable")
	var lease := make("vesper")
	lease._arrive("HC-V1-R2-S1", "")
	check(ride(lease, "lease_to_fine") == "", "Fine Print leaves Lease")
	check(Law.at(lease, lease.player.pos) == "red", "Fine Print law is red")
	var soil := make("anvil")
	soil._arrive("HC-V1-R5-S1", "")
	check(ride(soil, "soil_to_moth") == "", "Pollinator Road leaves First Soil")
	check(str(soil.defs.system.id) == "HC-V1-R5-S3", "Pollinator Road is flyable")
	check(ride(soil, "moth_from_soil") == "", "the moth lane returns")
	soil._arrive("HC-V1-R5-S1", "")
	check(ride(soil, "soil_to_silo") == "", "Silo Road leaves First Soil")
	check(str(soil.defs.system.name) == "Silo Dark", "Silo Dark is flyable")


func _actor_role(sim: SectorSim, role: String) -> Dictionary:
	for actor in sim.actors:
		if str(actor.ai.get("role", "")) == role and bool(actor.ai.get("role_authored", false)):
			return actor
	return {}


func _mobs() -> void:
	var ice := make("vesper")
	ice._arrive("HC-V1-R2-S4", "")
	var factor := {}
	var kite := {}
	for actor in ice.actors:
		if str(actor.name) == "Ice Factor":
			factor = actor
		if str(actor.ai.get("role", "")) == "kite":
			kite = actor
	check(not factor.is_empty() and str(factor.ai.get("action", "")) == "factor", "the Ice Factor reads the stamp")
	check(str(factor.ai.get("duty", "")).contains("Stamped Ice"), "the Ice Factor names the sky")
	check(not kite.is_empty() and bool(kite.ai.get("role_authored", false)), "a kite holds the clock ring")
	var road := make("anvil")
	road._arrive("HC-V1-R5-S3", "")
	var raider := _actor_role(road, "raider")
	var lighter := {}
	for actor in road.actors:
		if str(actor.name) == "Lighter Pilot":
			lighter = actor
	check(not raider.is_empty(), "a raider hunts the pollinator lighter")
	check(str(lighter.ai.get("action", "")) == "tow", "the Lighter Pilot holds a tow")
	road.player.pos = raider.home + Vector2(3000, 0)
	lighter.pos = raider.pos + Vector2(180, 0)
	var quarry: Dictionary = road._pirate_quarry(raider)
	check(str(quarry.get("agent_id", "")) == str(lighter.agent_id), "the raider takes the lighter before the captain")
	var school := make("kestrel")
	school._arrive("HC-V1-R2-S6", "")
	var ambush := _actor_role(school, "ambush")
	check(not ambush.is_empty(), "Fine Print posts an ambush")
	school.player.pos = ambush.home + Vector2(2000, 0)
	var held: Dictionary = school._pirate_quarry(ambush)
	check(held.is_empty(), "the ambush holds while the keel is outside the sight")
	school.player.pos = ambush.home + Vector2(180, 0)
	var sprung: Dictionary = school._pirate_quarry(ambush)
	check(not sprung.is_empty(), "the ambush closes inside the sight")
	var choir := make("vesper")
	choir._arrive("HC-V1-R2-S3", "")
	var jumper := _actor_role(choir, "claim_jumper")
	check(not jumper.is_empty(), "Ore Choir posts a claim jumper")
	check(jumper.home.distance_to(choir.pocket_pos) < 40.0, "the claim jumper sits the pocket")
	var brass := make("vesper")
	brass._arrive("HC-V1-R1-S2", "")
	var range_officer := false
	for actor in brass.actors:
		if str(actor.team) == "helion_compact" and str(actor.ai.get("action", "")) == "range":
			range_officer = true
	check(range_officer, "Brass Lantern's patrol is the gunnery range")


func _water_lease() -> void:
	var sim := make("anvil")
	sim._arrive("HC-V1-R2-S4", "")
	var opened := false
	for row in QuestLog.entries(sim.defs, sim):
		if str(row.get("id", "")) == "authored_water_lease" and str(row.get("state", "")) == "open":
			opened = true
	check(opened, "Water Lease opens on arrival at Stamped Ice")
	QuestBoard.pulse(sim, 0.2)
	check(int(sim.quest_flags.get("authored_water_lease_step", 0)) == 1, "Water Lease records the ice step")
	check(str(sim.quest_flags.get("authored_water_lease", "")) != "done", "ice in the sky is not yet a delivery")
	sim.player.cargo.ice_spall = 0
	sim._arrive("HC-V1-R2-S2", "")
	QuestBoard.pulse(sim, 0.2)
	check(str(sim.quest_flags.get("authored_water_lease", "")) != "done", "Towline without ice does not finish the lease")
	sim.player.cargo.ice_spall = 1
	QuestBoard.pulse(sim, 0.2)
	check(str(sim.quest_flags.get("authored_water_lease", "")) == "done", "ice at Towline finishes Water Lease")
	check(int(sim.quest_flags.get("charter_standing", 0)) > 0, "Water Lease writes charter standing")


func _print_yard() -> void:
	var sim := make("vesper")
	sim._arrive("HC-V1-R2-S5", "")
	var seen := false
	for row in QuestLog.entries(sim.defs, sim):
		if str(row.get("id", "")) == "authored_print_yard" and str(row.get("state", "")) == "open":
			seen = true
			check(str(row.get("giver", "")) == "Rimward Charter", "Second Copy names its giver")
			check(str(row.get("summary", "")).contains("Finish:"), "Second Copy states the finish")
	check(seen, "Second Copy is open in the log")
	var yard = sim.planet("print_yard")
	check(yard != null, "Print Yard is a body")
	if yard == null:
		return
	sim.player.pos = yard.pos + Vector2(float(yard.radius) + 400.0, 0.0)
	QuestBoard.pulse(sim, 0.2)
	check(str(sim.quest_flags.get("authored_print_yard", "")) != "done", "Second Copy stays open outside the shell")
	sim.player.pos = yard.pos
	QuestBoard.pulse(sim, 0.2)
	check(str(sim.quest_flags.get("authored_print_yard", "")) == "done", "closing on Print Yard finishes Second Copy")


func _cue() -> void:
	var hymn := make("vesper")
	hymn.quest_flags.did_cull = true
	hymn._arrive("HC-V1-R4-S4", "")
	check(QuestBoard.cue_line(hymn).contains("Ash Hymn"), "Ash Hymn still names itself")
	var ice := make("anvil")
	ice.quest_flags.authored_tug_yard = "done"
	ice._arrive("HC-V1-R2-S2", "")
	var line := QuestBoard.cue_line(ice)
	check(line.contains("Water Lease"), "from Towline the lease points at its lane")
