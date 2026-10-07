extends SceneTree

var defs: Dictionary = {}
var fails := 0

const ROAD := [
	"HC-V1-R1-S2",
	"HC-V1-R2-S1",
	"HC-V1-R5-S1",
	"HC-V1-R5-S6",
	"HC-V1-R7-S1",
	"HC-V1-R8-S1",
]


func _init() -> void:
	defs = Catalog.boot()
	_content()
	_road()
	_claims()
	_craft_lane()
	_anvil()
	_vesper_pack()
	_kestrel_fight()
	_kine()
	_heat()
	_flags()
	_grief()
	_persist()
	_headless()
	if fails == 0:
		print("LIVEOPS PASS")
	else:
		print("LIVEOPS FAIL %d" % fails)
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
	return sim


func _occupied(sim) -> bool:
	var star = sim.defs.system.get("star", {})
	if typeof(star) != TYPE_DICTIONARY or str(star.get("name", "")) == "":
		return false
	return sim.planets.size() > 0


func _ride(sim, dest: String) -> String:
	var gate: Dictionary = {}
	for row in sim.gates:
		if str(row.get("to", "")) == dest:
			gate = row
			break
	if gate.is_empty():
		return "no gate to %s from %s" % [dest, str(sim.defs.system.id)]
	sim.player.pos = gate.pos
	var err: String = sim.try_lane()
	if err != "":
		return err
	if str(sim.defs.system.id) != dest:
		return "landed in %s" % str(sim.defs.system.id)
	return ""


func _content() -> void:
	var baseline: Dictionary = Serde.load_json("res://data/modules.json")
	for module_id in ["cheek_fin", "belly_spine", "lamp_jaw"]:
		check(baseline.has(module_id) == false, "%s is data, not compiled into modules.json" % module_id)
		check(defs.modules.has(module_id), "%s loads from the drop folder" % module_id)
		var bare := Silhouette.extent(Silhouette.parts("vesper", [], []))
		var layers := Silhouette.layers_of(defs, [module_id])
		var shaped := Silhouette.extent(Silhouette.parts("vesper", Silhouette.shapes_of(defs, [module_id]), layers))
		check(shaped.x > bare.x or shaped.y > bare.y, "%s changes the Vesper silhouette" % module_id)
	check(defs.crops.has("cinder_millet"), "cinder millet loads as data")
	check(defs.animals.has("lamp_moth"), "lamp moth loads as data")
	check(defs.templates.has("choir_ash_window"), "choir ash window is a template")
	check(defs.templates.has("unpaid_tow"), "unpaid tow is a template")
	check(str(defs.templates.unpaid_tow.get("uses", "")) == "trash", "unpaid tow uses a trash origin")
	check(defs.quests.has("authored_glass_coda"), "glass coda is an authored short")
	check(defs.quests.has("authored_stolen_coda"), "stolen coda is an authored short")
	var nameless: Dictionary = defs.systems["HC-V1-R6-S3"]
	check(str(nameless.get("stream", {}).get("id", "")) == "false_rain", "False Rain is on Nameless Chart")
	var clock: Dictionary = defs.systems["HC-V1-R6-S2"]
	check(str(clock.get("trash", {}).get("id", "")) == "missed_windows" and int(clock.get("trash", {}).get("count", 0)) > 0, "Missed Windows is trash on Clockstream")
	var stream_hit := false
	for item in defs.streams.get("streams", []):
		if str(item.get("id", "")) == "false_rain":
			stream_hit = true
	check(stream_hit, "false rain is indexed in streams.json")
	var trash_hit := false
	for item in defs.trash_origins.get("origins", []):
		if str(item.get("id", "")) == "missed_windows":
			trash_hit = true
	check(trash_hit, "missed windows is indexed in trash origins")
	var choir := make("vesper")
	choir._arrive("HC-V1-R4-S1", "")
	var coda = choir.planet("coda")
	check(coda != null, "Coda is a body on Choir Gate")
	if coda != null:
		choir.player.pos = coda.pos
	QuestBoard.pulse(choir, 0.2)
	check(str(choir.quest_flags.get("authored_glass_coda", "")) == "done", "glass coda completes from data")
	check(int(choir.quest_flags.get("glass_standing", 0)) > 0, "glass coda raises Glass standing")
	var sail := make("kestrel")
	sail._arrive("HC-V1-R8-S2", "")
	var stolen = sail.planet("stolen_coda")
	check(stolen != null, "Stolen Coda is a body")
	if stolen != null:
		sail.player.pos = stolen.pos
	QuestBoard.pulse(sail, 0.2)
	check(str(sail.quest_flags.get("authored_stolen_coda", "")) == "done", "stolen coda completes from data")
	check(float(sail.heat.get("black_sail", 0.0)) >= 8.0, "stolen coda warms Black Sail heat")
	var window := make("vesper")
	window.quest_flags.did_survey = true
	window.quest_flags.did_cull = true
	window.quest_flags.did_ledger = true
	window.quest_flags.did_towline = true
	window.quest_flags.did_gyre = true
	window.quest_flags.did_lantern = true
	window.quest_flags.did_defend = true
	window.quest_flags.did_meteor_window = true
	var offered := QuestBoard.refresh(window)
	check(offered == "systemic_choir_ash_window", "the choir ash template is offered after the meteor window")
	window.quest_flags.did_choir_ash_window = true
	window.contracts.clear()
	var tow := QuestBoard.refresh(window)
	check(tow == "systemic_unpaid_tow", "the trash template is offered from origins")


func _road() -> void:
	var sim := make("vesper")
	check(_occupied(sim), "Helion Dock is not an empty chart")
	for dest in ROAD:
		var err := _ride(sim, dest)
		check(err == "", "lane to %s (%s)" % [dest, err])
		check(_occupied(sim), "%s has a star and a body" % dest)
	check(str(sim.defs.system.id) == "HC-V1-R8-S1", "the red road ends at Black Quay")


func _claims() -> void:
	var brass := make("vesper")
	var err := _ride(brass, "HC-V1-R1-S2")
	check(err == "", "Brass Lantern is on the lane")
	brass.player.pos = brass.pocket_pos
	var blocked := Homestead.try_plant(brass)
	check(blocked.contains("Green capital"), "a green capital refuses a core")
	var soil := make("vesper")
	soil._arrive("HC-V1-R5-S1", "")
	soil.player.pos = soil.pocket_pos
	check(Homestead.try_plant(soil) == "", "Quiet Hollow still takes a core")


func _craft_lane() -> void:
	var sim := make("vesper")
	var probe = null
	for item in sim.craft:
		if str(item.state) == "docked":
			probe = item
			break
	check(probe != null, "the keel has a docked craft")
	if probe == null:
		return
	probe.state = "scan"
	probe.pos = Vector2(9000, 9000)
	var gate: Dictionary = sim.gates[0]
	sim.player.pos = gate.pos
	var refused := sim.try_lane()
	check(refused.contains("Recall"), "a lane refuses while craft are out")
	check(str(sim.defs.system.id) == "HC-V1-R1-S1", "the refused lane does not jump")
	check(probe.pos.distance_to(sim.player.pos) > 500.0, "the craft is not snapped home")
	sim._arrive(str(gate.get("to", "")), str(gate.get("arrive", "")))
	check(str(probe.state) == "lost", "a craft left out on a lane is lost")
	check(probe.pos.distance_to(sim.player.pos) > 500.0, "a lost craft does not appear on the new buoy")


func _anvil() -> void:
	var sim := make("anvil")
	var bare := Fit.stats(defs, sim.player)
	for module_id in ["extra_hold", "cargo_blister", "heavy_turret", "missile_rack", "keel_stretch"]:
		sim.install(module_id)
	var fat := Fit.stats(defs, sim.player)
	check(bool(fat.keel_warn), "an overloaded Anvil is over the keel")
	check(float(fat.yaw_deg) < float(bare.yaw_deg) * 0.45, "an overloaded Anvil yaws like a barn")
	check(float(fat.accel) < float(bare.accel) * 0.65, "an overloaded Anvil accelerates like a barn")


func _count_pirates(sim) -> int:
	var n := 0
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			n += 1
	return n


func _aim_pack(sim) -> void:
	var aim: Vector2 = sim.pack_pos
	var best := 99999.0
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			var dist: float = sim.player.pos.distance_to(actor.pos)
			if dist < best:
				best = dist
				aim = actor.pos
	sim.player.rot = (aim - sim.player.pos).angle()


func _vesper_pack() -> void:
	var sim := make("vesper")
	sim.hold_npc = false
	sim.player.pos = sim.pack_pos
	sim.player.grace_armed = true
	sim.player.grace_t = 0.0
	var i := 0
	for actor in sim.actors:
		if str(actor.team) == "red_keel" and bool(actor.alive):
			actor.pos = sim.pack_pos + Vector2(70, 18 * i)
			actor.rot = PI
			i += 1
	var t := 0.0
	while t < 18.0 and bool(sim.player.alive):
		_aim_pack(sim)
		sim.tick(0.05, {"thrust": 0.0, "rot": 0.0, "strafe": 0.0, "fire": true, "retro": 0.0})
		t += 0.05
	var broke := false
	for wreck in sim.wrecks:
		if str(wreck.get("class_id", "")) == "vesper":
			broke = true
	check(broke, "a naked Vesper dies if it stays in the pack and shoots")


func _kestrel_fight() -> void:
	var sim := make("kestrel")
	sim.hold_npc = false
	sim.player.pos = sim.pack_pos
	sim.player.grace_armed = true
	sim.player.grace_t = 0.0
	var n := 0
	for actor in sim.actors:
		if str(actor.team) != "red_keel":
			continue
		n += 1
		if n > 2:
			actor.alive = false
			actor.hp = 0.0
		else:
			actor.pos = sim.pack_pos + Vector2(80, 16 * n)
			actor.rot = PI
	var t := 0.0
	while t < 16.0 and bool(sim.player.alive) and _count_pirates(sim) > 0:
		_aim_pack(sim)
		sim.tick(0.05, {"thrust": 0.0, "rot": 0.0, "strafe": 0.0, "fire": true, "retro": 0.0})
		t += 0.05
	var broke := false
	for wreck in sim.wrecks:
		if str(wreck.get("class_id", "")) == "kestrel":
			broke = true
	check(bool(sim.player.alive) and _count_pirates(sim) == 0 and not broke, "a Kestrel wins a two-skiff fight")


func _kine() -> void:
	var hungry := make("kestrel")
	hungry._arrive("HC-V1-R5-S1", "")
	hungry.player.pos = hungry.pocket_pos
	check(Homestead.try_plant(hungry) == "", "the hungry claim plants")
	hungry.claim.pen.fodder = 0
	hungry.claim.crate.food = 0
	hungry.player.cargo.food_mass = 0
	var t := 0.0
	while t < 16.0:
		hungry.tick(0.05, {})
		t += 0.05
	check(bool(hungry.claim.pen.alive) == false, "a claim with no food loses the kine")
	var fed := make("kestrel")
	fed._arrive("HC-V1-R5-S1", "")
	fed.player.pos = fed.pocket_pos
	check(Homestead.try_plant(fed) == "", "the fed claim plants")
	fed.claim.pen.fodder = 3
	t = 0.0
	while t < 16.0:
		fed.tick(0.05, {})
		t += 0.05
	check(bool(fed.claim.pen.alive), "starter fodder keeps the kine through the same window")


func _heat() -> void:
	var sim := make("vesper")
	sim.hold_npc = false
	var cutter = null
	for actor in sim.actors:
		if str(actor.team) == "red_keel":
			actor.alive = false
			actor.pos = Vector2(12000, 12000)
		elif str(actor.team) == "helion_compact" and bool(actor.alive) and cutter == null:
			cutter = actor
	check(cutter != null, "Helion Dock has a cutter")
	if cutter == null:
		return
	sim.player.pos = cutter.pos + Vector2(400, 0)
	sim.player.rot = (cutter.pos - sim.player.pos).angle()
	var start_d: float = sim.player.pos.distance_to(cutter.pos)
	var t := 0.0
	while t < 2.0:
		sim.player.rot = (cutter.pos - sim.player.pos).angle()
		sim.tick(0.05, {"fire": true, "thrust": 0.0, "rot": 0.0, "strafe": 0.0, "retro": 0.0})
		t += 0.05
	var heat_v := float(sim.heat.get("helion_compact", 0.0))
	check(heat_v >= 12.0, "a shot in sight of the patrol raises heat")
	var closest: float = start_d
	var hp := float(sim.player.hp)
	t = 0.0
	while t < 14.0:
		sim.tick(0.05, {"fire": false, "thrust": 0.0, "rot": 0.0, "strafe": 0.0, "retro": 0.0})
		t += 0.05
		for actor in sim.actors:
			if str(actor.team) == "helion_compact" and bool(actor.alive):
				closest = minf(closest, sim.player.pos.distance_to(actor.pos))
		if float(sim.player.hp) < hp - 0.5 and heat_v >= 40.0:
			break
		heat_v = float(sim.heat.get("helion_compact", 0.0))
	check(closest < start_d - 40.0, "green heat brings a cutter in")
	check(float(sim.player.hp) < hp - 0.5, "once the heat is hot the cutter fires")


func _flags() -> void:
	var sim := make("vesper")
	QuestBoard._apply(sim, "salvage_grant")
	check(bool(sim.quest_flags.get("world_salvage", false)), "salvage grant leaves a world flag")
	check(int(sim.player.cargo.get("salvage_parts", 0)) > 0, "salvage grant still puts parts in the hold")
	QuestBoard._apply(sim, "dock_fee")
	check(bool(sim.quest_flags.get("world_dock_fee", false)), "a dock fee leaves a world flag")
	QuestBoard._apply(sim, "glasswheat_dearer")
	check(str(sim.quest_flags.get("world_glasswheat", "")) == "dearer", "a grain price leaves a world flag")


func _grief() -> void:
	var sim := make("vesper")
	sim._arrive("HC-V1-R5-S1", "")
	sim.player.pos = sim.pocket_pos
	check(Homestead.try_plant(sim) == "", "the crack test has a core")
	var thief: Dictionary = sim.admit("kestrel", "captain-thief")
	thief.pos = sim.pocket_pos
	check(Homestead.try_crack(sim, thief) == "", "a crack starts inside the pocket")
	var owner := str(sim.claim.agent_id)
	var t := 0.0
	while t < 7.0:
		sim.tick(0.05, {})
		t += 0.05
	check(str(sim.claim.agent_id) == owner, "the core does not change hands before the crack timer")
	while t < 9.0:
		sim.tick(0.05, {})
		t += 0.05
	check(str(sim.claim.agent_id) == str(thief.agent_id), "the core changes hands after the crack timer")
	var dock := make("vesper")
	var bully: Dictionary = dock.admit("kestrel", "captain-bully")
	dock.player.grace_armed = true
	dock.player.grace_t = 20.0
	dock.player.hp = 4.0
	dock.player.shield = 0.0
	dock.player.armor_hp = 0.0
	dock.damage_unit(dock.player, 40.0, str(bully.agent_id))
	check(bool(dock.player.alive) and float(dock.player.hp) == 1.0, "green grace keeps a new Helion keel")
	dock.player.flagged = true
	dock.player.warrant = false
	dock.heat["helion_compact"] = 0.0
	check(Law.scan_tag(dock, dock.player) == "flagged", "a criminal flag is visible on scan")


func _persist() -> void:
	var path := "user://dark_sector_host.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var sim := make("kestrel")
	sim._arrive("HC-V1-R5-S1", "")
	sim.player.pos = sim.pocket_pos
	check(Homestead.try_plant(sim) == "", "the host claim plants")
	sim._add_cargo("food_mass", 1)
	check(Homestead.sow(sim, "cinder_millet") == "", "cinder millet is sown")
	check(Homestead.stock(sim, "lamp_moth") == "", "a lamp moth is stocked")
	sim.player.yard.append("cheek_fin")
	var bolted: Dictionary = sim.install("cheek_fin")
	check(bool(bolted.get("ok", false)), "cheek fin bolts on")
	var lost := false
	for item in sim.craft:
		item.state = "lost"
		item.hp = 0.0
		lost = true
		break
	check(lost, "a craft is marked lost before the log")
	sim._add_cargo("salvage_parts", 2)
	sim.heat["helion_compact"] = 22.0
	sim.player.warrant = true
	sim.quest_flags.liveops_mark = true
	sim.scans["quiet_hollow"] = {"complete": true}
	if not sim.visited.has("HC-V1-R8-S1"):
		sim.visited.append("HC-V1-R8-S1")
	var owner := str(sim.claim.agent_id)
	var log := FileAccess.open(path, FileAccess.WRITE)
	check(log != null, "the world log opens")
	if log != null:
		log.store_string(JSON.stringify(sim.to_dict(), "\t"))
		log.close()
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(typeof(raw) == TYPE_DICTIONARY, "the world log parses")
	var back := SectorSim.new(defs)
	if typeof(raw) == TYPE_DICTIONARY:
		back.from_dict(raw)
	check(bool(back.claim.get("owned", false)), "host restart keeps the claim")
	check(str(back.claim.get("agent_id", "")) == owner, "host restart keeps the claim owner")
	check(str(back.claim.get("system_id", "")) == "HC-V1-R5-S1", "host restart keeps the claim system")
	check(str(back.claim.plot.get("crop", "")) == "cinder_millet", "host restart keeps the crop")
	var moth := false
	for animal in back.claim.get("stock", []):
		if str(animal.get("kind", "")) == "lamp_moth" and bool(animal.get("alive", false)):
			moth = true
	check(moth, "host restart keeps the animal")
	check(bool(back.claim.pen.get("alive", false)), "host restart keeps the kine")
	check(back.player.modules.has("cheek_fin"), "host restart keeps the ship layout")
	var still_lost := false
	for item in back.craft:
		if str(item.state) == "lost":
			still_lost = true
	check(still_lost, "host restart keeps a lost craft")
	check(int(back.player.cargo.get("salvage_parts", 0)) >= 2, "host restart keeps cargo")
	check(float(back.heat.get("helion_compact", 0.0)) >= 22.0, "host restart keeps heat")
	check(bool(back.player.get("warrant", false)), "host restart keeps a warrant")
	check(bool(back.quest_flags.get("liveops_mark", false)), "host restart keeps a quest flag")
	check(bool(back.scans.get("quiet_hollow", {}).get("complete", false)), "host restart keeps a discovery")
	check(back.visited.has("HC-V1-R8-S1"), "host restart keeps visited systems")


func _headless() -> void:
	var pid := OS.create_process(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://scripts/headless_host.gd",
	])
	check(pid > 0, "the headless host process starts")
	var client_link: ListenLink = null
	var client: SectorSim = null
	var seen := false
	var until := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until and not seen:
		if client_link == null:
			client_link = ListenLink.new()
			client = SectorSim.new(Catalog.boot())
			client.new_game("anvil")
			client.hold_npc = true
			client.player.player_id = "captain-guest"
			var joined := client_link.join("127.0.0.1:24565", "anvil", "captain-guest")
			if joined != "":
				client_link.close()
				client_link = null
				OS.delay_msec(250)
				continue
		client_link.take_client(client)
		if str(client.defs.system.id) == "HC-V1-R5-S1" and bool(client.claim.get("owned", false)):
			seen = true
			break
		OS.delay_msec(40)
	check(seen, "a second client joins the headless host and sees the claim")
	if client_link != null:
		client_link.close()
	if pid > 0:
		OS.kill(pid)
	var path := "user://dark_sector_host.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
