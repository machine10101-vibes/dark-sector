extends SceneTree

var defs: Dictionary = {}
var fails := 0

const FILL := [
	"HC-V1-R3-S1", "HC-V1-R3-S2", "HC-V1-R3-S3", "HC-V1-R3-S4", "HC-V1-R3-S5", "HC-V1-R3-S6",
	"HC-V1-R4-S1", "HC-V1-R4-S2", "HC-V1-R4-S3", "HC-V1-R4-S4", "HC-V1-R4-S5", "HC-V1-R4-S6",
	"HC-V1-R6-S2", "HC-V1-R6-S3", "HC-V1-R6-S4", "HC-V1-R6-S5", "HC-V1-R6-S6",
	"HC-V1-R7-S1", "HC-V1-R7-S2", "HC-V1-R7-S3", "HC-V1-R7-S4", "HC-V1-R7-S5", "HC-V1-R7-S6",
	"HC-V1-R8-S1", "HC-V1-R8-S2", "HC-V1-R8-S3", "HC-V1-R8-S4", "HC-V1-R8-S5", "HC-V1-R8-S6",
]


func _init() -> void:
	defs = Catalog.boot()
	_bad_file()
	_module()
	_clone_hunt()
	_reach()
	_choir()
	_quay()
	_claims()
	_life()
	_quests()
	_listen()
	if fails == 0:
		print("SLICE9 PASS")
	else:
		print("SLICE9 FAIL %d" % fails)
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


func _bad_file() -> void:
	var hit := false
	for line in Catalog.errors:
		if str(line).contains("_broken.json") and str(line).contains("JSON parse failed"):
			hit = true
	check(hit, "a bad system file is skipped with a precise error")
	check(defs.systems.has("HC-V1-R1-S1"), "Helion Dock is still on the board")
	var sim := make("vesper")
	check(str(sim.defs.system.id) == "HC-V1-R1-S1", "a bad file does not stop a new game")
	check(sim.player.alive, "the keel is alive after a bad file")


func _module() -> void:
	var baseline: Dictionary = Serde.load_json("res://data/modules.json")
	check(not baseline.has("keel_cage"), "keel cage is not compiled into the module script data")
	check(defs.modules.has("keel_cage"), "keel cage loads from modules/keel_cage.json")
	var bare := Silhouette.extent(Silhouette.parts("vesper", [], []))
	var layers := Silhouette.layers_of(defs, ["keel_cage"])
	var shaped := Silhouette.extent(Silhouette.parts("vesper", Silhouette.shapes_of(defs, ["keel_cage"]), layers))
	check(shaped.x > bare.x and shaped.x >= 140.0, "keel cage lengthens the Vesper silhouette")
	var anvil_bare := Silhouette.extent(Silhouette.parts("anvil", [], []))
	var anvil := Silhouette.extent(Silhouette.parts("anvil", Silhouette.shapes_of(defs, ["keel_cage"]), layers))
	check(anvil.x > anvil_bare.x, "keel cage lengthens the Anvil silhouette")
	var sim := make("kestrel")
	var before := Silhouette.extent(Silhouette.parts("kestrel", [], []))
	var granted := Catalog.grant(sim, "module", "keel_cage")
	check(sim.player.modules.has("keel_cage"), "grant bolts the dropped module")
	check(granted.contains("Keel Cage"), "the yard names the dropped module")
	var after := Silhouette.extent(Silhouette.parts("kestrel", Silhouette.shapes_of(defs, sim.player.modules), Silhouette.layers_of(defs, sim.player.modules)))
	check(after.x > before.x, "the granted cage changes the Kestrel outline")
	check(defs.crops.has("silkreed") and defs.animals.has("ribbon_goat"), "silkreed and ribbon goats load as data")
	check(defs.craft.has("marker_buoy"), "a craft file loads without entering a starter rack")
	check(not sim.player.get("craft_ids", []).has("marker_buoy"), "the marker buoy is not forced onto the keel")


func _clone_hunt() -> void:
	var seen_belts := {}
	var seen_origins := {}
	for sid in FILL:
		check(defs.systems.has(sid), "%s loaded" % sid)
		if not defs.systems.has(sid):
			continue
		var sys: Dictionary = defs.systems[sid]
		var planets: Array = sys.get("planets", [])
		check(planets.size() >= 2, "%s has bodies" % sid)
		check(str(sys.get("star", {}).get("name", "")) != "", "%s has a star" % sid)
		check(str(sys.get("why_visit", "")).contains("."), "%s has a why_visit" % sid)
		var law := str(sys.get("law_color", ""))
		check(["green", "amber", "red"].has(law), "%s has a legal color" % sid)
		var belt: Dictionary = sys.get("belt", {})
		var ring := false
		for body in planets:
			var planet: Dictionary = body
			var pname := str(planet.get("name", "")).to_lower()
			check(not pname.begins_with("planet ") and not pname.begins_with("rock-") and not pname.contains("untitled"), "%s body %s is named" % [sid, planet.get("name", "")])
			if bool(planet.get("ring", false)):
				ring = true
		var composition := str(belt.get("composition", ""))
		if int(belt.get("count", 0)) > 0:
			check(not composition.to_lower().contains("asteroid belt"), "%s belt is not generic" % sid)
			check(not seen_belts.has(composition), "%s belt composition is unique" % sid)
			seen_belts[composition] = sid
		check(int(belt.get("count", 0)) > 0 or ring, "%s has a belt or a ring" % sid)
		var trash: Dictionary = sys.get("trash", {})
		var stream: Dictionary = sys.get("stream", {})
		var junk := int(trash.get("count", 0)) > 0 or str(stream.get("id", "")) != ""
		check(junk, "%s has junk or a stream" % sid)
		if int(trash.get("count", 0)) > 0:
			var origin := str(trash.get("origin", ""))
			check(origin != "" and not seen_origins.has(origin), "%s trash origin is unique" % sid)
			seen_origins[origin] = sid
		var nodes: Array = sys.get("nodes", [])
		var layered := false
		for node in nodes:
			var row: Dictionary = node
			if str(row.get("kind", "")) == "planet":
				var layers: Dictionary = row.get("layers", {})
				layered = layers.has("orbit") and layers.has("atmosphere") and layers.has("surface") and layers.has("crust") and layers.has("biosign") and layers.has("ruins") and layers.has("legal")
				break
		check(layered, "%s has scan layers" % sid)
		var living := int(sys.get("pdo", {}).get("count", 0)) > 0 or int(sys.get("pirates", {}).get("count", 0)) > 0 or not (sys.get("haulers", []) as Array).is_empty()
		check(living, "%s has a living use" % sid)


func _reach() -> void:
	var seen := {}
	var queue: Array = ["HC-V1-R1-S1"]
	while not queue.is_empty():
		var sid := str(queue.pop_front())
		if seen.has(sid) or not defs.systems.has(sid):
			continue
		seen[sid] = true
		for gate in defs.systems[sid].get("gates", []):
			queue.append(str(gate.get("to", "")))
	for sid in FILL:
		check(seen.has(sid), "%s is reachable from Helion Dock" % sid)
	var sim := make("vesper")
	check(ride_to(sim, "HC-V1-R3-S4") == "", "a lane reaches Not Ours")
	check(str(sim.defs.system.name) == "Not Ours", "Not Ours keeps its atlas name")
	var desk := Catalog.describe(sim)
	check(desk.contains("Not Ours") and desk.contains(str(sim.defs.system.why_visit)), "the desk prints why_visit")
	check(desk.contains("green"), "the desk prints the rule color")


func path_to(dest: String) -> Array:
	var parent := {}
	var via := {}
	var seen := {"HC-V1-R1-S1": true}
	var queue: Array = ["HC-V1-R1-S1"]
	while not queue.is_empty():
		var sid := str(queue.pop_front())
		if sid == dest:
			break
		if not defs.systems.has(sid):
			continue
		for gate in defs.systems[sid].get("gates", []):
			var nxt := str(gate.get("to", ""))
			if nxt == "" or seen.has(nxt) or not defs.systems.has(nxt):
				continue
			seen[nxt] = true
			parent[nxt] = sid
			via[nxt] = str(gate.get("id", ""))
			queue.append(nxt)
	var hops: Array = []
	var cursor := dest
	while cursor != "HC-V1-R1-S1" and parent.has(cursor):
		hops.push_front(str(via[cursor]))
		cursor = str(parent[cursor])
	return hops


func ride_to(sim: SectorSim, dest: String) -> String:
	for gate_id in path_to(dest):
		var found := false
		for row in sim.gates:
			var gate: Dictionary = row
			if str(gate.get("id", "")) != str(gate_id):
				continue
			sim.player.pos = gate.pos
			var err := sim.try_lane()
			if err != "":
				return err
			found = true
			break
		if not found:
			return "missing %s" % str(gate_id)
	if str(sim.defs.system.id) == dest:
		return ""
	return "missed %s" % dest


func _choir() -> void:
	var gate: Dictionary = defs.systems["HC-V1-R4-S1"]
	check(not gate.get("checkpoint", {}).is_empty(), "Choir Gate keeps its checkpoint block")
	var sim := make("vesper")
	sim._add_cargo("food_mass", 2)
	sim._add_cargo("silkreed", 1)
	sim.player.kine_aboard = true
	sim._arrive("HC-V1-R4-S1", "")
	check(int(sim.player.cargo.get("food_mass", 0)) == 0 and int(sim.player.cargo.get("silkreed", 0)) == 0, "Choir Gate confiscates living cargo")
	check(not bool(sim.player.kine_aboard), "Choir Gate takes a kine off the keel")
	var cleared := false
	for line in sim.lines:
		if str(line).contains("confiscates"):
			cleared = true
	check(cleared, "Choir Gate says why the hold was taken")
	var standing := make("anvil")
	standing.quest_flags.glass_standing = 1
	standing._add_cargo("food_mass", 2)
	standing._arrive("HC-V1-R4-S1", "")
	check(int(standing.player.cargo.get("food_mass", 0)) == 2, "Glass standing clears the hold")


func _quay() -> void:
	var quay: Dictionary = defs.systems["HC-V1-R8-S1"]
	check(str(quay.law_color) == "red", "Black Quay is a red system")
	check(str(quay.flagship) == "Quay", "Black Quay names Quay")
	var sim := make("vesper")
	sim._arrive("HC-V1-R8-S1", "")
	check(Law.at(sim, sim.player.pos) == "red", "Black Quay law is red on the board")
	check(sim.planet("quay") != null, "Quay is a body")
	var factor := false
	for actor in sim.actors:
		if str(actor.name) == "Quay Factor":
			factor = true
	check(factor, "Black Quay has a port factor")
	check(sim.defs.factions.has("black_sail"), "Black Sail loads from a faction file")


func _claims() -> void:
	var sim := make("vesper")
	sim._arrive("HC-V1-R5-S1", "soil_lane")
	sim.player.pos = sim.pocket_pos
	check(Homestead.try_plant(sim) == "", "Quiet Hollow is still a filed slot")
	var closed := make("anvil")
	closed._arrive("HC-V1-R3-S4", "")
	closed.player.pos = closed.pocket_pos
	check(Homestead.try_plant(closed) != "", "Not Ours does not take a core")
	var wake := make("kestrel")
	wake._arrive("HC-V1-R7-S5", "")
	wake.player.pos = wake.pocket_pos
	check(Homestead.try_plant(wake) == "", "Claimwake plants on its filed slot")


func _life() -> void:
	var sim := make("vesper")
	sim._arrive("HC-V1-R5-S1", "soil_lane")
	sim.player.pos = sim.pocket_pos
	check(Homestead.try_plant(sim) == "", "the life test has a claim")
	check(Homestead.sow(sim, "silkreed") == "", "silkreed sows from data")
	sim.player.vel = Vector2(40, 0)
	for _i in 16:
		Homestead.step(sim, 0.5)
	check(str(sim.claim.plot.get("state", "")) == "failed", "silkreed dies when the keel keeps moving")
	var herd := make("anvil")
	herd._arrive("HC-V1-R7-S5", "")
	herd.player.pos = herd.pocket_pos
	check(Homestead.try_plant(herd) == "", "the goat test has a claim")
	herd._add_cargo("food_mass", 1)
	check(Homestead.stock(herd, "ribbon_goat") == "", "ribbon goats stock from data")
	for _i in 20:
		Homestead.step(herd, 0.5)
	var dead := false
	for row in herd.claim.stock:
		if str(row.get("kind", "")) == "ribbon_goat" and not bool(row.get("alive", false)):
			dead = true
	check(dead, "a ribbon goat starves without food")


func _quests() -> void:
	var sim := make("vesper")
	sim._add_cargo("food_mass", 2)
	QuestBoard.pulse(sim, 0.2)
	sim._arrive("HC-V1-R3-S4", "")
	QuestBoard.pulse(sim, 0.2)
	sim._arrive("HC-V1-R7-S3", "")
	QuestBoard.pulse(sim, 0.2)
	check(str(sim.quest_flags.get("authored_jurisdiction_hole", "")) == "done", "the jurisdiction hole run completes from data")
	check(bool(sim.quest_flags.get("rumor_jurisdiction", false)), "the smuggler run leaves a rumor")
	check(int(sim.market.get("glasswheat", 0)) > 4, "the smuggler run moves a price")
	var spindle := make("kestrel")
	spindle._arrive("HC-V1-R3-S1", "")
	var rock = spindle.planet("spindle")
	check(rock != null, "Spindle is a body")
	if rock != null:
		spindle.player.pos = rock.pos
	QuestBoard.pulse(spindle, 0.2)
	check(str(spindle.quest_flags.get("authored_spindle", "")) == "done", "Spindle's hook is data")
	check(int(spindle.market.get("dock_fee", 0)) > 2, "Spindle raises the dock fee")
	check(int(spindle.quest_flags.get("municipal_standing", 0)) > 0, "Spindle raises municipal standing")
	var hymn := make("vesper")
	hymn._arrive("HC-V1-R4-S4", "")
	var ash = hymn.planet("ash_hymn")
	if ash != null:
		hymn.player.pos = ash.pos
	QuestBoard.pulse(hymn, 0.2)
	check(int(hymn.quest_flags.get("glass_standing", 0)) > 0, "Ash Hymn grants Glass standing")
	var step := make("anvil")
	step._arrive("HC-V1-R7-S1", "")
	var step_body = step.planet("step")
	if step_body != null:
		step.player.pos = step_body.pos
	QuestBoard.pulse(step, 0.2)
	check(float(step.heat.get("red_keel", 0.0)) >= 8.0, "Step warms Red Keel heat")
	var port := make("kestrel")
	port._arrive("HC-V1-R8-S1", "")
	var quay_body = port.planet("quay")
	if quay_body != null:
		port.player.pos = quay_body.pos
	QuestBoard.pulse(port, 0.2)
	check(str(port.quest_flags.get("claim_law", "")) == "red", "Quay files claim law red")
	check(float(port.heat.get("black_sail", 0.0)) >= 8.0, "Quay warms Black Sail heat")
	check(not port.quest_flags.has("xp"), "flagship hooks do not grant XP")
	var window := make("vesper")
	window.quest_flags.did_survey = true
	window.quest_flags.did_cull = true
	window.quest_flags.did_ledger = true
	window.quest_flags.did_towline = true
	window.quest_flags.did_gyre = true
	window.quest_flags.did_lantern = true
	window.quest_flags.did_defend = true
	var offered := QuestBoard.refresh(window)
	check(offered == "systemic_meteor_window", "meteor-window salvage is offered from the template")
	var job: Dictionary = {}
	for row in window.contracts:
		if str(row.get("id", "")) == "systemic_meteor_window":
			job = row
	var streams: Array = defs.get("streams", {}).get("streams", [])
	var known := false
	for item in streams:
		if str(item.get("system_id", "")) == str(job.get("system_id", "")):
			known = true
	check(known, "the meteor window uses streams.json")
	check(QuestBoard.accept(window) == "", "the meteor window is taken")
	window._add_cargo("salvage_parts", 1)
	window._arrive(str(job.get("system_id", "")), "")
	window.tick(0.2, {})
	check(bool(window.quest_flags.get("did_meteor_window", false)), "salvage in the stream window completes the template")


func _listen() -> void:
	var host_defs := Catalog.boot()
	var client_defs := Catalog.boot()
	var host := SectorSim.new(host_defs)
	host.new_game("vesper")
	host.hold_npc = true
	var client := SectorSim.new(client_defs)
	client.new_game("anvil")
	client.player.player_id = "captain-guest"
	host._arrive("HC-V1-R8-S1", "")
	var snap: Dictionary = host.net_snapshot()
	client.apply_snapshot(snap)
	check(str(client.defs.system.id) == "HC-V1-R8-S1", "a snapshot carries Black Quay to the second captain")
	var host_link := ListenLink.new()
	var client_link := ListenLink.new()
	var opened := host_link.open_host()
	check(opened == "", "the host opens a listen port for the new chart")
	if opened != "":
		return
	var joined := client_link.join("127.0.0.1:24565", "anvil", "captain-guest")
	check(joined == "", "the second captain addresses the host")
	var admitted := false
	for _i in 50:
		client_link.take_client(client)
		host_link.take_host(host)
		host_link.broadcast(host)
		client_link.take_client(client)
		if host.captains.size() == 1 and str(client.defs.system.id) == "HC-V1-R8-S1":
			admitted = true
			break
		OS.delay_msec(20)
	check(admitted, "the listen board loads Black Quay from data")
	host_link.close()
	client_link.close()
