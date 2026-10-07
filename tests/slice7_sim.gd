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
	_overlays()
	_green_law()
	_red_law()
	_amber_law()
	_grace_and_scan()
	_crack()
	_save()
	_listen()
	if fails == 0:
		print("SLICE7 PASS")
	else:
		print("SLICE7 FAIL %d" % fails)
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


func _to_soil(sim: SectorSim) -> void:
	var gate: Dictionary = sim.gates[0]
	sim.player.pos = gate.pos
	sim.try_lane()


func _red_pos(sim: SectorSim) -> Vector2:
	for disc in Law.discs(sim):
		var row: Dictionary = disc
		if str(row.get("kind", "")) == "red":
			return row.pos
	return Vector2.ZERO


func _overlays() -> void:
	var sim := make("vesper")
	var aegis = sim.planet("aegis_prime")
	check(Law.at(sim, sim.player.pos) == "green", "Aegis orbit where the keel wakes is green")
	var ring: Vector2 = aegis.pos + Vector2.from_angle(0.15) * (float(aegis.radius) + 43.0)
	check(Law.at(sim, ring) == "amber", "the ice ring lease is amber")
	check(Law.at(sim, sim.trash_pos) == "amber", "Seized Hold is amber while Compact is off the field")
	var watched := false
	for actor in sim.actors:
		if str(actor.team) == "helion_compact":
			actor.pos = sim.trash_pos
			watched = true
			break
	check(watched and Law.at(sim, sim.trash_pos) == "green", "Seized Hold is green when a cutter is on site")
	var gate: Dictionary = sim.gates[0]
	check(gate.pos.distance_to(aegis.pos) > float(sim.defs.system.zones.green.radius), "the lane buoy is outside the orbit disc")
	check(Law.at(sim, gate.pos) == "green", "the Helion Dock lane itself is green")
	_to_soil(sim)
	check(Law.at(sim, sim.pocket_pos) == "amber", "Quiet Hollow is amber claim country")
	var red: Vector2 = _red_pos(sim)
	check(red != Vector2.ZERO, "Perimeter is a red box on the First Soil chart")
	check(Law.at(sim, red) == "red", "the Perimeter road is red")
	check(str(sim.defs.system.get("law", {}).get("red", {}).get("atlas", "")) == "HC-V1-R5-S6", "the red box keeps the Perimeter atlas id")
	var saw_green := false
	var saw_amber := false
	var saw_red := false
	for disc in Law.discs(sim):
		var row: Dictionary = disc
		var kind := str(row.get("kind", ""))
		if kind == "green":
			saw_green = true
		elif kind == "amber":
			saw_amber = true
		elif kind == "red":
			saw_red = true
	check(saw_amber and saw_red, "First Soil draws amber and red on the same map")
	var dock := make("kestrel")
	for disc in Law.discs(dock):
		if str(disc.get("kind", "")) == "green":
			saw_green = true
	check(saw_green, "Helion Dock draws a green overlay")


func _green_law() -> void:
	var sim := make("vesper")
	var guest: Dictionary = sim.admit("anvil", "captain-2")
	guest.pos = sim.player.pos + Vector2(180, 0)
	guest.rot = PI
	guest.fire_cd = 0.0
	var before := float(sim.heat.get("helion_compact", 0.0))
	var guest_before := float(guest.get("heat_compact", 0.0))
	for _i in 12:
		sim.try_fire(guest, Fit.stats(defs, guest).gun)
		sim.tick(0.05, {})
		guest.fire_cd = 0.0
	check(float(guest.heat_compact) >= 40.0, "a shot on a captain in the green puts real heat on the shooter")
	check(bool(guest.warrant), "the green shot writes a warrant")
	check(sim.law_target == str(guest.agent_id), "the patrol is aimed at the captain who fired")
	check(float(sim.heat.get("helion_compact", 0.0)) == before, "the other captain's slate does not take that heat")
	check(float(guest.heat_compact) > guest_before, "guest heat moved")
	check(Law.scan_tag(sim, guest) == "WARRANT", "the warrant is visible on scan")
	var nearest := 100000.0
	for actor in sim.actors:
		if str(actor.team) != "helion_compact":
			continue
		var dist: float = actor.pos.distance_to(guest.pos)
		if dist < nearest:
			nearest = dist
	sim.hold_npc = false
	sim.tick(2.0, {})
	var later := 100000.0
	for actor in sim.actors:
		if str(actor.team) != "helion_compact" or not bool(actor.alive):
			continue
		var dist: float = actor.pos.distance_to(guest.pos)
		if dist < later:
			later = dist
	check(later < nearest - 20.0, "a Compact cutter actually closes on the green warrant")
	check(bool(guest.alive) and str(guest.class_id) == "anvil", "the shooter is still the same ship")


func _red_law() -> void:
	var sim := make("kestrel")
	_to_soil(sim)
	var red: Vector2 = _red_pos(sim)
	var guest: Dictionary = sim.admit("vesper", "captain-red")
	sim.player.pos = red
	guest.pos = red + Vector2(160, 0)
	guest.rot = PI
	var heat_before := float(sim.heat.get("helion_compact", 0.0))
	var guest_before := float(guest.get("heat_compact", 0.0))
	sim.damage_unit(guest, 6.0, str(sim.player.agent_id))
	check(float(sim.heat.get("helion_compact", 0.0)) == heat_before, "a shot in the red does not move Compact heat")
	check(float(guest.heat_compact) == guest_before, "the red shot does not write guest heat")
	check(not bool(sim.player.warrant), "the red shot does not write a warrant")
	check(sim.law_target == "", "the red shot does not call the patrol")
	check(not sim.pdo_alert, "the red shot does not open patrol guns")


func _amber_law() -> void:
	var sim := make("vesper")
	var aegis = sim.planet("aegis_prime")
	var ring: Vector2 = aegis.pos + Vector2.from_angle(0.15) * (float(aegis.radius) + 43.0)
	var tangent := Vector2.from_angle(0.15 + PI * 0.5)
	var guest: Dictionary = sim.admit("kestrel", "captain-amber")
	sim.player.pos = ring
	guest.pos = ring + tangent * 18.0
	check(Law.at(sim, sim.player.pos) == "amber" and Law.at(sim, guest.pos) == "amber", "both keels sit in the ice lease")
	sim.player.flagged = true
	guest.flagged = true
	var before := float(sim.heat.get("helion_compact", 0.0))
	sim.damage_unit(guest, 4.0, str(sim.player.agent_id))
	check(float(sim.heat.get("helion_compact", 0.0)) == before, "a flagged amber duel does not raise Compact heat")
	check(not bool(sim.player.warrant), "a flagged amber duel does not write a warrant")
	var bare := make("anvil")
	var body = bare.planet("aegis_prime")
	var lease: Vector2 = body.pos + Vector2.from_angle(0.15) * (float(body.radius) + 43.0)
	var other: Dictionary = bare.admit("vesper", "captain-bare")
	bare.player.pos = lease
	other.pos = lease + Vector2.from_angle(0.15 + PI * 0.5) * 18.0
	for actor in bare.actors:
		if str(actor.team) == "helion_compact":
			actor.pos = Vector2(8000, 8000)
	var parked := float(bare.heat.get("helion_compact", 0.0))
	bare.damage_unit(other, 4.0, str(bare.player.agent_id))
	check(float(bare.heat.get("helion_compact", 0.0)) == parked + 12.0, "an unflagged amber shot is noted, not a warrant")
	check(not bool(bare.player.warrant), "the amber note is not a warrant")
	check(not bare.pdo_alert, "the amber note does not bring guns")


func _grace_and_scan() -> void:
	var sim := make("vesper")
	var bully: Dictionary = sim.admit("kestrel", "captain-bully")
	sim.player.grace_armed = true
	sim.player.grace_t = 20.0
	sim.player.hp = 4.0
	sim.player.shield = 0.0
	sim.player.armor_hp = 0.0
	var klass := str(sim.player.class_id)
	sim.damage_unit(sim.player, 40.0, str(bully.agent_id))
	check(bool(sim.player.alive) and float(sim.player.hp) == 1.0, "green grace keeps a new keel from being wiped in Helion Dock")
	check(str(sim.player.class_id) == klass, "grace does not swap the hull")
	check(Law.scan_tag(sim, bully) == "WARRANT", "the captain who fired wears a warrant on scan")


func _crack() -> void:
	var sim := make("vesper")
	_to_soil(sim)
	sim.player.pos = sim.pocket_pos
	check(Homestead.try_plant(sim) == "", "the core goes down on Quiet Hollow")
	check(str(sim.claim.slot_id) == "HC-V1-R5-S1:green_wound:quiet_hollow", "the claim slot is First Soil / Green Wound / Quiet Hollow")
	var guest: Dictionary = sim.admit("anvil", "captain-raider")
	guest.pos = sim.pocket_pos + Vector2(30, 0)
	check(Homestead.try_crack(sim, guest) == "", "the second captain starts the crack")
	check(bool(sim.claim.flare), "the crack flares on the chart")
	var owner_hp: float = sim.player.hp
	var owner_class := str(sim.player.class_id)
	sim.claim.crack.t = 7.2
	sim.tick(1.0, {})
	check(str(sim.claim.agent_id) == str(guest.agent_id), "the crack timer hands the core over")
	check(bool(sim.player.alive) and str(sim.player.class_id) == owner_class, "losing the core does not delete the ship")
	check(absf(float(sim.player.hp) - owner_hp) < 0.1, "losing the core does not scrap the hull")
	var locked: Array = sim.claim.locked_out
	check(locked.has(str(sim.player.agent_id)), "the loser is locked out")
	check(sim.claim.has("plot") and sim.claim.has("pen"), "the homestead contents stay")
	check(Homestead.tend(sim).find("locked") >= 0, "the loser cannot tend the plot")

	var held := make("anvil")
	_to_soil(held)
	held.player.pos = held.pocket_pos
	check(Homestead.try_plant(held) == "", "a second homestead plants")
	var raider: Dictionary = held.admit("kestrel", "captain-crack")
	raider.pos = held.pocket_pos + Vector2(20, 10)
	check(Homestead.try_crack(held, raider) == "", "another crack starts")
	held.player.pos = raider.pos + Vector2(150, 0)
	held.player.rot = PI
	held.player.fire_cd = 0.0
	held.tick(0.45, {"fire": true})
	check(not bool(held.claim.crack.get("active", false)), "the owner shooting stops the crack")
	check(str(held.claim.agent_id) == str(held.player.agent_id), "the core stays with the owner")

	check(Homestead.try_crack(held, raider) == "", "the raider starts again")
	held.player.pos = _red_pos(held)
	held.quest_flags.compact_standing = 2
	var denied := Homestead.try_hail(held)
	check(denied.find("red") >= 0, "a hail in the red is refused")
	check(bool(held.claim.crack.get("active", false)), "the refused hail leaves the crack running")
	held.player.pos = held.pocket_pos
	check(Homestead.try_hail(held) == "", "standing pays a hail on amber ground")
	check(int(held.quest_flags.compact_standing) == 1, "the hail spends standing")
	check(not bool(held.claim.crack.get("active", false)), "the hail stops the crack")

	check(Homestead.try_crack(held, raider) == "", "the raider starts a third time")
	var probe := {}
	for item in held.craft:
		if str(item.def_id) == "survey_probe":
			probe = item
	probe.state = "orbit"
	probe.order = "orbit"
	check(CraftOrders.order(held, str(probe.uid), "return", "") == "", "the owner recalls a craft")
	check(not bool(held.claim.crack.get("active", false)), "recalling craft stops the crack")

	raider.cargo = {"raw_mass": 4}
	raider.hp = 3.0
	raider.shield = 0.0
	raider.armor_hp = 0.0
	held.damage_unit(raider, 20.0, "agent:red_keel:0")
	check(bool(raider.alive) and str(raider.class_id) == "kestrel", "a broken guest keel respawns as the same ship")
	check(int(raider.cargo.get("raw_mass", 0)) == 2, "wreck rules drop half the hold and keep the rest")
	var named := false
	for wreck in held.wrecks:
		if str(wreck.agent_id) == str(raider.agent_id):
			named = int(wreck.cargo.get("raw_mass", 0)) == 2
	check(named, "the wreck keeps the dropped cargo")


func _save() -> void:
	var sim := make("vesper")
	_to_soil(sim)
	sim.player.pos = sim.pocket_pos
	Homestead.try_plant(sim)
	var guest: Dictionary = sim.admit("anvil", "captain-save")
	guest.pos = sim.pocket_pos
	Homestead.try_crack(sim, guest)
	sim.claim.crack.t = 7.5
	sim.tick(1.0, {})
	var owner := str(sim.claim.agent_id)
	var data = JSON.parse_string(JSON.stringify(sim.to_dict()))
	var loaded := SectorSim.new(defs)
	loaded.from_dict(data)
	check(str(loaded.claim.agent_id) == owner, "reload restores claim ownership")
	check(loaded.claim.locked_out.has(str(sim.player.agent_id)), "reload restores the lockout")
	check(str(loaded.claim.slot_id) == "HC-V1-R5-S1:green_wound:quiet_hollow", "reload restores the slot id")
	check(loaded.captains.size() == 1, "reload restores the second captain")
	check(str(loaded.captains[0].class_id) == "anvil", "the second captain is still the Barn")
	check(bool(loaded.captains[0].alive), "the second captain's ship is still on the log")


func _page_port() -> void:
	ListenLink.block_port = true
	var game = load("res://scripts/game.gd").new()
	game.defs = defs
	var err: String = game.begin_host("vesper")
	check(err == "", "host without a port still starts")
	check(str(game.mode) == "sector", "solo host reaches the helm")
	check(game.link == null, "solo host has no socket")
	check(game.sim != null and bool(game.sim.player.moored), "solo host is moored")
	var heard := false
	for row in game.sim.lines:
		if str(row.text) == ListenLink.SOLO_LINE:
			heard = true
	check(heard, "the log says flying solo")
	game.begin_new("kestrel")
	check(game.link == null, "new keel opens no port")
	check(str(game.mode) == "sector", "new keel still reaches the helm")
	check(str(game.sim.player.class_id) == "kestrel", "new keel is the chosen hull")
	var joined: String = game.begin_join("anvil", "127.0.0.1:24565")
	check(joined == ListenLink.JOIN_LINE, "join without a port stays on the slate")
	check(str(game.mode) == "menu", "a failed join is not stuck in sector")
	check(game.sim == null, "a failed join leaves no sim")
	check(game.link == null, "a failed join leaves no socket")
	ListenLink.block_port = false
	game.free()


func _listen() -> void:
	_page_port()
	var host_sim := make("vesper")
	var client_sim := make("anvil")
	client_sim.player.player_id = "captain-guest"
	var host_link := ListenLink.new()
	var client_link := ListenLink.new()
	var opened := host_link.open_host()
	check(opened == "", "the host opens a listen port")
	if opened != "":
		print(host_link.last_error)
		return
	var joined := client_link.join("127.0.0.1:24565", "anvil", "captain-guest")
	check(joined == "", "the second captain addresses the host")
	var admitted := false
	for _i in 50:
		client_link.take_client(client_sim)
		host_link.take_host(host_sim)
		if host_sim.captains.size() == 1:
			admitted = true
			break
		OS.delay_msec(20)
	check(admitted, "the second captain joins Helion Dock")
	if not admitted:
		host_link.close()
		client_link.close()
		return
	check(str(host_sim.defs.system.id) == "HC-V1-R1-S1", "the host is still Helion Dock")
	check(host_sim.captains[0].pos.distance_to(host_sim.player.pos) < 400.0, "both keels share the dock")
	var start: Vector2 = host_sim.captains[0].pos
	var host_start: Vector2 = host_sim.player.pos
	var moved := false
	var saw_shot := false
	for _i in 30:
		client_link.send_cmd("captain-guest", {
			"thrust": 1.0,
			"retro": 0.0,
			"rot": 0.0,
			"strafe": 0.0,
			"fire": false,
		})
		host_link.take_host(host_sim)
		host_sim.tick(0.05, {})
		host_link.broadcast(host_sim)
		client_link.take_client(client_sim)
		if host_sim.captains[0].pos.distance_to(start) > 40.0:
			moved = true
			break
	check(moved, "the guest keel flies on the host")
	check(host_sim.player.pos.distance_to(host_start) < 5.0, "the host keel stays put while the guest flies")
	check(str(client_sim.player.class_id) == "anvil", "the guest still flies the Barn")
	check(client_sim.player.pos.distance_to(start) > 30.0, "the guest sees their own flight")
	check(client_sim.captains.size() >= 1, "the guest sees the other captain")
	var guest: Dictionary = host_sim.captains[0]
	guest.pos = host_sim.player.pos + Vector2(200, 0)
	guest.rot = PI
	guest.fire_cd = 0.0
	for _i in 16:
		client_link.send_cmd("captain-guest", {
			"thrust": 0.0,
			"retro": 0.0,
			"rot": 0.0,
			"strafe": 0.0,
			"fire": true,
		})
		host_link.take_host(host_sim)
		host_sim.tick(0.05, {})
		host_link.broadcast(host_sim)
		client_link.take_client(client_sim)
		if client_sim.projectiles.size() > 0:
			saw_shot = true
	check(saw_shot or bool(host_sim.captains[0].get("warrant", false)), "weapons fire replicates, or the green hit lands")
	check(str(client_sim.defs.system.id) == "HC-V1-R1-S1", "both clients are in Helion Dock")
	var pirates := 0
	for actor in host_sim.actors:
		if str(actor.team) == "red_keel":
			pirates += 1
	check(pirates >= 2 and pirates <= 4, "the host dock still has the Red Keel pack")
	host_link.close()
	client_link.close()
	var quiet := make("vesper")
	var offline := 0
	for actor in quiet.actors:
		if str(actor.team) == "red_keel":
			offline += 1
	check(offline >= 2 and offline <= 4, "an offline keel is still the NPC dock")
