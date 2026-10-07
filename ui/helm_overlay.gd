extends Control

## The combat glass over the helm: brackets in space, the tank capsule, the
## overview, the target card, and the objective tracker. It reads the sim and
## sends lock and order verbs; the host decides what they do.

const SHIELD_C := Color("6fc8ff")
const ARMOR_C := Color("e8b36a")
const HULL_C := Color("f07a6a")
const CAP_C := Color("ffe28a")
const HOT_C := Color("ff7a3c")
const QUEST_C := Color("ffd27a")
const DIM := Color(0.55, 0.7, 0.76, 0.22)
const ORBIT_RANGES := [220.0, 320.0, 450.0]
const KEEP_RANGES := [450.0, 650.0, 900.0]

var hud: Node
var capsule: Control
var overview: Control
var card: Control
var tracker: Control
var order_row: HBoxContainer
var order_buttons: Dictionary = {}
var _brackets: Array = []
var _rows: Array = []
var _orbit_pick := 1
var _keep_pick := 0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	capsule = _Pane.new(self, "_draw_capsule")
	capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(capsule)
	tracker = _Pane.new(self, "_draw_tracker")
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tracker)
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
	for spec in [["approach", "Approach"], ["orbit", "Orbit"], ["keep", "Keep"], ["stop", "Stop"], ["unlock", "✕"]]:
		var button := ThemeKit.button(str(spec[1]), false)
		button.custom_minimum_size = Vector2(0, 36)
		button.add_theme_font_size_override("font_size", 13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_press_order.bind(str(spec[0])))
		order_row.add_child(button)
		order_buttons[str(spec[0])] = button


func _process(_delta: float) -> void:
	var live := Game.mode == "sector" and Game.sim != null and hud != null
	visible = live
	if not live:
		return
	_place()
	queue_redraw()
	for pane in [capsule, overview, card, tracker]:
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

	var cap_w := minf(440.0, screen.x - 16.0)
	var cap_h := 104.0
	capsule.visible = band and not short and floor_y - cap_h > left_bottom + 40.0
	if capsule.visible:
		capsule.size = Vector2(cap_w, cap_h)
		capsule.position = Vector2((screen.x - cap_w) * 0.5, floor_y - cap_h)
		floor_y = capsule.position.y - 8.0

	var right_x := screen.x - 8.0
	var col_top := 8.0
	if stick != null:
		col_top = stick.position.y + stick.size.y + 8.0
	if minimap != null:
		col_top = maxf(col_top, minimap.position.y + minimap.size.y + 8.0)
	var rows := _contacts(sim)
	var ov_w := 300.0
	var ov_h := 36.0 + 24.0 * float(clampi(rows.size(), 1, 8))
	var ov_room := floor_y - col_top
	overview.visible = band and not compact and panel == null and ov_room > 84.0
	if overview.visible:
		ov_h = minf(ov_h, ov_room)
		overview.size = Vector2(ov_w, ov_h)
		overview.position = Vector2(right_x - ov_w, col_top)

	var locked := str(sim.player.get("lock_id", "")) != ""
	card.visible = band and locked
	var card_h := 136.0
	if card.visible:
		var lo := 8.0
		if status != null:
			lo = status.position.x + status.size.x + 10.0
		var hi := screen.x - 8.0
		if minimap != null:
			hi = minf(hi, minimap.position.x - 10.0)
		elif stick != null:
			hi = minf(hi, stick.position.x - 10.0)
		if panel != null:
			hi = minf(hi, panel.position.x - 10.0)
		var card_w := minf(400.0, hi - lo)
		if card_w >= 320.0 and not compact:
			card.size = Vector2(card_w, card_h)
			card.position = Vector2(lo + (hi - lo - card_w) * 0.5, 8.0)
		else:
			card_w = minf(400.0, screen.x - 16.0)
			card.size = Vector2(card_w, card_h)
			card.position = Vector2((screen.x - card_w) * 0.5, floor_y - card_h)
			floor_y = card.position.y - 8.0
			if card.position.y < left_bottom:
				card.visible = false
		order_row.position = Vector2(10.0, card_h - 44.0)
		order_row.size = Vector2(card.size.x - 20.0, 36.0)

	var objectives := objectives_of(sim)
	var tr_w := 300.0
	var tr_h := 26.0 + 36.0 * float(mini(objectives.size(), 2))
	tracker.visible = not objectives.is_empty() and not compact and floor_y - left_bottom > tr_h + 8.0
	if tracker.visible:
		tracker.size = Vector2(tr_w, tr_h)
		tracker.position = Vector2(10.0, left_bottom + 2.0)
		if panel != null and tracker.position.x + tr_w > panel.position.x:
			tracker.visible = false


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
	for row in HelmCombat.targets(sim, sim.player, float(stats.sensor) * 1.6):
		var unit: Dictionary = row.unit
		var mark := standing(sim, unit)
		var hull: Dictionary = sim.defs.ships.get(str(unit.get("class_id", "")), {})
		rows.append({
			"id": str(row.id),
			"name": str(unit.get("name", "Contact")),
			"kind": str(hull.get("class_name", unit.get("class_id", ""))),
			"dist": float(row.dist),
			"color": mark.color,
			"word": mark.word,
			"unit": unit,
			"wreck": false,
		})
	for wreck in sim.wrecks:
		if bool(wreck.get("stripped", false)):
			continue
		var gap: float = sim.player.pos.distance_to(wreck.pos)
		if gap > float(stats.sensor):
			continue
		rows.append({
			"id": str(wreck.id),
			"name": "Wreck · %s" % str(wreck.get("name", "keel")),
			"kind": "salvage",
			"dist": gap,
			"color": Color("a9b4b8"),
			"word": "wreck",
			"unit": wreck,
			"wreck": true,
		})
	rows.sort_custom(func(a, b): return float(a.dist) < float(b.dist))
	return rows


## Live objectives with a place in this system: dock slips first, then the
## shakedown mark.
func objectives_of(sim) -> Array:
	var out: Array = []
	var here := str(sim.defs.system.id)
	if here == "HC-V1-R1-S1":
		if DockBoard.state(sim, "dock_scan") == "active":
			var sealed: bool = sim.dossier_complete("aegis_prime")
			var body = sim.planet("aegis_prime")
			var at: Vector2 = sim.beacon_pos if sealed else (body.pos if body != null else sim.beacon_pos)
			var probe := "Probe reading Aegis Prime"
			for item in sim.craft:
				if str(item.def_id) == "survey_probe" and str(item.state) != "docked" and str(item.state) != "lost":
					probe = "Probe %s · %s" % [str(item.state), str(item.get("target", "aegis_prime"))]
			out.append({"title": "Seal Aegis Prime  ·  pay %d" % DockBoard.SCAN_PAY, "step": "Stand the pad to file it" if sealed else probe, "pos": at, "label": "Helion pad" if sealed else "Aegis Prime"})
		if DockBoard.state(sim, "dock_haul") == "active":
			var ring = sim.survey_node("aegis_ring")
			var back := bool(sim.quest_flags.get("dock_haul_ring", false))
			var spot: Vector2 = sim.beacon_pos if back or ring == null else ring.pos
			out.append({"title": "Crate to the ice ring  ·  pay %d" % DockBoard.HAUL_PAY, "step": "Bring the crate back" if back else "Hold toward the ice ring", "pos": spot, "label": "Helion pad" if back else "Ice ring drop"})
		if DockBoard.state(sim, "dock_salvage") == "active":
			var cut := bool(sim.quest_flags.get("dock_salvage_cut", false))
			out.append({"title": "Tow tag at Seized Hold  ·  pay %d" % DockBoard.SALVAGE_PAY, "step": "Bring the tag to the pad" if cut else "Strip one tow tag", "pos": sim.beacon_pos if cut else sim.trash_pos, "label": "Helion pad" if cut else "Seized Hold"})
		if DockBoard.state(sim, "dock_escort") == "active":
			var met := bool(sim.quest_flags.get("dock_escort_met", false))
			var cutter: Vector2 = DockBoard.cutter_pos(sim)
			out.append({"title": "Show the Compact the lane  ·  pay %d" % DockBoard.ESCORT_PAY, "step": "Stand the pad" if met else "Find the Compact cutter", "pos": sim.beacon_pos if met else cutter, "label": "Helion pad" if met else "Compact cutter"})
	var focus: Dictionary = QuestBoard.focus(sim)
	var beat := str(sim.quest_flags.get("shakedown_beat", "undock"))
	if out.size() < 2 and str(focus.get("system_id", "")) == here and beat != "done" and beat != "failed":
		var spot := Vector2(float(focus.get("x", 0.0)), float(focus.get("y", 0.0)))
		if spot != Vector2.ZERO and str(focus.get("kind", "")) != "keel":
			out.append({"title": "Shakedown  ·  %s" % beat, "step": "Mark: %s" % str(focus.get("label", "")), "pos": spot, "label": str(focus.get("label", "mark"))})
	return out


func _dist_word(meters: float) -> String:
	if meters >= 10000.0:
		return "%.0f km" % (meters / 1000.0)
	if meters >= 1000.0:
		return "%.1f km" % (meters / 1000.0)
	return "%d m" % int(meters)


# Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or Game.sim == null or Game.map_open or Game.paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
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
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var at := (event as InputEventMouseButton).position
		var best := {}
		var best_d := 34.0
		for row in _brackets:
			var gap: float = (row.at as Vector2).distance_to(at)
			if gap < best_d:
				best_d = gap
				best = row
		if best.is_empty():
			return
		_pick(str(best.id), bool(best.wreck), (event as InputEventMouseButton).double_click)
		get_viewport().set_input_as_handled()


func _overview_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var press := event as InputEventMouseButton
	if press.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := int((press.position.y - 30.0) / 24.0)
	if press.position.y < 30.0 or index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	_pick(str(row.id), bool(row.wreck), press.double_click)
	overview.accept_event()


func _pick(id: String, wreck: bool, double: bool) -> void:
	if wreck:
		Game.tap("order", {"kind": "approach", "target": id, "range": 40.0})
		return
	Game.tap("lock", id)
	if double:
		Game.tap("order", {"kind": "approach", "target": id})


func _press_order(kind: String) -> void:
	if Game.sim == null:
		return
	var target := str(Game.sim.player.get("lock_id", ""))
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


# Brackets -----------------------------------------------------------------

func _draw() -> void:
	_brackets = []
	var sim = Game.sim
	if sim == null or int(sim.layer) != ScaleFrame.BAND:
		return
	var helm: Node = hud.get_parent().get_node_or_null("Helm") if hud.get_parent() != null else null
	if helm == null:
		return
	var cam: Camera3D = helm.get("cam3")
	var stage = helm.get("stage")
	if cam == null or stage == null:
		return
	var lock_id := str(sim.player.get("lock_id", ""))
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


# Capsule ------------------------------------------------------------------

func _draw_capsule(pane: Control) -> void:
	var sim = Game.sim
	var p: Dictionary = sim.player
	var w := pane.size.x
	var h := pane.size.y
	pane.draw_style_box(ThemeKit.glass(true), Rect2(Vector2.ZERO, pane.size))
	var mid := Vector2(w * 0.5, 64.0)
	var rings := [
		[float(p.get("shield", 0.0)), float(p.get("shield_max", 0.0)), SHIELD_C, 50.0, "S"],
		[float(p.get("armor_hp", 0.0)), float(p.get("armor_max", 0.0)), ARMOR_C, 42.0, "A"],
		[float(p.hp), float(p.max_hp), HULL_C, 34.0, "H"],
	]
	var flash := clampf(1.0 - (float(sim.time) - float(p.get("hit_at", -10.0))) / 0.5, 0.0, 1.0)
	var hit_layer := str(p.get("hit_layer", ""))
	for ring in rings:
		var top := maxf(float(ring[1]), 0.001)
		var frac := clampf(float(ring[0]) / top, 0.0, 1.0)
		var col: Color = ring[2]
		var radius: float = ring[3]
		pane.draw_arc(mid, radius, PI, TAU, 40, DIM, 5.0, true)
		if float(ring[1]) > 0.0 and frac > 0.002:
			var lit := col
			var layer_key: String = {"S": "shield", "A": "armor", "H": "hull"}[str(ring[4])]
			if flash > 0.0 and hit_layer == layer_key:
				lit = col.lerp(Color.WHITE, flash * 0.7)
			pane.draw_arc(mid, radius, PI, PI + PI * frac, 40, lit, 5.0, true)
	var speed := int(Vector2(p.vel).length())
	var boosting := bool(p.get("boosting", false))
	_text_mid(pane, mid.x, mid.y - 6.0, "%d" % speed, 24, Color("ffd59a") if boosting else Color("f4fcff"))
	_text_mid(pane, mid.x, mid.y + 10.0, "m/s", 11, Color("8aa8b0"))
	var tank := "%d · %d · %d" % [int(float(p.get("shield", 0.0))), int(float(p.get("armor_hp", 0.0))), int(float(p.hp))]
	_text_mid(pane, mid.x, h - 12.0, tank, 12, Color("c5d6dc"))
	# Capacitor, left wing.
	var cap := float(p.get("cap", 0.0))
	var cap_max := maxf(float(p.get("cap_max", 1.0)), 1.0)
	var lx := 16.0
	var wing := w * 0.5 - 70.0 - lx
	_text(Vector2(lx, 24.0), "CAPACITOR", 11, Color("9fb7be"), pane)
	_text_right(pane, lx + wing, 24.0, "%d/%d" % [int(cap), int(cap_max)], 11, CAP_C)
	var segs := 12
	var seg_w := (wing - float(segs - 1) * 2.0) / float(segs)
	var lit_segs := int(ceil(cap / cap_max * float(segs) - 0.001))
	for i in segs:
		var col := CAP_C if i < lit_segs else DIM
		if lit_segs <= 2 and i < lit_segs:
			col = HOT_C
		pane.draw_rect(Rect2(Vector2(lx + float(i) * (seg_w + 2.0), 32.0), Vector2(seg_w, 9.0)), col)
	var therm := float(p.get("therm", 0.0))
	var hot := bool(p.get("overheat", false))
	_text(Vector2(lx, 62.0), "HEAT" if not hot else "OVERHEAT", 11, HOT_C if hot else Color("9fb7be"), pane)
	_text_right(pane, lx + wing, 62.0, "%d%%" % int(therm), 11, HOT_C if therm > 70.0 else Color("c5d6dc"))
	pane.draw_rect(Rect2(Vector2(lx, 70.0), Vector2(wing, 7.0)), DIM)
	var heat_col := Color("ffb15c").lerp(HOT_C, clampf((therm - 50.0) / 50.0, 0.0, 1.0))
	pane.draw_rect(Rect2(Vector2(lx, 70.0), Vector2(wing * clampf(therm / 100.0, 0.0, 1.0), 7.0)), heat_col)
	var sig := HelmCombat.effective_signature(sim, p)
	_text(Vector2(lx, 94.0), "SIG %.2f  %s" % [sig, Fit.signature_word(sig)], 11, Color("8aa8b0"), pane)
	# Helm state, right wing.
	var rx := w * 0.5 + 70.0
	var r_end := w - 16.0
	var order: Dictionary = p.get("order", {})
	var helm_word := "MANUAL HELM"
	var helm_col := Color("9fb7be")
	if not order.is_empty():
		helm_word = HelmCombat.order_label(sim, order).to_upper()
		helm_col = Color("9be7d0")
	if bool(p.get("moored", false)):
		helm_word = "MOORED"
	_text(Vector2(rx, 24.0), "HELM", 11, Color("9fb7be"), pane)
	_clip_text(pane, Vector2(rx, 40.0), r_end - rx, helm_word, 12, helm_col)
	var gun: Dictionary = Fit.stats(sim.defs, p).gun
	var gun_word := "GUN READY"
	var gun_col := Color("9be7d0")
	if hot:
		gun_word = "GUN COOLING"
		gun_col = HOT_C
	elif cap < float(gun.get("cap", 0.0)):
		gun_word = "GUN DRY"
		gun_col = HOT_C
	elif float(p.get("fire_cd", 0.0)) > 0.0:
		gun_word = "GUN CYCLING"
		gun_col = CAP_C
	_text(Vector2(rx, 62.0), "WEAPON", 11, Color("9fb7be"), pane)
	_text(Vector2(rx, 78.0), gun_word, 12, gun_col, pane)
	var lock_word := "Tab to lock"
	var target = HelmCombat.find_unit(sim, str(p.get("lock_id", "")))
	if target != null:
		var chance := HelmCombat.hit_chance(p, target, gun)
		lock_word = ("hit %d%%" % int(round(chance * 100.0))) if bool(p.get("lock_ok", false)) else "locking…"
	_text_right(pane, r_end, 94.0, lock_word, 11, Color("8aa8b0"))


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
	pane.draw_style_box(ThemeKit.glass(false), Rect2(Vector2.ZERO, pane.size))
	_text(Vector2(12, 19), "OVERVIEW", 11, Color("7ed0dc"), pane)
	_text_right(pane, pane.size.x - 12.0, 19.0, "%d in sensor" % _rows.size(), 11, Color("8aa8b0"))
	pane.draw_line(Vector2(10, 26), Vector2(pane.size.x - 10, 26), Color(0.55, 0.86, 0.94, 0.25), 1.0)
	var lock_id := str(sim.player.get("lock_id", ""))
	var order: Dictionary = sim.player.get("order", {})
	var y := 30.0
	for i in _rows.size():
		if y + 24.0 > pane.size.y - 2.0:
			break
		var row: Dictionary = _rows[i]
		var col: Color = row.color
		if str(row.id) == lock_id:
			pane.draw_rect(Rect2(Vector2(4, y), Vector2(pane.size.x - 8, 23)), Color(col, 0.16))
			pane.draw_rect(Rect2(Vector2(4, y), Vector2(3, 23)), col)
		var glyph := Vector2(18, y + 12)
		if bool(row.wreck):
			pane.draw_polyline(PackedVector2Array([glyph + Vector2(0, -5), glyph + Vector2(5, 0), glyph + Vector2(0, 5), glyph + Vector2(-5, 0), glyph + Vector2(0, -5)]), col, 1.4, true)
		else:
			pane.draw_colored_polygon(PackedVector2Array([glyph + Vector2(6, 0), glyph + Vector2(-4, -5), glyph + Vector2(-4, 5)]), col)
		_clip_text(pane, Vector2(30, y + 16), pane.size.x - 150.0, str(row.name), 12, Color("e7f3f6"))
		var tag := str(row.word)
		if str(order.get("target", "")) == str(row.id):
			tag = str(order.get("kind", tag))
		_text_right(pane, pane.size.x - 72.0, y + 16, tag, 10, Color(col, 0.85))
		_text_right(pane, pane.size.x - 10.0, y + 16, _dist_word(float(row.dist)), 12, Color("c5d6dc"))
		y += 24.0
	if _rows.is_empty():
		_text(Vector2(12, 46), "No contacts in sensor range.", 12, Color("8aa8b0"), pane)


# Target card --------------------------------------------------------------

func _draw_card(pane: Control) -> void:
	var sim = Game.sim
	var p: Dictionary = sim.player
	var target = HelmCombat.find_unit(sim, str(p.get("lock_id", "")))
	pane.draw_style_box(ThemeKit.glass(true), Rect2(Vector2.ZERO, pane.size))
	if target == null:
		return
	var mark := standing(sim, target)
	var col: Color = mark.color
	var w := pane.size.x
	pane.draw_rect(Rect2(Vector2(0, 14), Vector2(3, 54)), col)
	var hull: Dictionary = sim.defs.ships.get(str(target.get("class_id", "")), {})
	_clip_text(pane, Vector2(14, 24), w - 130.0, str(target.get("name", "Target")), 16, Color("f4fcff"))
	_text(Vector2(14, 40), "%s  ·  %s" % [str(hull.get("class_name", "")), str(mark.word)], 11, Color(col, 0.9), pane)
	var dist: float = p.pos.distance_to(target.pos)
	_text_right(pane, w - 14.0, 26.0, _dist_word(dist), 18, Color("f4fcff"))
	var gun: Dictionary = Fit.stats(sim.defs, p).gun
	var band_word := "in optimal"
	if dist > float(gun.optimal) + float(gun.falloff):
		band_word = "past falloff"
	elif dist > float(gun.optimal):
		band_word = "in falloff"
	_text_right(pane, w - 14.0, 42.0, band_word, 11, Color("8aa8b0"))
	var bar_w := (w - 28.0 - 16.0) / 3.0
	var rows := [
		["SHIELD", float(target.get("shield", 0.0)), float(target.get("shield_max", 0.0)), SHIELD_C],
		["ARMOR", float(target.get("armor_hp", 0.0)), float(target.get("armor_max", 0.0)), ARMOR_C],
		["HULL", float(target.hp), float(target.max_hp), HULL_C],
	]
	for i in rows.size():
		var row: Array = rows[i]
		var x := 14.0 + float(i) * (bar_w + 8.0)
		_text(Vector2(x, 58), str(row[0]), 10, Color("9fb7be"), pane)
		_text_right(pane, x + bar_w, 58.0, "%d" % int(float(row[1])), 10, row[3])
		pane.draw_rect(Rect2(Vector2(x, 62), Vector2(bar_w, 5)), DIM)
		if float(row[2]) > 0.0:
			pane.draw_rect(Rect2(Vector2(x, 62), Vector2(bar_w * clampf(float(row[1]) / float(row[2]), 0.0, 1.0), 5)), row[3])
	var ok := bool(p.get("lock_ok", false))
	var need := maxf(0.01, float(p.get("lock_need", 1.0)))
	var reach := float(Fit.stats(sim.defs, p).sensor)
	var line := ""
	if dist > reach:
		line = "Out of sensor range (%s). Close in to lock." % _dist_word(reach)
	elif not ok:
		var frac := clampf(float(p.get("lock_t", 0.0)) / need, 0.0, 1.0)
		pane.draw_rect(Rect2(Vector2(14, 76), Vector2(w - 28.0, 4)), DIM)
		pane.draw_rect(Rect2(Vector2(14, 76), Vector2((w - 28.0) * frac, 4)), col)
		line = "Locking  %d%%  ·  %.1f s scan" % [int(frac * 100.0), need]
	else:
		var chance := HelmCombat.hit_chance(p, target, gun)
		line = "LOCKED  ·  hit %d%%  ·  transversal %d m/s" % [int(round(chance * 100.0)), int(HelmCombat.transversal(p, target))]
	_text(Vector2(14, 90), line, 11, Color("d5e4e8") if ok else Color("9fb7be"), pane)
	var order: Dictionary = p.get("order", {})
	for kind in order_buttons.keys():
		var button: Button = order_buttons[kind]
		var on: bool = str(order.get("kind", "")) == str(kind)
		button.add_theme_color_override("font_color", Color("9be7d0") if on else Color("c5d6dc"))
	(order_buttons["orbit"] as Button).text = "Orbit %d" % int(ORBIT_RANGES[_orbit_pick])
	(order_buttons["keep"] as Button).text = "Keep %d" % int(KEEP_RANGES[_keep_pick])


# Tracker ------------------------------------------------------------------

func _draw_tracker(pane: Control) -> void:
	var sim = Game.sim
	var goals := objectives_of(sim)
	pane.draw_style_box(ThemeKit.glass(false), Rect2(Vector2.ZERO, pane.size))
	_text(Vector2(12, 18), "OBJECTIVES", 11, QUEST_C, pane)
	var y := 26.0
	for i in mini(goals.size(), 2):
		var goal: Dictionary = goals[i]
		_diamond_on(pane, Vector2(16, y + 9), 4.0)
		_clip_text(pane, Vector2(28, y + 13), pane.size.x - 40.0, str(goal.title), 12, Color("f4e6c8"))
		var gap: float = sim.player.pos.distance_to(goal.pos)
		_clip_text(pane, Vector2(28, y + 28), pane.size.x - 100.0, str(goal.step), 11, Color("b7c9c4"))
		_text_right(pane, pane.size.x - 12.0, y + 28.0, _dist_word(gap), 11, QUEST_C)
		y += 36.0


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
