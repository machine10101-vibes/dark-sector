extends SceneTree

## The sector chart has every named system, and the corner map fits the helm.

const Atlas = preload("res://ui/chart_atlas.gd")

var fails := 0
var phase := 0
var hud: Node
var size_i := 0
var waits := 0
var volume_wait := 0
var sizes: Array = [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1116, 1941)]


func _process(_dt: float) -> bool:
	phase += 1
	if phase == 1:
		_atlas()
		_quiet_helm()
		return false
	if hud == null:
		hud = load("res://ui/hud.gd").new()
		root.add_child(hud)
		return false
	if size_i >= sizes.size():
		if volume_wait == 0:
			_open_volume()
			volume_wait = 1
			return false
		if volume_wait < 4:
			volume_wait += 1
			return false
		_check_volume()
		_finish()
		return true
	var want: Vector2i = sizes[size_i]
	if root.size != want:
		root.size = want
		waits = 0
		return false
	var screen := root.get_viewport().get_visible_rect().size
	if screen != Vector2(want):
		waits += 1
		if waits < 12:
			return false
	_check_helm(screen)
	size_i += 1
	waits = 0
	return false


func _atlas() -> void:
	var defs: Dictionary = Catalog.boot()
	var atlas: Dictionary = Atlas.build(defs)
	var systems: Array = atlas.get("systems", [])
	check(systems.size() == 48, "atlas has 48 systems (%d)" % systems.size())
	var ids: Dictionary = {}
	var min_d := 1.0e9
	var helion := false
	for i in systems.size():
		var row: Dictionary = systems[i]
		var sid := str(row.get("id", ""))
		ids[sid] = true
		var at: Vector2 = row.get("pos", Vector2.ZERO)
		if sid == "HC-V1-R1-S1":
			helion = true
			check(str(row.get("name", "")) == "Helion Dock", "Helion Dock keeps its name")
			check(str(row.get("region", "")) == "R1", "Helion Dock sits in R1")
			check(at.length() < 0.05, "Helion Dock is on the Compact Core center")
		for j in range(i + 1, systems.size()):
			var other: Dictionary = systems[j]
			var there: Vector2 = other.get("pos", Vector2.ZERO)
			min_d = minf(min_d, at.distance_to(there))
	check(helion, "Helion Dock is on the chart")
	check(min_d > 0.3, "systems stay apart (%.3f)" % min_d)
	var lanes: Array = atlas.get("lanes", [])
	check(lanes.size() > 8, "lanes are on the chart (%d)" % lanes.size())
	var missing := 0
	for raw in lanes:
		var lane: Dictionary = raw
		if ids.has(str(lane.get("from", ""))) == false or ids.has(str(lane.get("to", ""))) == false:
			missing += 1
	check(missing == 0, "every lane ends on a named system")
	var hops: Array = Atlas.links(atlas, "HC-V1-R1-S1")
	var hop_ids: Dictionary = {}
	for raw_hop in hops:
		var hop: Dictionary = raw_hop
		hop_ids[str(hop.get("id", ""))] = true
	check(hop_ids.has("HC-V1-R1-S2"), "Helion lane reaches Brass Lantern")
	check(hop_ids.has("HC-V1-R1-S3"), "Helion lane reaches Writ")
	var regions: Array = atlas.get("regions", [])
	check(regions.size() == 8, "eight regions (%d)" % regions.size())


func _open_volume() -> void:
	var game = root.get_node("/root/Game")
	game.begin_new("vesper")
	game.mode = "sector"
	game.set_map_open(true)
	root.size = Vector2i(1280, 720)


func _check_volume() -> void:
	var chart: Control = hud.get("space_map")
	if chart == null:
		_bad("3D chart missing")
		return
	check(chart.visible, "the 3D chart fills the glass")
	var view = chart.get("vp")
	var eye = chart.get("cam")
	var stage = chart.get("stage")
	check(view is SubViewport, "the chart has its own 3D viewport")
	if view is SubViewport:
		check(bool((view as SubViewport).own_world_3d), "the chart world is its own sky")
	check(eye is Camera3D, "the chart has a camera")
	if stage != null and stage.has_method("system_count"):
		check(int(stage.system_count()) == 48, "the 3D chart plants every system (%d)" % int(stage.system_count()))
		check(int(stage.lane_count()) > 8, "the 3D chart draws the lanes (%d)" % int(stage.lane_count()))
	else:
		_bad("the 3D chart stage is missing")
	check(str(chart.get("selected")) != "", "the chart marks the system you are in")


func _quiet_helm() -> void:
	var game = root.get_node("/root/Game")
	game.map_open = true
	game.note_flight_key(KEY_W, true)
	check(game.flight_down(KEY_W) == false, "an open chart quiets the helm")
	game.map_open = false
	check(game.flight_down(KEY_W), "the helm key returns when the chart closes")
	game.clear_flight_keys()
	game.note_flight_key(KEY_A, true)
	game.set_map_open(true)
	check(game.map_open, "the chart opens")
	check(game.key_down.is_empty(), "opening the chart drops held keys")
	game.set_map_open(false)


func _check_helm(screen: Vector2) -> void:
	var touch := screen.x < 900.0 or screen.y > screen.x
	hud.set("touch_on", touch)
	hud.set("touch_chosen", true)
	hud._fit()
	var tag := "%dx%d" % [int(screen.x), int(screen.y)]
	var mini: Control = hud.get("minimap")
	var chart: Control = hud.get("space_map")
	if mini == null or chart == null:
		_bad(tag + " map missing")
		return
	check(chart.visible == false, tag + " chart starts closed")
	var expect := screen.y >= 520.0
	if expect:
		check(mini.visible, tag + " minimap visible")
	if mini.visible == false:
		return
	_inside(mini, screen, tag + " minimap")
	_apart(mini, hud.get("status_card"), tag + " minimap/status")
	_apart(mini, hud.get("primary_bar"), tag + " minimap/primary")
	_apart(mini, hud.get("hold_button"), tag + " minimap/hold")
	_apart(mini, hud.get("stick_button"), tag + " minimap/stick")
	_apart(mini, hud.get("action_scroll"), tag + " minimap/actions")
	if touch:
		var pad: Node = hud.get("pad")
		if pad != null:
			_apart(mini, pad.get("joy"), tag + " minimap/joy")
			_apart(mini, pad.get("fire_button"), tag + " minimap/gun")
	if mini.size.x < 72.0 or mini.size.y < 72.0:
		_bad(tag + " minimap small %s" % mini.size)


func _inside(node: Control, screen: Vector2, tag: String) -> void:
	var rect := node.get_global_rect()
	var bounds := Rect2(Vector2(-2, -2), screen + Vector2(4, 4))
	if bounds.encloses(rect) == false:
		_bad("%s off screen %s" % [tag, rect])


func _apart(a: Control, b: Node, tag: String) -> void:
	var other := b as Control
	if a == null or other == null or a.visible == false or other.visible == false:
		return
	if a.get_global_rect().grow(-1).intersects(other.get_global_rect()):
		_bad("%s overlap %s vs %s" % [tag, a.get_global_rect(), other.get_global_rect()])


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		_bad(message)


func _bad(message: String) -> void:
	fails += 1
	print("FAIL: ", message)


func _finish() -> void:
	if fails == 0:
		print("NAV PASS")
	else:
		print("NAV FAIL %d" % fails)
	quit(fails)
