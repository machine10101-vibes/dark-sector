extends SceneTree

## Runs inside the exported web pack (tests/ is excluded from the preset).
## Desktop Godot loads that pack with --main-pack and executes this script.

var fails := 0


func _init() -> void:
	print("WEB EXPORT MOOR start")
	var helion: Dictionary = Serde.load_json("res://data/system.json")
	var soil: Dictionary = Serde.load_json("res://data/first_soil.json")
	var defs := {
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
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.hold_npc = true
	var ring = sim.survey_node("aegis_ring")
	var prime = sim.survey_node("aegis_prime")
	check(ring != null and prime != null, "nodes")
	check(sim.player.pos.distance_to(ring.pos) < sim.player.pos.distance_to(prime.pos), "ring is nearer")
	check(CraftOrders.launch(sim, "survey_probe") == "", "probe launches")
	check(_probe_target(sim) == "aegis_ring", "free probe takes the ring")
	check(DockBoard.take(sim, "scan") == "", "take scan")
	check(_probe_target(sim) == "aegis_prime", "slip retargets to Aegis Prime")
	sim.player.moored = false
	sim.player.pos = sim.beacon_pos + Vector2(900.0, 0.0)
	_seal(sim, "aegis_ring")
	DockBoard.pulse(sim, 0.2)
	check(DockBoard.purse(sim) == 0, "ice ring seal pays nothing")
	_seal(sim, "aegis_prime")
	DockBoard.pulse(sim, 0.2)
	check(DockBoard.purse(sim) == 0, "prime seal off the pad waits")
	sim.player.pos = sim.beacon_pos
	sim.player.moored = true
	sim.layer = ScaleFrame.BAND
	DockBoard.pulse(sim, 0.2)
	check(DockBoard.purse(sim) == 80, "pad contact pays 80")
	check(DockBoard.take(sim, "haul") == "", "haul")
	var heard := false
	for row in sim.lines:
		if str(row.text).contains("don't clear the band yet"):
			heard = true
	check(heard, "haul log names the ice ring")
	check(DockBoard.haul_line(sim).contains("hold that way"), "helm names the ice ring")
	var body = sim.planet("aegis_prime")
	var away: Vector2 = (sim.beacon_pos - body.pos).normalized()
	sim.player.moored = false
	sim.quest_flags.moor_latch = 0.0
	sim.player.pos = sim.beacon_pos
	sim.player.vel = Vector2.ZERO
	sim.player.rot = away.angle()
	sim.layer = ScaleFrame.BAND
	sim.body_id = "aegis_prime"
	sim.tick(1.0, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(int(sim.layer) == ScaleFrame.BAND, "haul thrust stays on the band")
	check(sim.player.vel.length() >= 60.0, "haul thrust leaves 0")
	check(sim.player.vel.length() <= 250.0, "haul thrust stays under the shell cap")
	sim.tick(2.0, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(int(sim.layer) == ScaleFrame.BAND, "a longer haul burn still stays on the band")
	sim.layer = ScaleFrame.BAND
	sim.body_id = "aegis_prime"
	sim.player.moored = false
	sim.player.vel = Vector2.ZERO
	sim.player.pos = ring.pos
	DockBoard.pulse(sim, 0.2)
	check(bool(sim.quest_flags.get("dock_haul_ring", false)), "ring marks the crate")
	check(DockBoard.haul_line(sim).contains("bring the crate back"), "return cue is up")
	check(DockBoard.purse(sim) == 80, "ring does not pay the haul")
	sim.player.moored = true
	sim.player.pos = sim.beacon_pos
	DockBoard.pulse(sim, 0.2)
	check(DockBoard.purse(sim) == 200, "haul on the pad pays 120")
	sim.player.moored = false
	sim.quest_flags.pad_departed = true
	sim.quest_flags.moor_latch = 0.0
	sim.layer = ScaleFrame.BAND
	sim.body_id = "aegis_prime"
	sim.player.pos = sim.beacon_pos + Vector2(958.0, 0.0)
	sim.player.vel = Vector2.ZERO
	sim.tick(0.05, {})
	check(bool(sim.player.moored) == false, "958 m does not moor")
	sim.player.pos = sim.beacon_pos + Vector2(450.0, 0.0)
	sim.player.vel = Vector2(0.0, 40.0)
	sim.tick(0.05, {"dock": true})
	check(bool(sim.player.moored), "Dock at 450 m snaps")
	sim.player.moored = false
	sim.quest_flags.pad_departed = false
	sim.quest_flags.moor_latch = 0.0
	sim.player.pos = sim.beacon_pos + Vector2(40.0, 20.0)
	sim.player.vel = Vector2.ZERO
	sim.tick(0.05, {})
	check(bool(sim.player.moored) == false, "cast-off inside the bubble stays free")
	sim.quest_flags.pad_departed = true
	sim.player.pos = sim.beacon_pos + Vector2(-160.0, 110.0)
	sim.player.vel = Vector2.ZERO
	sim.player.rot = 2.2
	sim.tick(0.05, {})
	check(bool(sim.player.moored), "under 200 m stops and moors")
	check(DockBoard.at_pad(sim), "Board is live after the snap")
	_cue_closes(defs)
	_solo_port(defs)
	if fails == 0:
		print("WEB EXPORT MOOR PASS")
	else:
		print("WEB EXPORT MOOR FAIL %d" % fails)
	quit(fails)


func _cue_closes(defs: Dictionary) -> void:
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.hold_npc = true
	check(DockBoard.take(sim, "haul") == "", "cue haul")
	var ring = sim.survey_node("aegis_ring")
	var to_ring: Vector2 = ring.pos - sim.player.pos
	var start: float = to_ring.length()
	DockBoard.forced_origin = sim.player.pos
	var marked: Vector2 = DockBoard.marker_xy(sim, ring.pos)
	var keel: Vector2 = DockBoard.marker_xy(sim, sim.player.pos)
	var cue: Vector2 = marked - keel
	check(cue.normalized().dot(to_ring.normalized()) > 0.99, "the glass marker uses the ring bearing")
	DockBoard.forced_origin = null
	sim.player.moored = false
	sim.quest_flags.moor_latch = 0.0
	sim.player.vel = Vector2.ZERO
	sim.player.rot = to_ring.angle()
	sim.layer = ScaleFrame.BAND
	sim.body_id = "aegis_prime"
	sim.tick(1.2, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false})
	check(sim.player.pos.distance_to(ring.pos) < start - 40.0, "the cue bearing closes the range")
	check(int(sim.layer) == ScaleFrame.BAND, "the cue bearing stays on the band")
	check(sim.player.vel.length() >= 60.0, "the cue bearing still leaves 0")


func _solo_port(defs: Dictionary) -> void:
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
	var joined: String = game.begin_join("anvil", "127.0.0.1:24565")
	check(joined == ListenLink.JOIN_LINE, "join without a port stays on the slate")
	check(str(game.mode) == "menu", "a failed join is not stuck in sector")
	check(game.sim == null, "a failed join leaves no sim")
	ListenLink.block_port = false
	game.free()


func _seal(sim, node_id: String) -> void:
	for layer_name in CraftOrders.LAYERS:
		sim.reveal_layer(node_id, layer_name)


func _probe_target(sim) -> String:
	for craft in sim.craft:
		if str(craft.def_id) == "survey_probe" and str(craft.state) != "docked":
			return str(craft.target)
	return ""


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)
