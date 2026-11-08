extends SceneTree

var fails := 0
var phase := 0


func _process(_delta: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	_run()
	if fails == 0:
		print("OVERVIEW SLATE PASS")
	else:
		print("OVERVIEW SLATE FAIL %d" % fails)
	quit(fails)
	return true


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func _row(glass, sim, agent_id: String) -> Dictionary:
	sim.player.pos = Vector2.ZERO
	for actor in sim.actors:
		if str(actor.agent_id) == agent_id:
			sim.player.pos = actor.pos + Vector2(200, 0)
			break
	for raw in glass._contacts(sim):
		var row: Dictionary = raw
		if str(row.id) == agent_id:
			return row
	return {}


func _run() -> void:
	var defs := Catalog.boot()
	var glass = load("res://ui/helm_overlay.gd").new()
	var home := SectorSim.new(defs)
	home.new_game("vesper")
	home.hold_npc = true
	var skiff: Dictionary = {}
	var cutter: Dictionary = {}
	var hauler: Dictionary = {}
	for actor in home.actors:
		if str(actor.team) == "red_keel" and str(actor.class_id) == "skiff" and skiff.is_empty():
			skiff = actor
		elif str(actor.team) == "helion_compact" and cutter.is_empty():
			cutter = actor
		elif str(actor.team) == "civilian" and hauler.is_empty():
			hauler = actor
	check(not skiff.is_empty() and not cutter.is_empty() and not hauler.is_empty(), "Helion has a skiff, a cutter, and a hauler")
	if skiff.is_empty():
		return
	var skiff_row := _row(glass, home, str(skiff.agent_id))
	check(str(skiff_row.hull) == "Skiff" and int(skiff_row.bounty) == 24 and str(skiff_row.word) == "hostile", "a skiff contact keeps the hull and the 24 GRT bounty")
	check(glass.contact_tag(skiff_row, {}) == "Skiff 24", "the contacts row reads Skiff 24")
	check(glass.contact_tag(skiff_row, {"target": str(skiff.agent_id), "kind": "approach"}) == "approach", "a live order keeps its word")
	skiff_row.locking = true
	skiff_row.word = "locking"
	check(glass.contact_tag(skiff_row, {}) == "locking", "a lock warning keeps its word")
	var law_row := _row(glass, home, str(cutter.agent_id))
	check(str(law_row.hull) == "Cutter" and int(law_row.bounty) == 0 and str(law_row.word) == "law", "a cutter contact stays law")
	check(glass.contact_tag(law_row, {}) == "law", "the contacts row does not rename the law")
	var haul_row := _row(glass, home, str(hauler.agent_id))
	check(str(haul_row.word) == "neutral" and str(haul_row.hull) != "" and int(haul_row.bounty) == 0, "a hauler contact is a neutral hull")
	check(glass.contact_tag(haul_row, {}) == str(haul_row.hull), "the contacts row names the hauler hull (%s)" % glass.contact_tag(haul_row, {}))
	var guest := SectorSim.new(defs)
	guest.new_game("vesper")
	guest._arrive("HC-V1-R3-S3", "")
	guest.hold_npc = true
	var chase: Dictionary = {}
	for actor in guest.actors:
		if str(actor.team) == "red_keel" and str(actor.ai.role) == "interceptor":
			chase = actor
	var chase_row := _row(glass, guest, str(chase.agent_id))
	check(str(chase_row.hull) == "Pinnace" and glass.contact_tag(chase_row, {}) == "Pinnace 40", "Guest Lamp's interceptor reads Pinnace 40")
	var choir := SectorSim.new(defs)
	choir.new_game("vesper")
	choir._arrive("HC-V1-R2-S3", "")
	choir.hold_npc = true
	var saw_ketch := false
	var saw_yawl := false
	for actor in choir.actors:
		if str(actor.team) != "red_keel":
			continue
		var posted := _row(glass, choir, str(actor.agent_id))
		if str(actor.class_id) == "ketch":
			saw_ketch = glass.contact_tag(posted, {}) == "Ketch 52"
		elif str(actor.class_id) == "yawl":
			saw_yawl = glass.contact_tag(posted, {}) == "Yawl 36"
	check(saw_ketch and saw_yawl, "Ore Choir lists the ketch and the yawl before a lock")
	skiff.vel = Vector2(40, 0)
	home.player.vel = Vector2.ZERO
	var closing := _row(glass, home, str(skiff.agent_id))
	check(float(closing.get("radial", 0.0)) < -8.0, "the contacts row stores a closing radial")
	check(glass.radial_color(-40.0).r > glass.radial_color(40.0).r, "a close paints warmer than an open")
	check(glass.contact_tag(closing, {}) == "Skiff 24", "radial leaves the hull tag alone")
	var hostile_row := {"wreck": false, "locking": false, "word": "hostile", "bounty": 24}
	var calm_row := {"wreck": false, "locking": false, "word": "neutral", "bounty": 0}
	var wrecked_row := {"wreck": true, "locking": false, "word": "wreck", "bounty": 0}
	check(glass.keep_contact(hostile_row) and glass.keep_contact(calm_row) and glass.keep_contact(wrecked_row), "the overview starts on every contact")
	check(glass.cycle_overview() == "hostile" and glass.overview_title() == "HOSTILE", "the header steps to hostiles")
	check(glass.keep_contact(hostile_row) and not glass.keep_contact(calm_row) and not glass.keep_contact(wrecked_row), "hostile hides the hauler and the wreck")
	check(glass.cycle_overview() == "wreck" and glass.keep_contact(wrecked_row) and not glass.keep_contact(hostile_row), "wrecks keeps the wreck")
	check(glass.cycle_overview() == "neutral" and glass.keep_contact(calm_row) and not glass.keep_contact(hostile_row), "neutral keeps the hauler")
	check(glass.cycle_overview() == "all" and glass.overview_title() == "CONTACTS", "the header returns to every contact")
	home.player.pos = skiff.pos + Vector2(40, 0)
	skiff.pos = Vector2(50000, 50000)
	skiff.hp = 1.0
	skiff.shield = 0.0
	skiff.armor_hp = 0.0
	home.damage_unit(skiff, 80.0, "agent:captain")
	var wreck: Dictionary = home.wrecks[home.wrecks.size() - 1]
	home.player.pos = wreck.pos + Vector2(80, 0)
	var wreck_row: Dictionary = {}
	for raw in glass._contacts(home):
		var row: Dictionary = raw
		if bool(row.wreck) and str(row.id) == str(wreck.id):
			wreck_row = row
	check(not wreck_row.is_empty() and glass.contact_tag(wreck_row, {}) == "wreck", "a wreck stays a wreck on the contacts list")
