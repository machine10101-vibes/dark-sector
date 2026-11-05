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
	_roles()
	_steps()
	_hooks()
	_cue()
	_guide()
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
	check(str(sim.quest_flags.get("authored_print_yard", "")) != "done", "arrival does not file Second Copy")
	var factor := _named(sim, "Print Factor")
	check(not factor.is_empty(), "Second Copy posts a Print Factor")
	check(QuestBoard.track(sim, "authored_print_yard") == "", "Track pins Second Copy on the factor")
	check(QuestBoard.cue_line(sim).contains("Print Factor"), "the guide marks the Print Factor before the meet")
	check(_body_open(sim, "authored_print_yard", "print_yard"), "Print Yard's shell does not file Second Copy")
	check(bool(sim.quest_flags.get("authored_print_yard_meet_factor", false)) == false, "standing on Print Yard does not meet the factor")
	sim.player.pos = factor.pos + Vector2(40.0, 0.0)
	QuestBoard.pulse(sim, 0.2)
	check(bool(sim.quest_flags.get("authored_print_yard_meet_factor", false)), "coming alongside the Print Factor records the copy")
	check(_said(sim, "Second Copy: Print Factor."), "the helm names the Print Factor")
	check(str(sim.quest_flags.get("authored_print_yard", "")) != "done", "the factor alone does not file Second Copy")
	check(QuestBoard.cue_line(sim).contains("Print Yard"), "after the factor the guide marks Print Yard")
	var yard = sim.planet("print_yard")
	sim.player.pos = yard.pos
	QuestBoard.pulse(sim, 0.2)
	check(str(sim.quest_flags.get("authored_print_yard", "")) == "done", "Print Yard files Second Copy after the factor")
	check(int(sim.quest_flags.get("charter_standing", 0)) > 0, "Second Copy writes charter standing")
	check(bool(sim.quest_flags.get("rumor_print_yard", false)), "Second Copy writes the print rumor")


func _fly(sim: SectorSim, actor: Dictionary, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		var step: float = minf(0.25, left)
		sim._step_npc(actor, step)
		left -= step


func _said(sim: SectorSim, text: String) -> bool:
	for row in sim.lines:
		if str(row.get("text", "")) == text:
			return true
	return false


func _named(sim: SectorSim, ship_name: String) -> Dictionary:
	for actor in sim.actors:
		if str(actor.name) == ship_name:
			return actor
	return {}


func _action(sim: SectorSim, action: String) -> Dictionary:
	for actor in sim.actors:
		if str(actor.ai.get("action", "")) == action and bool(actor.alive):
			return actor
	return {}


func _roles() -> void:
	var brass := make("vesper")
	brass._arrive("HC-V1-R1-S2", "")
	var officer := _action(brass, "range")
	check(not officer.is_empty(), "a range cutter is on Brass Lantern")
	var opened: float = officer.pos.distance_to(officer.home)
	brass.player.pos = officer.home + Vector2(4000, 0)
	brass.heat.helion_compact = 0.0
	officer.rot = (officer.home - officer.pos).angle()
	_fly(brass, officer, 2.4)
	var closed: float = officer.pos.distance_to(officer.home)
	var bearing := Vector2.from_angle(float(officer.ai.get("phase", 0.0)))
	var lateral: float = absf((officer.pos - officer.home).cross(bearing))
	check(closed < opened - 40.0, "the range cutter flies the line in through the yard (%.0f -> %.0f)" % [opened, closed])
	check(lateral < 90.0, "the range cutter stays on the firing line")
	check(bool(officer.ai.get("said_duty", false)) == false, "the range cutter stays quiet while the keel is far")
	var hail := make("vesper")
	hail._arrive("HC-V1-R1-S2", "")
	var speaker := _action(hail, "range")
	hail.player.pos = speaker.pos
	hail.heat.helion_compact = 0.0
	_fly(hail, speaker, 0.4)
	check(bool(speaker.ai.get("said_duty", false)), "the range cutter hails inside 640 meters while the slate is cool")
	var hot := make("vesper")
	hot._arrive("HC-V1-R1-S2", "")
	var quiet := _action(hot, "range")
	hot.player.pos = quiet.pos
	hot.heat.helion_compact = 20.0
	_fly(hot, quiet, 0.4)
	check(bool(quiet.ai.get("said_duty", false)) == false, "a hot slate keeps the range line from reading the duty")
	var writ := make("anvil")
	writ._arrive("HC-V1-R1-S3", "")
	var bailiff := _action(writ, "bailiff")
	var holt := _named(writ, "Bailiff Holt")
	check(not bailiff.is_empty() and not holt.is_empty(), "Writ posts a bailiff and Bailiff Holt")
	bailiff.pos = holt.pos + Vector2(480.0, 0.0)
	bailiff.vel = Vector2.ZERO
	var bench: Vector2 = holt.pos + Vector2(-120.0, -90.0)
	bailiff.rot = (bench - bailiff.pos).angle()
	var escort_bench: Vector2 = holt.pos + Vector2(120.0, 90.0)
	var bench_open: float = bailiff.pos.distance_to(bench)
	_fly(writ, bailiff, 2.8)
	check(bailiff.pos.distance_to(bench) < bench_open - 20.0, "the bailiff takes the far side of the clerk")
	check(bailiff.pos.distance_to(bench) < bailiff.pos.distance_to(escort_bench), "the bailiff does not sit the escort's shoulder")
	check(bool(bailiff.ai.get("said_duty", false)), "the bailiff reads the hold")
	var silo := make("kestrel")
	silo._arrive("HC-V1-R5-S5", "")
	var clerk := _named(silo, "Vault Clerk")
	silo.player.pos = Vector2(7000, 7000)
	silo.player.rot = 0.0
	clerk.pos = silo.player.pos + Vector2(220.0, 0.0)
	clerk.vel = Vector2.ZERO
	var flank: Vector2 = silo.player.pos + Vector2(0.0, 110.0)
	clerk.rot = (flank - clerk.pos).angle()
	var flank_open: float = clerk.pos.distance_to(flank)
	var clerk_y: float = clerk.pos.y
	_fly(silo, clerk, 0.6)
	var flank_after: float = clerk.pos.distance_to(flank)
	check(flank_after < flank_open - 8.0, "the Vault Clerk slides alongside (%.0f -> %.0f)" % [flank_open, flank_after])
	check(clerk.pos.y > clerk_y + 4.0, "the clerk takes the flank, not the tow nose")
	check(bool(clerk.ai.get("said_duty", false)), "the Vault Clerk names the silo")
	var guest := make("vesper")
	guest._arrive("HC-V1-R3-S3", "")
	var authored := _actor_role(guest, "interceptor")
	check(not authored.is_empty(), "Guest Lamp posts an authored interceptor")
	var park := Vector2(9000, 9000)
	authored.home = park
	authored.pos = park
	authored.vel = Vector2.ZERO
	authored.rot = PI
	guest.player.pos = park + Vector2(180.0, 0.0)
	guest.player.fight_cd = 0.0
	var held: float = authored.pos.distance_to(guest.player.pos)
	_fly(guest, authored, 1.2)
	var widened: float = authored.pos.distance_to(guest.player.pos)
	check(widened > held + 8.0, "an authored interceptor holds outside 200 meters (%.0f -> %.0f)" % [held, widened])
	authored.pos = park
	authored.vel = Vector2.ZERO
	authored.rot = 0.0
	guest.player.pos = park + Vector2(400.0, 0.0)
	var far: float = authored.pos.distance_to(guest.player.pos)
	_fly(guest, authored, 1.2)
	var nearer: float = authored.pos.distance_to(guest.player.pos)
	check(nearer < far - 8.0, "an authored interceptor closes from outside 260 meters (%.0f -> %.0f)" % [far, nearer])
	var helion := make("kestrel")
	var stock := {}
	for actor in helion.actors:
		if str(actor.team) == "red_keel" and str(actor.ai.get("role", "")) == "interceptor":
			stock = actor
	check(bool(stock.ai.get("role_authored", false)) == false, "Helion's interceptor stays on the old pack cycle")
	var nest: Vector2 = stock.home + Vector2(400.0, 0.0)
	stock.pos = nest
	stock.vel = Vector2.ZERO
	stock.rot = 0.0
	helion.player.pos = nest + Vector2(180.0, 0.0)
	helion.player.fight_cd = 0.0
	var stock_open: float = stock.pos.distance_to(helion.player.pos)
	_fly(helion, stock, 0.9)
	var stock_after: float = stock.pos.distance_to(helion.player.pos)
	check(stock_after < stock_open - 5.0, "a Helion interceptor still closes inside the old band (%.0f -> %.0f)" % [stock_open, stock_after])


func _body_open(sim: SectorSim, quest_id: String, body_id: String) -> bool:
	var rock = sim.planet(body_id)
	if rock == null:
		return false
	sim.player.pos = rock.pos
	QuestBoard.pulse(sim, 0.2)
	return str(sim.quest_flags.get(quest_id, "")) != "done"


func _steps() -> void:
	var road := make("anvil")
	road._arrive("HC-V1-R5-S3", "")
	var lighter := _named(road, "Lighter Pilot")
	check(QuestBoard.track(road, "authored_moth_lane") == "", "Track pins Pollinator Road")
	var moth_line := QuestBoard.cue_line(road)
	check(moth_line.contains("Lighter Pilot"), "the guide marks the Lighter Pilot before the tow is met")
	check(_body_open(road, "authored_moth_lane", "moth_lane"), "Moth Lane's shell does not file Pollinator Road")
	check(bool(road.quest_flags.get("authored_moth_lane_meet_lighter", false)) == false, "standing on Moth Lane does not meet the lighter")
	road.player.pos = lighter.pos + Vector2(40.0, 0.0)
	QuestBoard.pulse(road, 0.2)
	check(bool(road.quest_flags.get("authored_moth_lane_meet_lighter", false)), "closing on the Lighter Pilot records the tow")
	check(str(road.quest_flags.get("authored_moth_lane", "")) != "done", "the tow alone does not file Pollinator Road")
	var met := QuestBoard.cue_line(road)
	check(met.contains("Moth Lane"), "after the tow the guide marks Moth Lane")
	var lane = road.planet("moth_lane")
	road.player.pos = lane.pos
	QuestBoard.pulse(road, 0.2)
	check(str(road.quest_flags.get("authored_moth_lane", "")) == "done", "Moth Lane files Pollinator Road after the tow")
	check(int(road.quest_flags.get("charter_standing", 0)) > 0, "Pollinator Road writes charter standing")
	var school := make("vesper")
	school._arrive("HC-V1-R2-S6", "")
	var ambush := _actor_role(school, "ambush")
	check(QuestBoard.track(school, "authored_expired_charter") == "", "Track pins Fine Print")
	check(QuestBoard.cue_line(school).contains("school buoy"), "the guide marks the school buoy before the sight")
	check(_body_open(school, "authored_expired_charter", "expired_charter"), "Expired Charter's shell does not file Fine Print")
	school.player.pos = ambush.home + Vector2(80.0, 0.0)
	QuestBoard.pulse(school, 0.2)
	check(bool(school.quest_flags.get("authored_expired_charter_spring_sight", false)), "entering the ambush sight records the spring")
	check(str(school.quest_flags.get("authored_expired_charter", "")) != "done", "the sight alone does not file Fine Print")
	var charter = school.planet("expired_charter")
	school.player.pos = charter.pos
	QuestBoard.pulse(school, 0.2)
	check(str(school.quest_flags.get("authored_expired_charter", "")) == "done", "Expired Charter files Fine Print after the sight")
	var vault := make("anvil")
	vault._arrive("HC-V1-R5-S5", "")
	var keeper := _named(vault, "Vault Clerk")
	check(_body_open(vault, "authored_night_vault", "night_vault"), "Night Vault's shell does not file Silo Dark")
	vault.player.pos = keeper.pos + Vector2(40.0, 0.0)
	QuestBoard.pulse(vault, 0.2)
	check(bool(vault.quest_flags.get("authored_night_vault_alongside_clerk", false)), "coming alongside the Vault Clerk records the case")
	check(str(vault.quest_flags.get("authored_night_vault", "")) != "done", "the clerk alone does not file Silo Dark")
	var night = vault.planet("night_vault")
	vault.player.pos = night.pos
	QuestBoard.pulse(vault, 0.2)
	check(str(vault.quest_flags.get("authored_night_vault", "")) == "done", "Night Vault files Silo Dark after the clerk")
	var scales := make("vesper")
	scales._arrive("HC-V1-R1-S2", "")
	var range_cutter := _action(scales, "range")
	check(_body_open(scales, "authored_lamp_yard", "lamp_yard"), "Lamp Yard's shell does not file Honest Scales")
	scales.player.pos = range_cutter.pos + Vector2(40.0, 0.0)
	QuestBoard.pulse(scales, 0.2)
	check(bool(scales.quest_flags.get("authored_lamp_yard_range_line", false)), "closing on the range records the line")
	check(str(scales.quest_flags.get("authored_lamp_yard", "")) != "done", "the range alone does not file Honest Scales")
	var yard = scales.planet("lamp_yard")
	scales.player.pos = yard.pos
	QuestBoard.pulse(scales, 0.2)
	check(str(scales.quest_flags.get("authored_lamp_yard", "")) == "done", "Lamp Yard files Honest Scales after the range")
	var court := make("kestrel")
	court._arrive("HC-V1-R1-S3", "")
	var clerk_holt := _named(court, "Bailiff Holt")
	check(_body_open(court, "authored_warrant_house", "warrant_house"), "Warrant House's shell does not file Post the Writ")
	court.player.pos = clerk_holt.pos + Vector2(40.0, 0.0)
	QuestBoard.pulse(court, 0.2)
	check(bool(court.quest_flags.get("authored_warrant_house_alongside_holt", false)), "coming alongside Bailiff Holt records the tow")
	check(str(court.quest_flags.get("authored_warrant_house", "")) != "done", "Holt alone does not file Post the Writ")
	var house = court.planet("warrant_house")
	court.player.pos = house.pos
	QuestBoard.pulse(court, 0.2)
	check(str(court.quest_flags.get("authored_warrant_house", "")) == "done", "Warrant House files Post the Writ after Holt")
	var towline := make("anvil")
	towline._arrive("HC-V1-R2-S2", "")
	var tug := _named(towline, "Tug Factor")
	check(not tug.is_empty(), "Towline posts a Tug Factor")
	check(QuestBoard.track(towline, "authored_tug_yard") == "", "Track pins Tow the Yard")
	check(QuestBoard.cue_line(towline).contains("Tug Factor"), "the guide marks the Tug Factor before the tow")
	check(_body_open(towline, "authored_tug_yard", "tug_yard"), "Tug Yard's shell does not file Tow the Yard")
	check(bool(towline.quest_flags.get("authored_tug_yard_meet_tug", false)) == false, "standing on Tug Yard does not meet the tug")
	towline.player.pos = tug.pos + Vector2(40.0, 0.0)
	QuestBoard.pulse(towline, 0.2)
	check(bool(towline.quest_flags.get("authored_tug_yard_meet_tug", false)), "coming alongside the Tug Factor records the tow")
	check(_said(towline, "Tow the Yard: Tug Factor."), "the helm names the Tug Factor")
	check(str(towline.quest_flags.get("authored_tug_yard", "")) != "done", "the tug alone does not file Tow the Yard")
	check(QuestBoard.cue_line(towline).contains("Tug Yard"), "after the tug the guide marks Tug Yard")
	var bollard = towline.planet("tug_yard")
	towline.player.pos = bollard.pos
	QuestBoard.pulse(towline, 0.2)
	check(str(towline.quest_flags.get("authored_tug_yard", "")) == "done", "Tug Yard files Tow the Yard after the tug")
	check(int(towline.quest_flags.get("charter_standing", 0)) > 0, "Tow the Yard writes charter standing")
	var choir := make("kestrel")
	choir._arrive("HC-V1-R2-S3", "")
	var jumper := _actor_role(choir, "claim_jumper")
	check(not jumper.is_empty(), "Ore Choir's claim jumper is the pocket mark")
	check(QuestBoard.track(choir, "authored_choir_anvil") == "", "Track pins Ore Choir")
	check(QuestBoard.cue_line(choir).contains("rim pocket"), "the guide marks the rim pocket before the sight")
	check(_body_open(choir, "authored_choir_anvil", "choir_anvil"), "Choir Anvil's shell does not file Ore Choir")
	check(bool(choir.quest_flags.get("authored_choir_anvil_see_pocket", false)) == false, "standing on Choir Anvil does not see the pocket")
	choir.player.pos = jumper.home + Vector2(80.0, 0.0)
	QuestBoard.pulse(choir, 0.2)
	check(bool(choir.quest_flags.get("authored_choir_anvil_see_pocket", false)), "entering the rim pocket records the sight")
	check(_said(choir, "Ore Choir: the rim pocket."), "the helm names the rim pocket")
	check(str(choir.quest_flags.get("authored_choir_anvil", "")) != "done", "the pocket alone does not file Ore Choir")
	check(QuestBoard.cue_line(choir).contains("Choir Anvil"), "after the pocket the guide marks Choir Anvil")
	var anvil = choir.planet("choir_anvil")
	choir.player.pos = anvil.pos
	QuestBoard.pulse(choir, 0.2)
	check(str(choir.quest_flags.get("authored_choir_anvil", "")) == "done", "Choir Anvil files Ore Choir after the pocket")
	check(int(choir.quest_flags.get("charter_standing", 0)) > 0, "Ore Choir writes charter standing")


func _hooks() -> void:
	_meet_shell("vesper", "HC-V1-R1-S5", "authored_bonded_loft", "bonded_loft", "Bond Factor", "meet_factor", "Bonded Loft", "Bonded Loft: Bond Factor.", "compact_standing", "rumor_bonded_loft")
	_meet_shell("anvil", "HC-V1-R5-S4", "authored_first_stamp", "first_stamp", "Stamp Clerk", "meet_clerk", "First Stamp", "Broken Charter: Stamp Clerk.", "charter_standing", "rumor_first_stamp")
	_meet_shell("kestrel", "HC-V1-R3-S3", "authored_guest_station", "guest_station", "Lamp Host", "meet_host", "Guest Station", "Guest Lamp: Lamp Host.", "municipal_standing", "rumor_guest_station")
	_meet_shell("vesper", "HC-V1-R5-S2", "authored_hot_face", "hot_face", "Weather Shepherd", "meet_shepherd", "Hot Face", "Two Weathers: Weather Shepherd.", "charter_standing", "rumor_hot_face")
	_meet_shell("anvil", "HC-V1-R3-S2", "authored_algae_stack", "algae_stack", "Shift Boss", "meet_boss", "Algae Stack", "Lower Stack: Shift Boss.", "municipal_standing", "rumor_algae_stack")
	_meet_shell("kestrel", "HC-V1-R4-S5", "authored_feedstock", "feedstock", "Fine Clerk", "meet_clerk", "Feedstock", "Clean Hands: Fine Clerk.", "glass_standing", "rumor_feedstock")
	_meet_shell("vesper", "HC-V1-R3-S4", "authored_garden_moon", "garden_moon", "Orbit Clerk", "meet_clerk", "Garden Moon", "Not Ours: Orbit Clerk.", "municipal_standing", "rumor_garden_moon")
	_meet_shell("anvil", "HC-V1-R3-S6", "authored_night_market", "night_market", "Night Broker", "meet_broker", "Night Market", "After Hours: Night Broker.", "municipal_standing", "rumor_night_market")
	_meet_shell("kestrel", "HC-V1-R4-S6", "authored_research_shard", "research_shard", "License Warden", "meet_warden", "Research Shard", "The Exception: License Warden.", "glass_standing", "rumor_research_shard")


func _meet_shell(ship: String, system_id: String, quest_id: String, body_id: String, who: String, step_id: String, shell_name: String, said: String, standing: String, rumor: String) -> void:
	var sim := make(ship)
	sim._arrive(system_id, "")
	var actor := _named(sim, who)
	check(not actor.is_empty(), "%s posts %s" % [shell_name, who])
	if actor.is_empty():
		return
	check(QuestBoard.track(sim, quest_id) == "", "Track pins %s" % who)
	check(QuestBoard.cue_line(sim).contains(who), "the guide marks %s before the shell" % who)
	check(_body_open(sim, quest_id, body_id), "%s's shell does not file the job" % shell_name)
	var flag := "%s_%s" % [quest_id, step_id]
	check(bool(sim.quest_flags.get(flag, false)) == false, "standing on %s does not meet %s" % [shell_name, who])
	sim.player.pos = actor.pos + Vector2(40.0, 0.0)
	QuestBoard.pulse(sim, 0.2)
	check(bool(sim.quest_flags.get(flag, false)), "coming alongside %s records the meet" % who)
	check(_said(sim, said), "the helm names %s" % who)
	check(str(sim.quest_flags.get(quest_id, "")) != "done", "%s alone does not file the job" % who)
	var after := QuestBoard.cue_line(sim)
	check(after.contains(shell_name), "after %s the guide marks %s" % [who, shell_name])
	check(after.contains(who) == false, "after the meet the guide leaves %s" % who)
	var rock = sim.planet(body_id)
	sim.player.pos = rock.pos
	QuestBoard.pulse(sim, 0.2)
	check(str(sim.quest_flags.get(quest_id, "")) == "done", "%s files the job after %s" % [shell_name, who])
	check(int(sim.quest_flags.get(standing, 0)) > 0, "%s writes standing" % who)
	check(bool(sim.quest_flags.get(rumor, false)), "%s writes the rumor" % who)


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


func _guide() -> void:
	var sim := make("vesper")
	sim.quest_flags.shakedown_beat = "done"
	sim._arrive("HC-V1-R2-S5", "")
	check(str(sim.quest_flags.get("authored_print_yard", "")) == "open", "Second Copy stays on the slate after arrival")
	check(QuestBoard.cue_line(sim).begins_with("TRACK") == false, "an unpinned sky still uses the live cue")
	check(QuestBoard.track(sim, "authored_print_yard") == "", "Track pins Second Copy")
	var pinned := QuestBoard.cue_line(sim)
	check(pinned.begins_with("TRACK"), "the helm names the pinned job")
	check(pinned.contains("Second Copy"), "the pin names Second Copy")
	check(pinned.contains("Print Factor"), "the pin names the Print Factor before the shell")
	check(QuestBoard.cue_aim(sim).length() > 8.0, "the pin aims the amber beam")
	var card := QuestBoard.guide_card(sim, "authored_print_yard")
	check(str(card.get("detail", "")).contains("ambush") or str(card.get("detail", "")).contains("Print"), "the guide names the local work")
	check(str(card.get("finish", "")).contains("Print Yard"), "the guide states the finish")
	check(str(card.get("reward", "")) != "", "the guide states the reward")
	check(str(card.get("fail", "")) != "", "the guide states how it fails")
	sim._arrive("HC-V1-R1-S1", "")
	var kept := false
	for row in QuestLog.entries(sim.defs, sim):
		if str(row.get("id", "")) == "authored_print_yard" and str(row.get("state", "")) == "open":
			kept = true
			check(str(row.get("step", "")).contains("Print Yard") or str(row.get("step", "")).contains("Second Copy"), "the slate still names the next step from Helion")
	check(kept, "Second Copy stays on the slate after you leave")
	var away := QuestBoard.cue_line(sim)
	check(away.begins_with("TRACK") and away.contains("Second Copy"), "the pin still guides from another system")
	check(QuestBoard.track(sim, "authored_print_yard") == "", "tracking the same job clears the guide")
	check(QuestBoard.cue_line(sim).begins_with("TRACK") == false, "a cleared guide returns the live cue")
	var ice := make("anvil")
	ice.quest_flags.shakedown_beat = "done"
	ice.quest_flags.authored_tug_yard = "done"
	ice._arrive("HC-V1-R2-S4", "")
	QuestBoard.pulse(ice, 0.2)
	ice._arrive("HC-V1-R2-S2", "")
	check(QuestBoard.track(ice, "authored_water_lease") == "", "Track pins Water Lease")
	var lease := QuestBoard.cue_line(ice)
	check(lease.contains("Water Lease"), "the lease pin names itself at Towline")
	check(lease.contains("ice spall") or lease.contains("Clock"), "the lease pin names the unfinished step")
