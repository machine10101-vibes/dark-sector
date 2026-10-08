extends SceneTree

const Steer = preload("res://world/helm_steer.gd")

var fails := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node = root.get_node("/root/Game")
	game.begin_new("vesper")
	game.mode = "sector"
	var sim = game.sim
	var away: Vector2 = sim.beacon_pos + Vector2(1400.0, 900.0)
	sim.player.pos = away
	sim.player.dock_x = away.x
	sim.player.dock_y = away.y
	sim.player.vel = Vector2.ZERO
	sim.player.moored = false
	sim.quest_flags.moor_latch = 0.0
	sim.quest_flags.pad_departed = false
	var view: Node = load("res://world/sector_view.gd").new()
	game.text_entry = true
	game.cast_pulse = 0.8
	game.flight = {"thrust": 1.0, "retro": 0.0, "rot": 1.0, "strafe": 1.0, "fire": true}
	sim.player.fire_cd = 0.0
	game.tap("hail", true)
	var pos_before: Vector2 = sim.player.pos
	var shots_before: int = sim.projectiles.size()
	var cmd: Dictionary = view._cmd(0.2)
	check(float(cmd.thrust) == 0.0 and bool(cmd.fire) == false, "a text field drops thrust and the gun")
	check(bool(cmd.get("hail", false)), "a button still lands while the field is open")
	check(float(game.cast_pulse) == 0.0, "cast-off thrust does not keep running while typing")
	sim.tick(0.2, cmd)
	check(sim.player.pos.distance_to(pos_before) < 1.0, "typing does not fly the keel")
	check(sim.projectiles.size() == shots_before, "typing does not fire")
	game.text_entry = false
	game.clear_flight()

	var pad: Node = load("res://ui/flight_pad.gd").new()
	root.add_child(pad)
	await process_frame
	pad.visible = true
	pad.set("knob", Vector2(0.0, -40.0))
	pad.set("joy_touch", -1)
	pad._process(0.016)
	check(float(game.flight.get("thrust", 0.0)) > 0.5, "a pushed stick writes thrust")
	pad.visible = false
	pad._process(0.016)
	check(float(game.flight.get("thrust", 1.0)) == 0.0, "hiding the stick drops thrust")
	check(bool(game.flight.get("fire", true)) == false, "hiding the stick drops the gun")
	check((pad.get("knob") as Vector2).length() < 0.1, "hiding the stick centers the knob")
	pad.visible = true
	pad._process(0.016)
	check(float(game.flight.get("thrust", 1.0)) == 0.0, "showing the stick again does not resume the old shove")
	pad.set("knob", Vector2(0.0, -36.0))
	pad.set("joy_touch", 0)
	pad._process(0.016)
	check(float(game.flight.get("thrust", 0.0)) > 0.4, "a live touch still thrusts")
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.index = 0
	up.position = Vector2(20.0, 20.0)
	pad._input(up)
	check((pad.get("knob") as Vector2).length() < 0.1, "a touch release outside the stick centers it")
	pad.release()
	check(float(game.flight.get("thrust", 1.0)) == 0.0 and bool(game.flight.get("fire", true)) == false, "release drops the stick and the gun")

	game.clear_flight()
	sim.player.rot = 0.0
	sim.player.vel = Vector2.ZERO
	game.note_flight_key(KEY_Q, true)
	var qcmd: Dictionary = view._cmd(0.05)
	sim.tick(0.35, qcmd)
	check(sim.player.vel.y > 8.0, "Q steps to port, left of the nose")
	game.clear_flight_keys()
	sim.player.vel = Vector2.ZERO
	game.flight = {"thrust": 0.0, "retro": 0.0, "rot": 0.0, "strafe": -1.0, "fire": false}
	sim.tick(0.35, view._cmd(0.35))
	check(sim.player.vel.y > 8.0, "Port matches Q")
	game.clear_flight()
	sim.player.vel = Vector2.ZERO
	game.note_flight_key(KEY_E, true)
	sim.tick(0.35, view._cmd(0.35))
	check(sim.player.vel.y < -8.0, "E steps to starboard")
	game.clear_flight_keys()
	game.clear_flight()

	sim.player.moored = true
	sim.player.vel = Vector2.ZERO
	sim.tick(0.2, {"thrust": 0.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false, "boost": true})
	check(bool(sim.player.moored), "boost does not cast off")
	sim.player.moored = false
	sim.player.pos = away
	sim.player.vel = Vector2.ZERO
	sim.player.rot = 0.0
	sim.tick(1.0, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false, "boost": false})
	var cruise: float = sim.player.vel.length()
	sim.player.pos = away
	sim.player.vel = Vector2.ZERO
	sim.player.rot = 0.0
	sim.tick(1.0, {"thrust": 1.0, "retro": 0.0, "rot": 0.0, "strafe": 0.0, "fire": false, "boost": true})
	var boosted: float = sim.player.vel.length()
	check(boosted > cruise * 1.45, "boost runs well ahead of cruise")
	check(boosted <= Fit.VMAX * 2.0 + 1.0, "boost tops out at twice hull speed")
	check(boosted > Fit.VMAX * 0.9, "boost reaches the doubled hull speed")
	var helm_main: Node = load("res://scripts/main.gd").new()
	check(helm_main._is_flight_key(KEY_SHIFT), "Shift is a flight key")
	game.note_flight_key(KEY_SHIFT, true)
	var boost_cmd: Dictionary = view._cmd(0.05)
	check(bool(boost_cmd.get("boost", false)), "Shift is boost")
	game.clear_flight_keys()
	game.text_entry = true
	var typed: Dictionary = view._cmd(0.05)
	check(bool(typed.get("boost", false)) == false, "typing does not boost")
	game.text_entry = false
	var yaw0 := float(game.cam_yaw)
	var pitch0 := float(game.cam_pitch)
	game.cam_mode = "chase"
	game.look_cam(24.0, 10.0)
	check(str(game.cam_mode) == "orbit", "look drag takes orbit")
	check(float(game.cam_yaw) != yaw0, "look drag turns the yaw")
	check(float(game.cam_pitch) != pitch0, "look drag tips the pitch")
	check(Steer.gesture(Vector2.ZERO, Vector2(12, 0), false, true, false) == "look", "a click-drag on empty sky is a look")

	var boat := str(CraftOrders.launch(sim, ""))
	check(boat.contains("no boat"), "Boat on an empty rack says so")
	var probe := str(CraftOrders.launch(sim, "survey_probe"))
	check(probe == "", "Probe still launches from the rack")
	var out := false
	for item in sim.craft:
		if str(item.def_id) == "survey_probe" and str(item.state) != "docked":
			out = true
	check(out, "the probe leaves the rack")

	if fails == 0:
		print("HELM CONTROLS PASS")
	else:
		print("HELM CONTROLS FAIL %d" % fails)
	quit(fails)


func check(ok: bool, label: String) -> void:
	if ok:
		print("ok: %s" % label)
	else:
		fails += 1
		print("FAIL: %s" % label)
