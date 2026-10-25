extends Control

## The combat glass over the helm: brackets in space, the tank capsule, the
## overview, the target card, and the objective tracker. It reads the sim and
## sends lock and order verbs; the host decides what they do.

const Steer = preload("res://world/helm_steer.gd")

const SHIELD_C := Color("6fc8ff")
const ARMOR_C := Color("e8b36a")
const HULL_C := Color("f07a6a")
const CAP_C := Color("ffe28a")
const HOT_C := Color("ff7a3c")
const QUEST_C := Color("ffd27a")
const WARN_C := Color("ff6a5c")
const RING_SENSOR := Color(0.45, 0.82, 0.9, 0.28)
const RING_OPT := Color(0.45, 0.92, 0.62, 0.42)
const RING_FALL := Color(0.95, 0.72, 0.28, 0.36)
const DIM := Color(0.55, 0.7, 0.76, 0.22)
const ORBIT_RANGES := [220.0, 320.0, 450.0]
const KEEP_RANGES := [450.0, 650.0, 900.0]

var hud: Node
var capsule: Control
var overview: Control
var card: Control
var tracker: Control
var warn: Control
var order_row: HBoxContainer
var order_buttons: Dictionary = {}
var _brackets: Array = []
var _rows: Array = []
var _orbit_pick := 1
var _keep_pick := 0
var _font: Font
var strike_box: PanelContainer
var strike_list: VBoxContainer
var _lmb: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	capsule = _Pane.new(self, "_draw_capsule")
	capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(capsule)
	tracker = _Pane.new(self, "_draw_tracker")
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tracker)
	warn = _Pane.new(self, "_draw_warn")
	warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warn.z_index = 8
	add_child(warn)
	overview = _Pane.new(self, "_draw_overview")
	overview.mouse_filter = Control.MOUSE_FILTER_STOP
	overview.gui_input.connect(_overview_input)
	add_child(overview)
	card = _Pane.new(self, "_draw_card")
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	order_row = HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 6)
	order_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(order_row)
	for spec in [["approach", "Approach"], ["orbit", "Orbit"], ["keep", "Keep"], ["engage", "Engage"], ["stop", "Stop"], ["unlock", "✕"]]:
		var button := ThemeKit.button(str(spec[1]), false)
		button.custom_minimum_size = Vector2(0, 30)
		button.add_theme_font_size_override("font_size", 12)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_press_order.bind(str(spec[0])))
		order_row.add_child(button)
		order_buttons[str(spec[0])] = button
	strike_box = PanelContainer.new()
	strike_box.visible = false
	strike_box.mouse_filter = Control.MOUSE_FILTER_STOP
	strike_box.z_index = 40
	strike_box.add_theme_stylebox_override("panel", ThemeKit.glass(true))
	add_child(strike_box)
	strike_list = VBoxContainer.new()
	strike_list.add_theme_constant_override("separation", 3)
	strike_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strike_box.add_child(strike_list)


func _process(_delta: float) -> void:
	var live := Game.mode == "sector" and Game.sim != null and hud != null
	visible = live
	mouse_filter = Control.MOUSE_FILTER_STOP if live and not Game.map_open and not Game.paused else Control.MOUSE_FILTER_IGNORE
	if not live:
		return
	_place()
	queue_redraw()
	for pane in [capsule, overview, card, tracker, warn]:
		pane.queue_redraw()


# Layout -------------------------------------------------------------------

func _chrome(name: String) -> Control:
	var node = hud.get(name)
	if node is Control and (node as Control).visible:
		return node
	return null


func _place() -> void:
	var sim = Game.sim
	var screen := get_viewport_rect().size
	size = screen
	var compact := bool(hud.get("compact"))
	var short := screen.y < 520.0
	var band := int(sim.layer) == ScaleFrame.BAND and bool(sim.player.get("alive", false))
	var primary := _chrome("primary_bar")
	var floor_y := screen.y - 8.0
	if primary != null:
		floor_y = primary.position.y - 8.0
	var status := _chrome("status_card")
	var top_y := 8.0
	if status != null:
		top_y = status.position.y + status.size.y + 8.0
	var log_card := _chrome("log_card")
	var banner := _chrome("banner")
	var left_bottom := top_y
	if banner != null:
		left_bottom = maxf(left_bottom, banner.position.y + banner.size.y + 6.0)
	if log_card != null:
		left_bottom = maxf(left_bottom, log_card.position.y + log_card.size.y + 6.0)
	var panel := _chrome("panel")
	var minimap := _chrome("minimap")
	var stick := _chrome("stick_button")

	var cap_w := 300.0
	var cap_h := 76.0
	if status != null:
		cap_w = clampf(status.size.x, 220.0, 348.0)
	capsule.visible = band and not short and floor_y - left_bottom > cap_h + 8.0
	if capsule.visible and panel != null and status != null:
		var cap_right := 10.0 + cap_w
		if cap_right > panel.position.x - 8.0 and panel.position.x < cap_right:
			capsule.visible = false
	if capsule.visible:
		capsule.size = Vector2(cap_w, cap_h)
		capsule.position = Vector2(10.0, left_bottom)
		left_bottom = capsule.position.y + cap_h + 6.0

	var right_x := screen.x - 8.0
	var col_top := 8.0
	if stick != null:
		col_top = stick.position.y + stick.size.y + 8.0
	if minimap != null:
		col_top = maxf(col_top, minimap.position.y + minimap.size.y + 8.0)
	var rows := _contacts(sim)
	var ov_w := 228.0
	var ov_h := 26.0 + 20.0 * float(clampi(rows.size(), 1, 6))
	var ov_room := floor_y - col_top
	overview.visible = band and not compact and panel == null and ov_room > 84.0
	if overview.visible:
		ov_h = minf(ov_h, ov_room)
		overview.size = Vector2(ov_w, ov_h)
		overview.position = Vector2(right_x - ov_w, col_top)

	var locked := str(sim.player.get("lock_id", "")) != ""
	var marked = HelmHarvest.marked(sim)
	card.visible = band and (locked or marked != null)
	var card_h := 108.0 if locked else 72.0
	if card.visible:
		var lo := 8.0
		if status != null:
			lo = status.position.x + status.size.x + 8.0
		var hi := screen.x - 8.0
		if minimap != null:
			hi = minf(hi, minimap.position.x - 8.0)
		elif stick != null:
			hi = minf(hi, stick.position.x - 8.0)
		if panel != null:
			hi = minf(hi, panel.position.x - 8.0)
		var card_w := minf(340.0, hi - lo)
		if card_w >= 260.0 and not compact:
			card.size = Vector2(card_w, card_h)
			card.position = Vector2(lo, 8.0)
		else:
			card_w = minf(340.0, screen.x - 16.0)
			card.size = Vector2(card_w, card_h)
			card.position = Vector2(10.0, floor_y - card_h)
			floor_y = card.position.y - 6.0
			if card.position.y < left_bottom:
				card.visible = false
		order_row.visible = locked
		order_row.position = Vector2(8.0, card_h - 36.0)
		order_row.size = Vector2(card.size.x - 16.0, 30.0)

	var objectives := objectives_of(sim)
	var tr_w := 248.0
	var tr_h := 22.0 + 32.0 * float(mini(objectives.size(), 2))
	tracker.visible = not objectives.is_empty() and not compact and floor_y - left_bottom > tr_h + 8.0
	if tracker.visible:
		tracker.size = Vector2(tr_w, tr_h)
		tracker.position = Vector2(10.0, left_bottom + 2.0)
		if panel != null and tracker.position.x + tr_w > panel.position.x:
			tracker.visible = false

	var threats := HelmCombat.lockers(sim, sim.player)
	warn.visible = band and not threats.is_empty()
	if warn.visible:
		var warn_w := minf(440.0, screen.x - 20.0)
		warn.size = Vector2(warn_w, 42.0)
		var warn_y := 8.0
		if card.visible:
			warn_y = maxf(warn_y, card.position.y + card.size.y + 6.0)
		if status != null:
			warn_y = maxf(warn_y, 8.0)
		warn.position = Vector2((screen.x - warn_w) * 0.5, warn_y)
		if minimap != null and warn.position.x + warn_w > minimap.position.x - 8.0:
			warn.position.x = maxf(10.0, minimap.position.x - warn_w - 8.0)


# Data ---------------------------------------------------------------------

func standing(sim, unit: Dictionary) -> Dictionary:
	var team := str(unit.get("team", ""))
	if team == "red_keel":
		return {"word": "hostile", "color": Color("ff6a5c")}
	if team == str(sim._pdo_id()):
		var stage := str(sim.heat_stage())
		if stage == "guns" or bool(sim.pdo_alert):
			return {"word": "hostile law", "color": Color("ff6a5c")}
		if stage == "fine" or stage == "hail":
			return {"word": "wary law", "color": Color("f0c36a")}
		return {"word": "law", "color": Color("7fd8c0")}
	if team == "civilian":
		return {"word": "neutral", "color": Color("c9d3d6")}
	if str(unit.get("controller", "")) == "human":
		if bool(unit.get("warrant", false)) or bool(unit.get("flagged", false)):
			return {"word": "flagged", "color": Color("f0a35a")}
		return {"word": "captain", "color": Color("8fc7ff")}
	return {"word": "contact", "color": Color("c9d3d6")}


func _contacts(sim) -> Array:
	var rows: Array = []
	if int(sim.layer) != ScaleFrame.BAND:
		return rows
	var stats := Fit.stats(sim.defs, sim.player)
	var self_id := str(sim.player.get("agent_id", ""))
	for row in HelmCombat.targets(sim, sim.player, float(stats.sensor) * 1.6):
		var unit: Dictionary = row.unit
		var mark := standing(sim, unit)
		var hull: Dictionary = sim.defs.ships.get(str(unit.get("class_id", "")), {})
		var locking := str(unit.get("lock_id", "")) == self_id
		var word := str(mark.word)
		if locking and bool(unit.get("lock_ok", false)):
			word = "has lock"
		elif locking:
			word = "locking"
		rows.append({
			"id": str(row.id),
			"name": str(unit.get("name", "Contact")),
			"kind": str(hull.get("class_name", unit.get("class_id", ""))),
			"dist": float(row.dist),
			"color": WARN_C if locking else mark.color,
			"word": word,
			"unit": unit,
			"wreck": false,
			"locking": locking,
		})
	for wreck in sim.wrecks:
		if bool(wreck.get("stripped", false)):
			continue
		var gap: float = sim.player.pos.distance_to(wreck.pos)
		if gap > float(stats.sensor):
			continue
		var yours := bool(wreck.get("rights", false)) or str(wreck.get("agent_id", "")) == self_id
		rows.append({
			"id": str(wreck.id),
			"name": "Wreck · %s" % str(wreck.get("name", "keel")),
			"kind": "salvage",
			"dist": gap,
			"color": Color("d7c48a") if yours else Color("a9b4b8"),
			"word": "your wreck" if yours else "wreck",
			"unit": wreck,
			"wreck": true,
			"locking": false,
		})
	rows.sort_custom(func(a, b): return float(a.dist) < float(b.dist))
	return rows


## Live objectives with a place in this system: dock slips first, then the
## shakedown mark.
func objectives_of(sim) -> Array:
	var out: Array = []
	var here := str(sim.defs.system.id)
	if here == "HC-V1-R1-S1":
		if DockBoard.state(sim, "dock_haul") == "active":
			var ring = sim.survey_node("aegis_ring")
			var back := bool(sim.quest_flags.get("dock_haul_ring", false))
			var spot: Vector2 = sim.beacon_pos if back or ring == null else ring.pos
			out.append({"title": "Crate to the ice ring  ·  pay %d" % DockBoard.HAUL_PAY, "step": "Bring the crate back" if back else "Hold toward the ice ring", "pos": spot, "label": "Helion pad" if back else "Ice ring drop"})
		elif DockBoard.state(sim, "dock_salvage") == "active":
			var cut := bool(sim.quest_flags.get("dock_salvage_cut", false))
			out.append({"title": "Tow tag at Seized Hold  ·  pay %d" % DockBoard.SALVAGE_PAY, "step": "Bring the tag to the pad" if cut else "Strip one tow tag", "pos": sim.beacon_pos if cut else sim.trash_pos, "label": "Helion pad" if cut else "Seized Hold"})
		elif DockBoard.state(sim, "dock_escort") == "active":
			var met := bool(sim.quest_flags.get("dock_escort_met", false))
			var cutter: Vector2 = DockBoard.cutter_pos(sim)
			out.append({"title": "Show the Compact the lane  ·  pay %d" % DockBoard.ESCORT_PAY, "step": "Stand the pad" if met else "Find the Compact cutter", "pos": sim.beacon_pos if met else cutter, "label": "Helion pad" if met else "Compact cutter"})
		elif DockBoard.state(sim, "dock_scan") == "active":
			var sealed: bool = sim.dossier_complete("aegis_prime")
			var body = sim.planet("aegis_prime")
			var at: Vector2 = sim.beacon_pos if sealed else (body.pos if body != null else sim.beacon_pos)
			var probe := "Probe reading Aegis Prime"
			for item in sim.craft:
				if str(item.def_id) == "survey_probe" and str(item.state) != "docked" and str(item.state) != "lost":
					probe = "Probe %s · %s" % [str(item.state), str(item.get("target", "aegis_prime"))]
			out.append({"title": "Seal Aegis Prime  ·  pay %d" % DockBoard.SCAN_PAY, "step": "Stand the pad to file it" if sealed else probe, "pos": at, "label": "Helion pad" if sealed else "Aegis Prime"})
	var focus: Dictionary = QuestBoard.focus(sim)
	var beat := str(sim.quest_flags.get("shakedown_beat", "undock"))
	if out.size() < 2 and beat != "done" and beat != "failed":
		var spot := Vector2(float(focus.get("x", 0.0)), float(focus.get("y", 0.0)))
		if spot != Vector2.ZERO and str(focus.get("kind", "")) != "keel":
			var step_line := QuestBoard.cue_line(sim)
			if str(sim.quest_flags.get("tracked_quest", "")) != "" and str(sim.quest_flags.get("tracked_quest", "")) != "authored_shakedown_01":
				step_line = QuestBoard.shakedown_line(sim)
			out.append({"title": "Shakedown  ·  %s" % beat, "step": step_line, "pos": spot, "label": str(focus.get("label", "mark"))})
	var pinned := str(sim.quest_flags.get("tracked_quest", ""))
	if pinned != "" and pinned != "authored_shakedown_01":
		var card: Dictionary = QuestBoard.guide_card(sim, pinned)
		if not card.is_empty() and bool(card.get("tracking", false)):
			var at := Vector2(float(card.get("x", 0.0)), float(card.get("y", 0.0)))
			if at != Vector2.ZERO:
				out.append({"title": "Tracking  ·  %s" % str(card.get("title", pinned)), "step": str(card.get("step", "")), "pos": at, "label": str(card.get("where", "mark"))})
	return out


func _dist_word(meters: float) -> String:
	if meters >= 10000.0:
		return "%.0f km" % (meters / 1000.0)
	if meters >= 1000.0:
		return "%.1f km" % (meters / 1000.0)
	return "%d m" % int(meters)


# Input --------------------------------------------------------------------

func _can_steer() -> bool:
	return Game.mode == "sector" and Game.sim != null and not Game.map_open and not Game.paused


func _gui_input(event: InputEvent) -> void:
	if not _can_steer():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_left(touch.position, false)
		else:
			_finish_left(touch.position)
		accept_event()
		return
	if event is InputEventScreenDrag:
		_drag_to((event as InputEventScreenDrag).position)
		accept_event()
		return
	if event is InputEventMouseMotion and bool(_lmb.get("on", false)):
		_drag_to((event as InputEventMouseMotion).position)
		accept_event()
		return
	if not (event is InputEventMouseButton):
		return
	var press := event as InputEventMouseButton
	if press.button_index == MOUSE_BUTTON_LEFT:
		if press.pressed:
			_begin_left(press.position, press.double_click)
		else:
			_finish_left(press.position)
		accept_event()
		return
	if press.button_index != MOUSE_BUTTON_RIGHT or not press.pressed:
		return
	var at := press.position
	var hit := _hit(at)
	var act := Steer.gesture(at, at, press.double_click, hit.is_empty(), true)
	if act == "engage":
		_engage_hit(hit)
	elif act == "command":
		_open_command(at)
	else:
		_open_strike(hit, at)
	accept_event()


func _input(event: InputEvent) -> void:
	if not bool(_lmb.get("on", false)):
		return
	if event is InputEventMouseMotion:
		_drag_to((event as InputEventMouseMotion).position)
		return
	if event is InputEventScreenDrag:
		_drag_to((event as InputEventScreenDrag).position)
		return
	if event is InputEventMouseButton:
		var press := event as InputEventMouseButton
		if press.button_index == MOUSE_BUTTON_LEFT and not press.pressed:
			_finish_left(press.position)
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			_finish_left(touch.position)
			if get_viewport() != null:
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_steer():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE and strike_box != null and strike_box.visible:
			_close_strike()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_4 or key == KEY_KP_4:
			Game.tap("sweep", true)
			get_viewport().set_input_as_handled()
			return
		var order := ""
		match key:
			KEY_F1:
				order = "approach"
			KEY_F2:
				order = "orbit"
			KEY_F3:
				order = "keep"
			KEY_F4:
				order = "stop"
		if order != "":
			_press_order(order)
			get_viewport().set_input_as_handled()
		return


func _begin_left(at: Vector2, double_click: bool) -> void:
	_lmb = {
		"on": true,
		"at": at,
		"now": at,
		"hit": _hit(at),
		"double": double_click,
		"drag": false,
	}


func _drag_to(at: Vector2) -> void:
	if not bool(_lmb.get("on", false)):
		return
	_lmb.now = at
	if bool(_lmb.get("drag", false)) or Steer.is_drag(_lmb.at, at):
		_lmb.drag = true
		queue_redraw()


func _overview_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var press := event as InputEventMouseButton
	if press.button_index != MOUSE_BUTTON_LEFT and press.button_index != MOUSE_BUTTON_RIGHT:
		return
	var index := int((press.position.y - 22.0) / 20.0)
	if press.position.y < 22.0 or index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	_close_strike()
	if press.button_index == MOUSE_BUTTON_RIGHT:
		var marked := {
			"id": str(row.id),
			"name": str(row.name),
			"kind": "wreck" if bool(row.wreck) else "ship",
			"wreck": bool(row.wreck),
			"pos": row.unit.pos if typeof(row.get("unit", null)) == TYPE_DICTIONARY else Vector2.ZERO,
		}
		_open_strike(marked, overview.position + press.position)
		overview.accept_event()
		return
	_pick(str(row.id), bool(row.wreck), press.double_click)
	overview.accept_event()


func _eye() -> Dictionary:
	var helm: Node = hud.get_parent().get_node_or_null("Helm") if hud != null and hud.get_parent() != null else null
	if helm == null:
		return {}
	var cam: Camera3D = helm.get("cam3")
	var stage = helm.get("stage")
	if cam == null or stage == null:
		return {}
	return {"cam": cam, "stage": stage}


func _hit(at: Vector2) -> Dictionary:
	var sim = Game.sim
	if sim == null or int(sim.layer) != ScaleFrame.BAND:
		return {}
	var eye := _eye()
	if eye.is_empty():
		return {}
	return HelmCombat.pick_mark(at, _marks(eye.cam, eye.stage, sim))


func _marks(cam: Camera3D, stage, sim) -> Array:
	var marks: Array = []
	for row in _contacts(sim):
		var unit: Dictionary = row.unit
		var world_r := 16.0
		if not bool(row.wreck):
			world_r = float(Fit.stats(sim.defs, unit).hit_radius) * 1.6
		var spot := _project(cam, stage, unit.pos, world_r, 28.0, 220.0)
		if spot.is_empty():
			continue
		marks.append({
			"id": str(row.id),
			"name": str(row.name),
			"kind": "wreck" if bool(row.wreck) else "ship",
			"wreck": bool(row.wreck),
			"pos": unit.pos,
			"range": 80.0,
			"at": spot.at,
			"rad": spot.rad,
		})
	for body in sim.planets:
		var spot := _project(cam, stage, body.pos, float(body.radius), 36.0, 4000.0)
		if spot.is_empty():
			continue
		marks.append({
			"id": str(body.id),
			"name": str(body.name),
			"kind": "planet",
			"pos": body.pos,
			"range": float(body.radius) + 160.0,
			"at": spot.at,
			"rad": spot.rad,
		})
	for gate in sim.gates:
		var row: Dictionary = gate
		var reach := float(row.get("radius", 80.0))
		var spot := _project(cam, stage, row.pos, reach, 36.0, 800.0)
		if spot.is_empty():
			continue
		marks.append({
			"id": str(row.get("id", "")),
			"name": str(row.get("name", "Lane")),
			"kind": "gate",
			"pos": row.pos,
			"range": 30.0,
			"at": spot.at,
			"rad": spot.rad,
		})
	for place in sim.nodes:
		if str(place.get("kind", "")) == "planet":
			continue
		var reach := maxf(28.0, float(place.get("radius", 40.0)))
		var spot := _project(cam, stage, place.pos, reach, 28.0, 240.0)
		if spot.is_empty():
			continue
		var row: Dictionary = place
		var ore: bool = sim.yields_material(row)
		var mark_kind := "node"
		if ore:
			mark_kind = "ore"
		marks.append({
			"id": str(place.id),
			"name": str(place.name),
			"kind": mark_kind,
			"pos": place.pos,
			"range": reach,
			"at": spot.at,
			"rad": spot.rad,
		})
	for own in _own_marks(cam, stage, sim):
		if str(own.get("id", "")) == str(sim.player.get("agent_id", "")):
			continue
		marks.append(own)
	_mark_bits(marks, cam, stage, sim, sim.asteroids, "rock", 8, 26.0)
	_mark_bits(marks, cam, stage, sim, sim.trash, "debris", 6, 34.0)
	_mark_bits(marks, cam, stage, sim, sim.meteors, "meteor", 6, 22.0)
	if sim.beacon_pos != Vector2.ZERO:
		var spot := _project(cam, stage, sim.beacon_pos, 40.0, 28.0, 80.0)
		if not spot.is_empty():
			marks.append({
				"id": "beacon",
				"name": "Helion Dock",
				"kind": "beacon",
				"pos": sim.beacon_pos,
				"range": 36.0,
				"at": spot.at,
				"rad": spot.rad,
			})
	return marks


func _project(cam: Camera3D, stage, world_pos: Vector2, world_r: float, lo: float, hi: float) -> Dictionary:
	var at3: Vector3 = stage.chart(world_pos, 2.0)
	if cam.is_position_behind(at3):
		return {}
	var sp := cam.unproject_position(at3)
	if sp.x < -80.0 or sp.y < -80.0 or sp.x > size.x + 80.0 or sp.y > size.y + 80.0:
		return {}
	var edge: Vector3 = stage.chart(world_pos + Vector2(world_r, 0.0), 2.0)
	var rad := clampf(sp.distance_to(cam.unproject_position(edge)), lo, hi)
	return {"at": sp, "rad": rad}


func _finish_left(at: Vector2) -> void:
	var started: Dictionary = _lmb.duplicate()
	_lmb = {}
	if started.is_empty():
		return
	if bool(started.get("drag", false)):
		_box_pick(started.at, at)
		return
	var hit: Dictionary = started.get("hit", {})
	if typeof(hit) != TYPE_DICTIONARY:
		hit = {}
	var act := Steer.gesture(started.at, at, bool(started.get("double", false)), hit.is_empty(), false)
	_close_strike()
	if act == "box":
		_box_pick(started.at, at)
		return
	if act == "fly":
		_fly_screen(at)
		return
	if str(hit.get("kind", "")) == "own":
		Game.picked = [str(hit.id)]
		return
	_use_hit(hit, act == "approach" or bool(started.get("double", false)))


func _use_hit(hit: Dictionary, double: bool) -> void:
	var kind := str(hit.get("kind", ""))
	if kind == "own":
		Game.picked = [str(hit.id)]
		return
	if kind == "ship" or kind == "wreck":
		_pick(str(hit.id), kind == "wreck", double)
		return
	_approach_hit(hit)


func own_bodies(sim) -> Array:
	var bodies: Array = []
	if sim == null:
		return bodies
	bodies.append({
		"id": str(sim.player.get("agent_id", "keel")),
		"name": str(sim.player.get("name", "Keel")),
		"kind": "own",
		"pos": sim.player.pos,
		"rad": float(Fit.stats(sim.defs, sim.player).hit_radius),
	})
	var index := 0
	for item in sim.craft:
		var row: Dictionary = item
		var state := str(row.get("state", ""))
		if state == "lost":
			index += 1
			continue
		var pos: Vector2 = row.pos
		if state == "docked":
			var pose: Dictionary = CraftOrders.escort_pose(sim, row, index)
			pos = pose.pos
		bodies.append({
			"id": str(row.get("uid", "")),
			"name": str(row.get("name", "Craft")),
			"kind": "own",
			"pos": pos,
			"rad": maxf(float(row.get("radius", 8.0)), 8.0),
		})
		index += 1
	return bodies


func _own_marks(cam: Camera3D, stage, sim) -> Array:
	var marks: Array = []
	if cam == null or stage == null or sim == null:
		return marks
	for raw in own_bodies(sim):
		var row: Dictionary = raw
		var lo := 16.0
		var hi := 56.0
		if str(row.get("id", "")) == str(sim.player.get("agent_id", "")):
			lo = 22.0
			hi = 90.0
		var spot := _project(cam, stage, row.pos, float(row.get("rad", 8.0)), lo, hi)
		if spot.is_empty():
			continue
		marks.append({
			"id": str(row.get("id", "")),
			"name": str(row.get("name", "Craft")),
			"kind": "own",
			"at": spot.at,
			"rad": spot.rad,
		})
	return marks


func _box_pick(start: Vector2, now: Vector2) -> void:
	var eye := _eye()
	if eye.is_empty() or Game.sim == null:
		return
	var box := Steer.box_of(start, now)
	var hits := Steer.box_hits(box, _own_marks(eye.cam, eye.stage, Game.sim))
	var ids: Array = []
	for raw in hits:
		var row: Dictionary = raw
		var id := str(row.get("id", ""))
		if id != "" and not ids.has(id):
			ids.append(id)
	Game.picked = ids
	if ids.size() > 0:
		Game.sim.say("Picked %d." % ids.size())
	else:
		Game.sim.say("No units in that box.")


func _fly_screen(at: Vector2) -> void:
	var eye := _eye()
	if eye.is_empty():
		return
	var pos: Vector2 = Steer.plane_point(eye.cam, at)
	if pos == Vector2.INF:
		return
	var ids: Array = Game.picked
	var move_keel := ids.is_empty()
	var craft_ids: Array = []
	for raw in ids:
		var id := str(raw)
		if id == str(Game.sim.player.get("agent_id", "")):
			move_keel = true
		else:
			craft_ids.append(id)
	if move_keel:
		Game.tap("order", {
			"kind": "approach",
			"x": pos.x,
			"y": pos.y,
			"range": 48.0,
			"label": "that heading",
		})
	if not craft_ids.is_empty():
		CraftOrders.hold_picked(Game.sim, craft_ids, pos)


func _approach_hit(hit: Dictionary) -> void:
	_mark_harvest(hit)
	var pos: Vector2 = hit.pos
	var spec := {
		"kind": "approach",
		"x": pos.x,
		"y": pos.y,
		"range": float(hit.get("range", 80.0)),
		"label": str(hit.get("name", "the mark")),
	}
	var node_id := str(hit.get("id", ""))
	if Game.sim != null and Game.sim.survey_node(node_id) != null:
		spec.target = node_id
	Game.tap("order", spec)


func _mark_harvest(hit: Dictionary) -> void:
	if Game.sim == null:
		return
	var kind := str(hit.get("kind", ""))
	if kind == "ore" or kind == "node" or kind == "planet":
		HelmHarvest.mark(Game.sim, str(hit.get("id", "")))
		return
	if kind == "rock" or kind == "meteor" or kind == "debris":
		var seam := _ore_near(hit.pos)
		if seam != "":
			HelmHarvest.mark(Game.sim, seam)


func _open_strike(hit: Dictionary, at: Vector2) -> void:
	_close_strike()
	var kind := str(hit.get("kind", ""))
	_strike_title(str(hit.get("name", "Target")))
	if kind == "ship" or kind == "wreck":
		_strike_button("Target", _strike_target.bind(str(hit.id), kind == "wreck"))
		if kind == "wreck":
			_strike_button("Approach", _strike_approach.bind(hit))
			_strike_button("Salvage", _strike_salvage.bind(str(hit.id)))
		if kind == "ship":
			_strike_button("Engage", _engage_hit.bind(hit))
			_strike_button("Approach", _strike_helm.bind(str(hit.id), "approach"))
			_strike_button("Orbit", _strike_helm.bind(str(hit.id), "orbit"))
			_strike_button("Keep at range", _strike_helm.bind(str(hit.id), "keep"))
			_strike_label("WEAPONS")
			for gun in _weapon_rows():
				_strike_button("Attack · %s" % str(gun.name), _strike_gun.bind(str(hit.id), str(gun.socket), str(gun.name)))
			var wing: Array = _fighter_rows()
			_strike_label("FLEET")
			if not wing.is_empty():
				for craft in wing:
					_strike_button("Attack · %s" % str(craft.name), _strike_craft.bind(str(hit.id), str(craft.uid)))
				if wing.size() > 1:
					_strike_button("Attack · the wing", _strike_wing.bind(str(hit.id)))
			_strike_button("Form on me", _fleet_verb.bind("form"))
			_strike_button("Recall the wing", _fleet_verb.bind("recall"))
	elif kind == "gate":
		_strike_button("Approach", _strike_approach.bind(hit))
		_strike_button("Take the lane", _strike_lane.bind(str(hit.id)))
	elif kind == "ore":
		_strike_button("Approach", _strike_approach.bind(hit))
		_strike_button("Scan", _strike_scan.bind(str(hit.id)))
		_strike_button("Harvest with probe", _strike_harvest.bind(str(hit.id)))
		_strike_button("Plasma cut", _strike_plasma.bind(str(hit.id)))
	elif kind == "rock" or kind == "meteor" or kind == "debris":
		_strike_button("Approach", _strike_approach.bind(hit))
		var seam := _ore_near(hit.pos)
		if seam != "":
			_strike_button("Scan", _strike_scan.bind(seam))
			_strike_button("Harvest with probe", _strike_harvest.bind(seam))
			_strike_button("Plasma cut", _strike_plasma.bind(seam))
	else:
		_strike_button("Approach", _strike_approach.bind(hit))
	_place_strike(at)


func _open_command(at: Vector2) -> void:
	_close_strike()
	var lock := ""
	if Game.sim != null:
		lock = str(Game.sim.player.get("lock_id", ""))
	_strike_title("Command")
	_strike_label("HELM")
	_strike_button("All stop", _press_order.bind("stop"))
	if lock != "":
		_strike_button("Approach the lock", _press_order.bind("approach"))
		_strike_button("Orbit the lock", _press_order.bind("orbit"))
		_strike_button("Keep at range", _press_order.bind("keep"))
		_strike_button("Engage", _engage_lock)
	_strike_label("FLEET")
	_strike_button("Form on me", _fleet_verb.bind("form"))
	if lock != "":
		_strike_button("Attack with the wing", _strike_wing.bind(lock))
	_strike_button("Recall the wing", _fleet_verb.bind("recall"))
	_strike_label("SCAN")
	_strike_button("Sensor sweep", _do_sweep)
	_place_strike(at)


func _place_strike(at: Vector2) -> void:
	var gap := float(strike_list.get_theme_constant("separation"))
	var height := 10.0
	for child in strike_list.get_children():
		var node := child as Control
		if node == null:
			continue
		height += node.get_combined_minimum_size().y + gap
	var box := Vector2(236.0, height)
	var floor_y := size.y - 8.0
	var primary := _chrome("primary_bar")
	if primary != null:
		floor_y = primary.position.y - 8.0
	var pos := at
	pos.x = clampf(pos.x, 8.0, maxf(8.0, size.x - box.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, floor_y - box.y))
	strike_box.position = pos
	strike_box.size = box
	strike_box.visible = true


func _weapon_rows() -> Array:
	var rows: Array = []
	if Game.sim == null:
		return rows
	for raw in HelmCombat.weapon_rows(Game.sim, Game.sim.player):
		var row: Dictionary = raw
		if str(row.get("family", "")) == "pd":
			continue
		rows.append(row)
	return rows


func _fighter_rows() -> Array:
	var rows: Array = []
	if Game.sim == null:
		return rows
	for item in Game.sim.craft:
		if not CraftOrders.is_attack(Game.sim, str(item.def_id)) or str(item.state) == "lost":
			continue
		rows.append(item)
	return rows


func _strike_title(text: String) -> void:
	var label := ThemeKit.label(text, 15, Color("f4fcff"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strike_list.add_child(label)


func _strike_label(text: String) -> void:
	strike_list.add_child(ThemeKit.label(text, 11, Color("7ed0dc")))


func _strike_button(text: String, call: Callable) -> void:
	var button := ThemeKit.button(text, false)
	button.custom_minimum_size = Vector2(212, 30)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(call)
	strike_list.add_child(button)


func _close_strike() -> void:
	if strike_box == null:
		return
	strike_box.visible = false
	for child in strike_list.get_children():
		strike_list.remove_child(child)
		child.queue_free()


func _strike_target(id: String, wreck: bool) -> void:
	_close_strike()
	_pick(id, wreck, false)


func _strike_gun(id: String, socket: String, gun_name: String) -> void:
	_close_strike()
	Game.tap("engage", {"socket": socket, "lock": id, "name": gun_name})


func _strike_craft(id: String, uid: String) -> void:
	_close_strike()
	if Game.sim == null:
		return
	Game.tap("lock", id)
	var message := CraftOrders.strike(Game.sim, uid, id)
	if message != "":
		Game.sim.say(message)


func _strike_wing(id: String) -> void:
	_close_strike()
	if Game.sim == null:
		return
	Game.tap("lock", id)
	var message := CraftOrders.wing_strike(Game.sim, id)
	if message != "":
		Game.sim.say(message)


func _mark_bits(marks: Array, cam: Camera3D, stage, sim, rows: Array, kind: String, cap: int, world_r: float) -> void:
	var near: Array = []
	var origin: Vector2 = sim.player.pos
	for row in rows:
		var item: Dictionary = row
		var at: Vector2 = item.pos
		var dist: float = origin.distance_to(at)
		if dist > 900.0:
			continue
		near.append({"d": dist, "row": item})
	near.sort_custom(func(a, b): return float(a.d) < float(b.d))
	var added := 0
	for entry in near:
		if added >= cap:
			break
		var bit: Dictionary = entry.row
		var reach := maxf(world_r, float(bit.get("size", world_r)))
		var spot := _project(cam, stage, bit.pos, reach, 22.0, 90.0)
		if spot.is_empty():
			continue
		var label := kind.capitalize()
		if kind == "rock":
			label = "Asteroid"
		elif kind == "meteor":
			label = "Meteor"
		elif kind == "debris":
			label = "Debris"
		marks.append({
			"id": "%s%d" % [kind, added],
			"name": label,
			"kind": kind,
			"pos": bit.pos,
			"range": reach,
			"at": spot.at,
			"rad": spot.rad,
		})
		added += 1


func _ore_near(at: Vector2) -> String:
	if Game.sim == null:
		return ""
	var best := ""
	var best_d := 280.0
	for place in Game.sim.nodes:
		var row: Dictionary = place
		var ore := Game.sim.yields_material(row)
		if not ore:
			continue
		var dist: float = at.distance_to(row.pos)
		if dist < best_d:
			best_d = dist
			best = str(row.id)
	return best


func _craft_uid(def_id: String) -> String:
	if Game.sim == null:
		return ""
	for item in Game.sim.craft:
		if str(item.def_id) == def_id and str(item.state) != "lost":
			return str(item.uid)
	return ""


func _strike_scan(node_id: String) -> void:
	_close_strike()
	if Game.sim == null:
		return
	var uid := _craft_uid("survey_probe")
	if uid == "":
		Game.sim.say("No survey probe on the rack.")
		return
	var message := CraftOrders.order(Game.sim, uid, "scan", node_id)
	if message != "":
		Game.sim.say(message)


func _strike_harvest(node_id: String) -> void:
	_close_strike()
	if Game.sim == null:
		return
	var message := HelmHarvest.send_craft(Game.sim, node_id)
	if message != "":
		Game.sim.say(message)


func _strike_plasma(node_id: String) -> void:
	_close_strike()
	Game.tap("cut", {"node": node_id})


func _strike_salvage(wreck_id: String) -> void:
	_close_strike()
	if Game.sim == null:
		return
	var message := CraftOrders.salvage(Game.sim, wreck_id)
	if message != "":
		Game.sim.say(message)


func _strike_approach(hit: Dictionary) -> void:
	_close_strike()
	_approach_hit(hit)


func _strike_lane(id: String) -> void:
	_close_strike()
	if Game.sim == null:
		return
	var gate := Game.sim.nearby_gate()
	if gate.is_empty() or str(gate.get("id", "")) != id:
		Game.sim.say("Fly into the ring, then take the lane.")
		return
	var message := Game.sim.try_lane()
	if message != "":
		Game.sim.say(message)


func _pick(id: String, wreck: bool, double: bool) -> void:
	if wreck:
		Game.tap("order", {"kind": "approach", "target": id, "range": 40.0})
		return
	Game.tap("lock", id)
	if double:
		Game.tap("order", {"kind": "approach", "target": id})


func _press_order(kind: String) -> void:
	_close_strike()
	if Game.sim == null:
		return
	var target := str(Game.sim.player.get("lock_id", ""))
	_issue_order(kind, target)


func _strike_helm(id: String, kind: String) -> void:
	_close_strike()
	Game.tap("lock", id)
	_issue_order(kind, id)


func _issue_order(kind: String, target: String) -> void:
	if Game.sim == null:
		return
	match kind:
		"unlock":
			Game.tap("lock", "")
		"stop":
			Game.tap("order", {"kind": "stop"})
		"orbit":
			var now: Dictionary = Game.sim.player.get("order", {})
			if str(now.get("kind", "")) == "orbit" and str(now.get("target", "")) == target:
				_orbit_pick = (_orbit_pick + 1) % ORBIT_RANGES.size()
			Game.tap("order", {"kind": "orbit", "target": target, "range": ORBIT_RANGES[_orbit_pick]})
		"keep":
			var held: Dictionary = Game.sim.player.get("order", {})
			if str(held.get("kind", "")) == "keep" and str(held.get("target", "")) == target:
				_keep_pick = (_keep_pick + 1) % KEEP_RANGES.size()
			Game.tap("order", {"kind": "keep", "target": target, "range": KEEP_RANGES[_keep_pick]})
		"approach":
			if target != "":
				Game.tap("order", {"kind": "approach", "target": target})
		"engage":
			_engage_id(target)


func _engage_lock() -> void:
	_close_strike()
	if Game.sim == null:
		return
	_engage_id(str(Game.sim.player.get("lock_id", "")))


func _engage_hit(hit: Dictionary) -> void:
	_close_strike()
	if str(hit.get("kind", "")) != "ship":
		return
	_engage_id(str(hit.id))


func _engage_id(id: String) -> void:
	if id == "":
		if Game.sim != null:
			Game.sim.say("Lock a ship first.")
		return
	var rows := _weapon_rows()
	var socket := "nose"
	var gun_name := "Main gun"
	if not rows.is_empty():
		socket = str(rows[0].socket)
		gun_name = str(rows[0].name)
	var armed := ""
	if Game.sim != null:
		armed = str(Game.sim.player.get("engage", ""))
	if armed != "":
		socket = armed
		for gun in rows:
			var row: Dictionary = gun
			if str(row.socket) == armed:
				gun_name = str(row.name)
	Game.tap("engage", {"socket": socket, "lock": id, "name": gun_name})


func _fleet_verb(verb: String) -> void:
	_close_strike()
	if Game.sim == null:
		return
	var message := CraftOrders.fleet(Game.sim, verb)
	if message != "":
		Game.sim.say(message)


func _do_sweep() -> void:
	_close_strike()
	Game.tap("sweep", true)


# Brackets -----------------------------------------------------------------

func _draw() -> void:
	_brackets = []
	var sim = Game.sim
	if sim == null or int(sim.layer) != ScaleFrame.BAND:
		return
	if size.x < 80.0 or size.y < 80.0:
		return
	var helm: Node = hud.get_parent().get_node_or_null("Helm") if hud != null and hud.get_parent() != null else null
	if helm == null:
		return
	var cam: Camera3D = helm.get("cam3")
	var stage = helm.get("stage")
	if cam == null or stage == null:
		return
	var lock_id := str(sim.player.get("lock_id", ""))
	_draw_rings(cam, stage, sim)
	_draw_sweep(cam, stage, sim)
	_draw_cuts(cam, stage, sim)
	_draw_mark(cam, stage, sim)
	_draw_incoming(cam, stage, sim)
	var quest_ids := {}
	for goal in objectives_of(sim):
		_draw_objective(cam, stage, sim, goal)
		if str(goal.label) == "Compact cutter":
			for actor in sim.actors:
				if str(actor.team) == str(sim._pdo_id()):
					quest_ids[str(actor.agent_id)] = true
	for row in _contacts(sim):
		var unit: Dictionary = row.unit
		var at3: Vector3 = stage.chart(unit.pos, 2.0)
		if cam.is_position_behind(at3):
			continue
		var sp := cam.unproject_position(at3)
		if sp.x < -40.0 or sp.y < -40.0 or sp.x > size.x + 40.0 or sp.y > size.y + 40.0:
			continue
		_brackets.append({"id": row.id, "at": sp, "wreck": row.wreck})
		var radius := 16.0
		if not bool(row.wreck):
			var edge3: Vector3 = stage.chart(unit.pos + Vector2(float(Fit.stats(sim.defs, unit).hit_radius) * 1.4, 0.0), 2.0)
			radius = clampf(cam.unproject_position(edge3).distance_to(sp), 12.0, 64.0)
		var col: Color = row.color
		if bool(row.wreck):
			_diamond(sp, 9.0, col, 1.5)
			_text(sp + Vector2(12, -6), "%s  %s" % [row.name, _dist_word(row.dist)], 11, Color(col, 0.85))
			continue
		var is_lock := str(row.id) == lock_id
		var weight := 2.4 if is_lock else 1.4
		_corners(sp, radius, col, weight, 0.36)
		if quest_ids.has(str(row.id)):
			_diamond(sp + Vector2(0, -radius - 10.0), 5.0, QUEST_C, 1.6)
		if bool(row.get("locking", false)):
			_corners(sp, radius + 16.0, WARN_C, 2.0, 0.22)
			draw_arc(sp, radius + 18.0, 0.0, TAU, 36, Color(WARN_C, 0.7 if bool(row.unit.get("lock_ok", false)) else 0.4), 1.6, true)
		if is_lock:
			var ok := bool(sim.player.get("lock_ok", false))
			var need := maxf(0.01, float(sim.player.get("lock_need", 1.0)))
			var frac := 1.0 if ok else clampf(float(sim.player.get("lock_t", 0.0)) / need, 0.0, 1.0)
			draw_arc(sp, radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, Color(col, 0.95), 2.0, true)
			if ok:
				_corners(sp, radius + 12.0, Color(col, 0.6), 1.2, 0.2)
		var tank_y := sp.y + radius + 6.0
		_tank_strip(Vector2(sp.x - radius, tank_y), radius * 2.0, unit)
		_text(Vector2(sp.x - radius, tank_y + 20.0), "%s · %s" % [_dist_word(row.dist), row.word], 10, Color(col.lerp(Color.WHITE, 0.35), 0.85))
	_draw_own(cam, stage, sim)
	_draw_box()


func _draw_mark(cam: Camera3D, stage, sim) -> void:
	var place = HelmHarvest.marked(sim)
	if place == null:
		return
	var at3: Vector3 = stage.chart(place.pos, 2.0)
	if cam.is_position_behind(at3):
		return
	var sp := cam.unproject_position(at3)
	if sp.x < -40.0 or sp.y < -40.0 or sp.x > size.x + 40.0 or sp.y > size.y + 40.0:
		return
	var col := Color(0.55, 0.96, 0.82, 0.95)
	_diamond(sp, 12.0, col, 2.1)
	_corners(sp, 20.0, col, 1.7, 0.3)
	var gap: float = sim.player.pos.distance_to(place.pos)
	var word := "READY" if HelmHarvest.ready(sim, place) else "SCAN"
	_text(sp + Vector2(16, -8), "%s  ·  %s  ·  %s" % [str(place.name), _dist_word(gap), word], 11, Color(col, 0.96))


func _draw_cuts(cam: Camera3D, stage, sim) -> void:
	if not sim.get("cuts"):
		return
	for raw in sim.cuts:
		var row: Dictionary = raw
		var a3: Vector3 = stage.chart(row.from, 4.0)
		var b3: Vector3 = stage.chart(row.to, 2.0)
		if cam.is_position_behind(a3) or cam.is_position_behind(b3):
			continue
		var a := cam.unproject_position(a3)
		var b := cam.unproject_position(b3)
		var fade := clampf(1.0 - float(row.get("age", 0.0)) / HelmHarvest.CUT_LIFE, 0.12, 1.0)
		var kind := str(row.get("kind", "plasma"))
		var col := Color(0.55, 0.95, 1.0, 0.9 * fade)
		if kind == "probe":
			col = Color(0.55, 0.92, 0.78, 0.88 * fade)
		elif kind == "drone":
			col = Color(1.0, 0.72, 0.32, 0.9 * fade)
		draw_line(a, b, col, 2.4 if kind == "plasma" else 1.8, true)
		draw_circle(b, 4.0 + fade * 2.0, Color(col, 0.55 * fade))


func _draw_rings(cam: Camera3D, stage, sim) -> void:
	var threats := HelmCombat.lockers(sim, sim.player)
	var armed := str(sim.player.get("lock_id", "")) != "" or str(sim.player.get("engage", "")) != ""
	if threats.is_empty() and not armed:
		return
	var bands: Dictionary = HelmCombat.range_bands(sim, sim.player)
	_world_ring(cam, stage, sim.player.pos, float(bands.sensor), RING_SENSOR, 1.2)
	_world_ring(cam, stage, sim.player.pos, float(bands.optimal), RING_OPT, 1.6)
	_world_ring(cam, stage, sim.player.pos, float(bands.falloff), RING_FALL, 1.3)


func _draw_sweep(cam: Camera3D, stage, sim) -> void:
	var pulse: Dictionary = sim.sweep
	if pulse.is_empty():
		return
	if float(sim.time) - float(pulse.get("t", -20.0)) > 6.0:
		return
	var fade := clampf(1.0 - (float(sim.time) - float(pulse.get("t", 0.0))) / 6.0, 0.15, 1.0)
	_world_ring(cam, stage, sim.player.pos, float(pulse.get("reach", 0.0)), Color(0.62, 0.94, 1.0, 0.22 * fade), 1.1)
	for raw in pulse.get("rows", []):
		var row: Dictionary = raw
		var at3: Vector3 = stage.chart(row.pos, 2.0)
		if cam.is_position_behind(at3):
			continue
		var sp := cam.unproject_position(at3)
		if sp.x < -20.0 or sp.y < -20.0 or sp.x > size.x + 20.0 or sp.y > size.y + 20.0:
			continue
		var kind := str(row.get("kind", ""))
		if kind == "ore":
			_diamond(sp, 7.0, Color(0.72, 0.9, 0.55, 0.85 * fade), 1.4)
		elif kind == "wreck":
			_diamond(sp, 8.0, Color(0.85, 0.78, 0.55, 0.9 * fade), 1.5)
		elif bool(row.get("hostile", false)):
			_corners(sp, 14.0, Color(WARN_C, 0.85 * fade), 1.8, 0.3)
		else:
			_corners(sp, 12.0, Color(0.7, 0.86, 0.9, 0.7 * fade), 1.2, 0.28)


func _draw_incoming(cam: Camera3D, stage, sim) -> void:
	var box := Rect2(Vector2(28, 28), size - Vector2(56, 56))
	var center := size * 0.5
	for raw in HelmCombat.lockers(sim, sim.player):
		var row: Dictionary = raw
		var unit: Dictionary = row.unit
		var at3: Vector3 = stage.chart(unit.pos, 2.0)
		var on_screen := not cam.is_position_behind(at3)
		var sp := cam.unproject_position(at3) if on_screen else Vector2(-1, -1)
		if on_screen and box.has_point(sp):
			continue
		var dir := (sp - center) if on_screen else Vector2.ZERO
		if dir.length() < 1.0:
			var heading: Vector2 = unit.pos - sim.player.pos
			var probe3: Vector3 = stage.chart(sim.player.pos + heading.normalized() * 50.0, 2.0)
			var self3: Vector3 = stage.chart(sim.player.pos, 2.0)
			dir = cam.unproject_position(probe3) - cam.unproject_position(self3)
			if dir.length() < 0.01:
				continue
		dir = dir.normalized()
		var reach := minf(absf((box.size.x * 0.5) / maxf(absf(dir.x), 0.001)), absf((box.size.y * 0.5) / maxf(absf(dir.y), 0.001)))
		var tip := center + dir * reach
		var side := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([tip + dir * 10.0, tip - dir * 6.0 + side * 8.0, tip - dir * 6.0 - side * 8.0]), Color(WARN_C, 0.92))
		var label := "%s  %s" % [str(row.name), _dist_word(float(row.dist))]
		var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var spot := tip - dir * 22.0 - Vector2(width * 0.5, -4.0)
		spot.x = clampf(spot.x, 8.0, size.x - width - 8.0)
		_text(spot, label, 11, WARN_C)


func _world_ring(cam: Camera3D, stage, origin: Vector2, radius: float, col: Color, width: float) -> void:
	if radius < 8.0:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	var steps := 56
	for i in steps + 1:
		var ang := TAU * float(i) / float(steps)
		var world: Vector2 = origin + Vector2.from_angle(ang) * radius
		var at3: Vector3 = stage.chart(world, 2.0)
		if cam.is_position_behind(at3):
			if pts.size() >= 2:
				draw_polyline(pts, col, width, true)
			pts = PackedVector2Array()
			continue
		var sp := cam.unproject_position(at3)
		if sp.x < -140.0 or sp.y < -140.0 or sp.x > size.x + 140.0 or sp.y > size.y + 140.0:
			if pts.size() >= 2:
				draw_polyline(pts, col, width, true)
			pts = PackedVector2Array()
			continue
		pts.append(sp)
	if pts.size() >= 2:
		draw_polyline(pts, col, width, true)


func _draw_own(cam: Camera3D, stage, sim) -> void:
	var picked: Array = Game.picked
	for mark in _own_marks(cam, stage, sim):
		var id := str(mark.get("id", ""))
		var on := picked.has(id)
		if not on and id == str(sim.player.get("agent_id", "")):
			continue
		var at: Vector2 = mark.at
		var rad := float(mark.get("rad", 16.0))
		var col := Color("7ed0dc")
		_corners(at, rad, col, 2.4 if on else 1.3, 0.34)
		if on:
			draw_arc(at, rad + 6.0, 0.0, TAU, 36, Color(col, 0.85), 1.6, true)
			_text(at + Vector2(rad + 6.0, -4.0), str(mark.get("name", "")), 11, Color(col, 0.9))


func _draw_box() -> void:
	if not bool(_lmb.get("drag", false)):
		return
	var start: Vector2 = _lmb.get("at", Vector2.ZERO)
	var now: Vector2 = _lmb.get("now", start)
	var box := Steer.box_of(start, now)
	draw_rect(box, Color(0.45, 0.88, 1.0, 0.16), true)
	draw_rect(box, Color(0.62, 0.94, 1.0, 0.95), false, 2.0)
	var eye := _eye()
	if eye.is_empty() or Game.sim == null:
		return
	for raw in Steer.box_hits(box, _own_marks(eye.cam, eye.stage, Game.sim)):
		var row: Dictionary = raw
		var at: Vector2 = row.get("at", Vector2.ZERO)
		var rad := float(row.get("rad", 16.0))
		draw_arc(at, rad + 4.0, 0.0, TAU, 28, Color(0.62, 0.94, 1.0, 0.9), 2.0, true)


func _draw_objective(cam: Camera3D, stage, sim, goal: Dictionary) -> void:
	var at3: Vector3 = stage.chart(goal.pos, 2.0)
	var gap: float = sim.player.pos.distance_to(goal.pos)
	var on_screen := not cam.is_position_behind(at3)
	var sp := cam.unproject_position(at3) if on_screen else Vector2(-1, -1)
	var box := Rect2(Vector2(28, 28), size - Vector2(56, 56))
	if on_screen and box.has_point(sp):
		_diamond(sp, 11.0, QUEST_C, 2.0)
		_diamond(sp, 4.0, Color(QUEST_C, 0.7), 0.0)
		_text(sp + Vector2(15, 4), "%s  %s" % [str(goal.label), _dist_word(gap)], 12, QUEST_C)
		return
	var center := size * 0.5
	var dir := (sp - center) if on_screen else Vector2.ZERO
	if dir.length() < 1.0:
		var heading: Vector2 = goal.pos - sim.player.pos
		var probe3: Vector3 = stage.chart(sim.player.pos + heading.normalized() * 50.0, 2.0)
		var self3: Vector3 = stage.chart(sim.player.pos, 2.0)
		dir = cam.unproject_position(probe3) - cam.unproject_position(self3)
		if dir.length() < 0.01:
			return
	dir = dir.normalized()
	var reach := minf(absf((box.size.x * 0.5) / maxf(absf(dir.x), 0.001)), absf((box.size.y * 0.5) / maxf(absf(dir.y), 0.001)))
	var tip := center + dir * reach
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([tip + dir * 10.0, tip - dir * 6.0 + side * 8.0, tip - dir * 6.0 - side * 8.0]), Color(QUEST_C, 0.9))
	var label := "%s  %s" % [str(goal.label), _dist_word(gap)]
	var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var spot := tip - dir * 22.0 - Vector2(width * 0.5, -4.0)
	spot.x = clampf(spot.x, 8.0, size.x - width - 8.0)
	_text(spot, label, 11, QUEST_C)


func _corners(c: Vector2, r: float, col: Color, w: float, arm: float) -> void:
	var a := r * arm
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p := c + Vector2(sx * r, sy * r)
			draw_line(p, p - Vector2(sx * a, 0.0), col, w, true)
			draw_line(p, p - Vector2(0.0, sy * a), col, w, true)


func _diamond(c: Vector2, r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
	if w <= 0.0:
		draw_colored_polygon(pts.slice(0, 4), col)
	else:
		draw_polyline(pts, col, w, true)


func _tank_strip(at: Vector2, width: float, unit: Dictionary) -> void:
	var rows := [
		[float(unit.get("shield", 0.0)), float(unit.get("shield_max", 0.0)), SHIELD_C],
		[float(unit.get("armor_hp", 0.0)), float(unit.get("armor_max", 0.0)), ARMOR_C],
		[float(unit.get("hp", 0.0)), float(unit.get("max_hp", 1.0)), HULL_C],
	]
	var y := at.y
	for row in rows:
		var top := float(row[1])
		if top <= 0.0:
			continue
		draw_rect(Rect2(Vector2(at.x, y), Vector2(width, 2.0)), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(Vector2(at.x, y), Vector2(width * clampf(float(row[0]) / top, 0.0, 1.0), 2.0)), row[2])
		y += 3.0


func _text(at: Vector2, text: String, font_size: int, col: Color, on: CanvasItem = null) -> void:
	var canvas: CanvasItem = self if on == null else on
	canvas.draw_string(_font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.7))
	canvas.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _text_mid(on: CanvasItem, center_x: float, y: float, text: String, font_size: int, col: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(Vector2(center_x - width * 0.5, y), text, font_size, col, on)


func _text_right(on: CanvasItem, right_x: float, y: float, text: String, font_size: int, col: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(Vector2(right_x - width, y), text, font_size, col, on)


func _plate(pane: Control, strong: bool) -> void:
	var s := pane.size
	var fill := Color(0.008, 0.028, 0.042, 0.78 if strong else 0.58)
	var edge := Color(0.5, 0.88, 0.96, 0.62 if strong else 0.4)
	var accent := Color(0.78, 0.98, 1.0, 0.95)
	pane.draw_rect(Rect2(Vector2.ZERO, s), fill)
	pane.draw_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), edge, false, 1.0)
	var arm := 9.0
	var corners: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(1, arm), Vector2(1, 1), Vector2(arm, 1)]),
		PackedVector2Array([Vector2(s.x - arm, 1), Vector2(s.x - 1, 1), Vector2(s.x - 1, arm)]),
		PackedVector2Array([Vector2(1, s.y - arm), Vector2(1, s.y - 1), Vector2(arm, s.y - 1)]),
		PackedVector2Array([Vector2(s.x - arm, s.y - 1), Vector2(s.x - 1, s.y - 1), Vector2(s.x - 1, s.y - arm)]),
	]
	for corner in corners:
		pane.draw_polyline(corner, accent, 1.5, true)


# Capsule ------------------------------------------------------------------

func _draw_capsule(pane: Control) -> void:
	var sim = Game.sim
	var p: Dictionary = sim.player
	var w := pane.size.x
	_plate(pane, true)
	var speed := int(Vector2(p.vel).length())
	var boosting := bool(p.get("boosting", false))
	_text(Vector2(10, 15), "SPD", 10, Color("7ed0dc"), pane)
	_text(Vector2(36, 16), "%d" % speed, 15, Color("ffd59a") if boosting else Color("f4fcff"), pane)
	var speed_w := _font.get_string_size("%d" % speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(Vector2(40.0 + speed_w, 15), "m/s", 10, Color("8aa8b0"), pane)
	var order: Dictionary = p.get("order", {})
	var helm_word := "MANUAL"
	var helm_col := Color("9fb7be")
	if not order.is_empty():
		helm_word = HelmCombat.order_label(sim, order).to_upper()
		helm_col = Color("9be7d0")
	if bool(p.get("moored", false)):
		helm_word = "MOORED"
	_text_right(pane, w - 10.0, 15.0, helm_word, 11, helm_col)
	var flash := clampf(1.0 - (float(sim.time) - float(p.get("hit_at", -10.0))) / 0.5, 0.0, 1.0)
	var hit_layer := str(p.get("hit_layer", ""))
	var tanks := [
		["S", float(p.get("shield", 0.0)), float(p.get("shield_max", 0.0)), SHIELD_C, "shield"],
		["A", float(p.get("armor_hp", 0.0)), float(p.get("armor_max", 0.0)), ARMOR_C, "armor"],
		["H", float(p.hp), float(p.max_hp), HULL_C, "hull"],
	]
	var gap := 8.0
	var bar_w := (w - 20.0 - gap * 2.0) / 3.0
	for i in tanks.size():
		var row: Array = tanks[i]
		var x := 10.0 + float(i) * (bar_w + gap)
		var col: Color = row[3]
		if flash > 0.0 and hit_layer == str(row[4]):
			col = col.lerp(Color.WHITE, flash * 0.7)
		_text(Vector2(x, 32), str(row[0]), 10, col, pane)
		var track_x := x + 12.0
		var track_w := bar_w - 12.0
		pane.draw_rect(Rect2(Vector2(track_x, 26), Vector2(track_w, 4)), DIM)
		var top := maxf(float(row[2]), 0.001)
		if float(row[2]) > 0.0:
			pane.draw_rect(Rect2(Vector2(track_x, 26), Vector2(track_w * clampf(float(row[1]) / top, 0.0, 1.0), 4)), col)
	var cap := float(p.get("cap", 0.0))
	var cap_max := maxf(float(p.get("cap_max", 1.0)), 1.0)
	var half := (w - 28.0) * 0.5
	_text(Vector2(10, 48), "CAP", 10, Color("9fb7be"), pane)
	var segs := 8
	var seg_w := (half - 28.0 - float(segs - 1) * 2.0) / float(segs)
	var lit_segs := int(ceil(cap / cap_max * float(segs) - 0.001))
	for i in segs:
		var col := CAP_C if i < lit_segs else DIM
		if lit_segs <= 2 and i < lit_segs:
			col = HOT_C
		pane.draw_rect(Rect2(Vector2(34.0 + float(i) * (seg_w + 2.0), 42.0), Vector2(maxf(seg_w, 2.0), 5.0)), col)
	var therm := float(p.get("therm", 0.0))
	var hot := bool(p.get("overheat", false))
	var hx := 10.0 + half + 8.0
	_text(Vector2(hx, 48), "HEAT" if not hot else "HOT", 10, HOT_C if hot else Color("9fb7be"), pane)
	var heat_x := hx + 36.0
	var heat_w := w - 10.0 - heat_x
	pane.draw_rect(Rect2(Vector2(heat_x, 42), Vector2(heat_w, 5)), DIM)
	var heat_col := Color("ffb15c").lerp(HOT_C, clampf((therm - 50.0) / 50.0, 0.0, 1.0))
	pane.draw_rect(Rect2(Vector2(heat_x, 42), Vector2(heat_w * clampf(therm / 100.0, 0.0, 1.0), 5)), heat_col)
	var sig := HelmCombat.effective_signature(sim, p)
	var sig_line := "SIG %.2f  %s" % [sig, Fit.signature_word(sig)]
	var threat_n := HelmCombat.lockers(sim, p).size()
	if threat_n > 0:
		sig_line += "  ·  %d locking" % threat_n
	_text(Vector2(10, 68), sig_line, 10, WARN_C if threat_n > 0 else Color("8aa8b0"), pane)
	var gun: Dictionary = Fit.stats(sim.defs, p).gun
	var mounts := Fit.mounts(sim.defs, p)
	var gun_word := "GUN READY"
	var gun_col := Color("9be7d0")
	if hot:
		gun_word = "COOLING"
		gun_col = HOT_C
	elif cap < float(gun.get("cap", 0.0)):
		gun_word = "CAP DRY"
		gun_col = HOT_C
	elif float(p.get("fire_cd", 0.0)) > 0.0 and mounts.is_empty():
		gun_word = "CYCLING"
		gun_col = CAP_C
	elif not mounts.is_empty():
		var bits: PackedStringArray = PackedStringArray()
		for mount in mounts:
			bits.append(str(mount.get("name", "Mount")))
		gun_word = " · ".join(bits)
	var target = HelmCombat.find_unit(sim, str(p.get("lock_id", "")))
	if target != null:
		var chance := HelmCombat.hit_chance(p, target, gun)
		gun_word = ("%s  %d%%" % [gun_word, int(round(chance * 100.0))]) if bool(p.get("lock_ok", false)) else gun_word + "  locking"
	_clip_text(pane, Vector2(w * 0.46, 68.0), w * 0.54 - 12.0, gun_word, 10, gun_col)


func _clip_text(pane: CanvasItem, at: Vector2, width: float, text: String, font_size: int, col: Color) -> void:
	var shown := text
	while shown.length() > 3 and _font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		shown = shown.substr(0, shown.length() - 2)
	if shown != text:
		shown = shown.substr(0, shown.length() - 1) + "…"
	_text(at, shown, font_size, col, pane)


# Overview -----------------------------------------------------------------

func _draw_overview(pane: Control) -> void:
	var sim = Game.sim
	_rows = _contacts(sim)
	_plate(pane, false)
	_text(Vector2(10, 16), "CONTACTS", 10, Color("7ed0dc"), pane)
	_text_right(pane, pane.size.x - 10.0, 16.0, "%d" % _rows.size(), 10, Color("8aa8b0"))
	pane.draw_line(Vector2(8, 20), Vector2(pane.size.x - 8, 20), Color(0.55, 0.86, 0.94, 0.25), 1.0)
	var lock_id := str(sim.player.get("lock_id", ""))
	var order: Dictionary = sim.player.get("order", {})
	var y := 22.0
	for i in _rows.size():
		if y + 20.0 > pane.size.y - 2.0:
			break
		var row: Dictionary = _rows[i]
		var col: Color = row.color
		if str(row.id) == lock_id:
			pane.draw_rect(Rect2(Vector2(4, y), Vector2(pane.size.x - 8, 18)), Color(col, 0.16))
			pane.draw_rect(Rect2(Vector2(4, y), Vector2(2, 18)), col)
		var glyph := Vector2(16, y + 10)
		if bool(row.wreck):
			pane.draw_polyline(PackedVector2Array([glyph + Vector2(0, -5), glyph + Vector2(5, 0), glyph + Vector2(0, 5), glyph + Vector2(-5, 0), glyph + Vector2(0, -5)]), col, 1.4, true)
		else:
			pane.draw_colored_polygon(PackedVector2Array([glyph + Vector2(6, 0), glyph + Vector2(-4, -5), glyph + Vector2(-4, 5)]), col)
		_clip_text(pane, Vector2(28, y + 14), pane.size.x - 118.0, str(row.name), 11, Color("e7f3f6"))
		var tag := str(row.word)
		if str(order.get("target", "")) == str(row.id):
			tag = str(order.get("kind", tag))
		_text_right(pane, pane.size.x - 52.0, y + 14, tag, 10, Color(col, 0.85))
		_text_right(pane, pane.size.x - 8.0, y + 14, _dist_word(float(row.dist)), 11, Color("c5d6dc"))
		y += 20.0
	if _rows.is_empty():
		_text(Vector2(10, 40), "No contacts.", 11, Color("8aa8b0"), pane)


# Target card --------------------------------------------------------------

func _draw_card(pane: Control) -> void:
	var sim = Game.sim
	var p: Dictionary = sim.player
	var target = HelmCombat.find_unit(sim, str(p.get("lock_id", "")))
	_plate(pane, true)
	if target == null:
		_draw_mark_card(pane, sim, p)
		return
	var mark := standing(sim, target)
	var col: Color = mark.color
	var w := pane.size.x
	pane.draw_rect(Rect2(Vector2(0, 10), Vector2(2, 36)), col)
	var hull: Dictionary = sim.defs.ships.get(str(target.get("class_id", "")), {})
	_clip_text(pane, Vector2(10, 16), w - 96.0, str(target.get("name", "Target")), 14, Color("f4fcff"))
	var class_line := "%s  ·  %s" % [str(hull.get("class_name", "")), str(mark.word)]
	var posted := int(hull.get("bounty", 0))
	if posted > 0:
		class_line += "  ·  bounty %d" % posted
	_text(Vector2(10, 30), class_line, 10, Color(col, 0.9), pane)
	var dist: float = p.pos.distance_to(target.pos)
	_text_right(pane, w - 10.0, 16.0, _dist_word(dist), 14, Color("f4fcff"))
	var gun: Dictionary = Fit.stats(sim.defs, p).gun
	var band_word := "optimal"
	if dist > float(gun.optimal) + float(gun.falloff):
		band_word = "past falloff"
	elif dist > float(gun.optimal):
		band_word = "falloff"
	_text_right(pane, w - 10.0, 30.0, band_word, 10, Color("8aa8b0"))
	var bar_w := (w - 20.0 - 12.0) / 3.0
	var rows := [
		["SHD", float(target.get("shield", 0.0)), float(target.get("shield_max", 0.0)), SHIELD_C],
		["ARM", float(target.get("armor_hp", 0.0)), float(target.get("armor_max", 0.0)), ARMOR_C],
		["HULL", float(target.hp), float(target.max_hp), HULL_C],
	]
	for i in rows.size():
		var row: Array = rows[i]
		var x := 10.0 + float(i) * (bar_w + 6.0)
		_text(Vector2(x, 44), str(row[0]), 9, Color("9fb7be"), pane)
		pane.draw_rect(Rect2(Vector2(x, 48), Vector2(bar_w, 3)), DIM)
		if float(row[2]) > 0.0:
			pane.draw_rect(Rect2(Vector2(x, 48), Vector2(bar_w * clampf(float(row[1]) / float(row[2]), 0.0, 1.0), 3)), row[3])
	var ok := bool(p.get("lock_ok", false))
	var need := maxf(0.01, float(p.get("lock_need", 1.0)))
	var reach := float(Fit.stats(sim.defs, p).sensor)
	var line := ""
	if dist > reach:
		line = "Out of sensor range (%s)." % _dist_word(reach)
	elif not ok:
		var frac := clampf(float(p.get("lock_t", 0.0)) / need, 0.0, 1.0)
		pane.draw_rect(Rect2(Vector2(10, 56), Vector2(w - 20.0, 3)), DIM)
		pane.draw_rect(Rect2(Vector2(10, 56), Vector2((w - 20.0) * frac, 3)), col)
		line = "Locking  %d%%" % int(frac * 100.0)
	else:
		var chance := HelmCombat.hit_chance(p, target, gun)
		line = "LOCKED  ·  hit %d%%  ·  trans %d" % [int(round(chance * 100.0)), int(HelmCombat.transversal(p, target))]
	_text(Vector2(10, 68), line, 10, Color("d5e4e8") if ok else Color("9fb7be"), pane)
	var order: Dictionary = p.get("order", {})
	for kind in order_buttons.keys():
		var button: Button = order_buttons[kind]
		var on: bool = str(order.get("kind", "")) == str(kind)
		if kind == "engage":
			on = str(p.get("engage", "")) != ""
		button.add_theme_color_override("font_color", Color("9be7d0") if on else Color("c5d6dc"))
	(order_buttons["orbit"] as Button).text = "Orbit %d" % int(ORBIT_RANGES[_orbit_pick])
	(order_buttons["keep"] as Button).text = "Keep %d" % int(KEEP_RANGES[_keep_pick])


func _draw_mark_card(pane: Control, sim, p: Dictionary) -> void:
	var place = HelmHarvest.marked(sim)
	if place == null:
		return
	var w := pane.size.x
	var col := Color(0.55, 0.96, 0.82, 0.95)
	pane.draw_rect(Rect2(Vector2(0, 10), Vector2(2, 36)), col)
	_clip_text(pane, Vector2(10, 16), w - 96.0, str(place.name), 14, Color("f4fcff"))
	var word := "ready to cut" if HelmHarvest.ready(sim, place) else "needs a scan"
	_text(Vector2(10, 30), "MARK  ·  %s" % word, 10, Color(col, 0.9), pane)
	var dist: float = p.pos.distance_to(place.pos)
	_text_right(pane, w - 10.0, 16.0, _dist_word(dist), 14, Color("f4fcff"))
	var left := int(sim.deposits.get(str(place.id), 0))
	var line := "Probe or Harvest flies here.  %d crate%s left." % [left, "" if left == 1 else "s"]
	if left <= 0:
		line = "This seam is worked out."
	_text(Vector2(10, 52), line, 10, Color("d5e4e8"), pane)


# Incoming lock ------------------------------------------------------------

func _draw_warn(pane: Control) -> void:
	var sim = Game.sim
	var threats := HelmCombat.lockers(sim, sim.player)
	if threats.is_empty():
		return
	_plate(pane, true)
	var row: Dictionary = threats[0]
	var ok := bool(row.lock_ok)
	var pulse := 0.55 + 0.45 * absf(sin(float(sim.time) * (8.0 if ok else 5.0)))
	var col := Color(WARN_C, pulse)
	pane.draw_rect(Rect2(Vector2(0, 0), Vector2(4, pane.size.y)), col)
	var head := "HAS LOCK" if ok else "LOCKING YOU"
	if threats.size() > 1:
		head = "%s  ·  %d" % [head, threats.size()]
	_text(Vector2(12, 14), head, 11, col, pane)
	_text_right(pane, pane.size.x - 10.0, 14.0, _dist_word(float(row.dist)), 12, Color("f4fcff"))
	_clip_text(pane, Vector2(12, 28), pane.size.x - 20.0, str(row.name), 12, Color("f4fcff"))
	var need := maxf(0.01, float(row.lock_need))
	var frac := 1.0 if ok else clampf(float(row.lock_t) / need, 0.0, 1.0)
	pane.draw_rect(Rect2(Vector2(12, 34), Vector2(pane.size.x - 24.0, 3)), DIM)
	pane.draw_rect(Rect2(Vector2(12, 34), Vector2((pane.size.x - 24.0) * frac, 3)), col)


# Tracker ------------------------------------------------------------------

func _draw_tracker(pane: Control) -> void:
	var sim = Game.sim
	var goals := objectives_of(sim)
	_plate(pane, false)
	_text(Vector2(10, 14), "OBJECTIVES", 10, QUEST_C, pane)
	var y := 18.0
	for i in mini(goals.size(), 2):
		var goal: Dictionary = goals[i]
		_diamond_on(pane, Vector2(14, y + 8), 3.0)
		_clip_text(pane, Vector2(22, y + 12), pane.size.x - 36.0, str(goal.title), 11, Color("f4e6c8"))
		var gap: float = sim.player.pos.distance_to(goal.pos)
		_clip_text(pane, Vector2(22, y + 26), pane.size.x - 80.0, str(goal.step), 10, Color("b7c9c4"))
		_text_right(pane, pane.size.x - 8.0, y + 26.0, _dist_word(gap), 10, QUEST_C)
		y += 32.0


func _diamond_on(pane: CanvasItem, c: Vector2, r: float) -> void:
	pane.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), QUEST_C)


class _Pane extends Control:
	var host: Object
	var method: String

	func _init(owner_node: Object, draw_method: String) -> void:
		host = owner_node
		method = draw_method

	func _draw() -> void:
		if host != null and Game.sim != null and Game.mode == "sector":
			host.call(method, self)
