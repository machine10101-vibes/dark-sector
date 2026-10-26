extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("WRECK WARRANT PASS")
	else:
		print("WRECK WARRANT FAIL %d" % fails)
	quit(fails)
	return true


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func _first(sim, team: String) -> Dictionary:
	for actor in sim.actors:
		if str(actor.team) == team and bool(actor.alive):
			return actor
	return {}


func _heard(sim, needle: String) -> bool:
	for raw in sim.lines:
		var line: Dictionary = raw
		if str(line.text).find(needle) >= 0:
			return true
	return false


func _break(sim, unit: Dictionary, attacker: String) -> void:
	unit.pos = Vector2(50000, 50000)
	unit.vel = Vector2.ZERO
	unit.hp = 1.0
	unit.shield = 0.0
	unit.armor_hp = 0.0
	unit.ai.fired_on_captain = false
	sim.damage_unit(unit, 40.0, attacker)


func _run() -> void:
	var defs := Catalog.boot()
	var sim := SectorSim.new(defs)
	sim.new_game("vesper")
	sim.hold_npc = true
	var pirate := _first(sim, "red_keel")
	var patrol := _first(sim, "helion_compact")
	check(not pirate.is_empty() and not patrol.is_empty(), "Helion still has a skiff and a cutter")
	if pirate.is_empty():
		return
	var ship_name := str(pirate.name)
	var role := str(pirate.ai.role)
	var rows: Array = DockBoard.wanted(sim)
	var listed := false
	var cutter_listed := false
	for raw in rows:
		var row: Dictionary = raw
		if str(row.id) == str(pirate.agent_id):
			listed = int(row.bounty) == 24 and str(row.role) == role and str(row.name) == ship_name
		if str(row.id) == str(patrol.agent_id):
			cutter_listed = true
	check(listed, "the board posts the skiff, the job, and 24 GRT")
	check(not cutter_listed, "a Compact cutter is not a warrant")
	check(DockBoard.mark_warrant(sim, str(patrol.agent_id)) != "", "marking the cutter refuses")
	check(DockBoard.mark_warrant(sim, str(pirate.agent_id)) == "", "Mark files the skiff warrant")
	check(_heard(sim, "Warrant on %s. Bounty 24." % ship_name), "the helm names the warrant")
	check(str(sim.player.order.get("label", "")) == "Warrant %s" % ship_name, "the order keeps the warrant label")
	check(str(sim.player.order.get("target", "")) == str(pirate.agent_id), "the warrant flies that skiff")
	var stats: Dictionary = Fit.stats(sim.defs, sim.player)
	HelmCombat.steer(sim, sim.player, {}, stats)
	check(str(sim.player.order.get("kind", "")) == "approach", "a moored warrant stays on the helm")
	HelmCombat.steer(sim, sim.player, {"thrust": 1.0}, stats)
	check(sim.player.order.is_empty(), "the stick clears a warrant")
	sim.player.moored = true
	sim.player.order = {"kind": "approach", "target": str(pirate.agent_id), "label": "the pack"}
	HelmCombat.steer(sim, sim.player, {}, stats)
	check(sim.player.order.is_empty(), "a plain approach still drops while moored")
	var purse0 := DockBoard.purse(sim)
	_break(sim, pirate, "agent:captain")
	check(DockBoard.purse(sim) == purse0 + 24, "the warrant still pays 24 when the skiff breaks")
	var still := false
	for raw in DockBoard.wanted(sim):
		var row: Dictionary = raw
		if str(row.id) == str(pirate.agent_id):
			still = true
	check(not still, "a broken skiff leaves the board")
	var wreck: Dictionary = sim.wrecks[sim.wrecks.size() - 1]
	sim.player.pos = wreck.pos + Vector2(90, 0)
	sim.player.order = {"kind": "approach", "target": str(wreck.id)}
	var caption: String = sim.wreck_caption(wreck)
	var expect := "WRECK  %s  ·  90 m  ·  scrap ×1, Hull plate ×1  ·  strip keel salvage and scrap" % ship_name
	check(caption == expect, "the wreck names the hold and the strip (%s)" % caption)
	check(sim.ordered_wreck() != null, "an approach on the wreck selects it")
	check(int(wreck.cargo.get("scrap", 0)) == 1 and int(wreck.cargo.get("hull_plate", 0)) == 1, "reading the wreck does not take the hold")
	check(not bool(wreck.get("stripped", false)), "reading the wreck does not strip it")
	var other := _first(sim, "red_keel")
	other.cargo = {}
	var other_name := str(other.name)
	_break(sim, other, "agent:captain")
	var bare: Dictionary = sim.wrecks[sim.wrecks.size() - 1]
	sim.player.pos = bare.pos + Vector2(40, 0)
	var bare_line: String = sim.wreck_caption(bare)
	check(bare_line == "WRECK  %s  ·  40 m  ·  hold empty  ·  strip keel salvage" % other_name, "an empty wreck still names keel salvage (%s)" % bare_line)
	var barn := SectorSim.new(defs)
	barn.new_game("anvil")
	barn.hold_npc = true
	barn.quest_flags.purse = 10
	var hull := barn._blank_ship("anvil", "Lost Barn", "agent:civilian:lost", "npc", "civilian")
	hull.cargo = {"ice_spall": 3}
	hull.pos = Vector2(60000, 60000)
	barn._kill(hull, "captain")
	var lost: Dictionary = barn.wrecks[barn.wrecks.size() - 1]
	barn.player.pos = lost.pos + Vector2(40, 0)
	var ice_line: String = barn.wreck_caption(lost)
	check(ice_line.find("Ice spall ×3") >= 0 and ice_line.find("strip keel salvage and Ice spall") >= 0, "a civilian wreck names the ice (%s)" % ice_line)
	check(DockBoard.purse(barn) == 10, "a civilian wreck still pays no bounty")
	var stage: Node = load("res://world/stage3d.gd").new()
	root.add_child(stage)
	var skiff := Node3D.new()
	stage.call("_fill_ship", skiff, "skiff", [], [], [], "interceptor")
	check(skiff.get_node_or_null("BountyPlate") != null and skiff.get_node_or_null("BountyLamp") != null, "a skiff wears a bounty plate and lamp")
	check(skiff.get_node_or_null("PostSpike") != null, "the interceptor spike stays on the skiff")
	var cutter := Node3D.new()
	stage.call("_fill_ship", cutter, "cutter", [], [], [], "range")
	check(cutter.get_node_or_null("BountyLamp") == null and cutter.get_node_or_null("RangeRail") != null, "a cutter keeps the range rail and no bounty lamp")
