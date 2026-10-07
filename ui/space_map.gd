extends Control

## The whole Haven chart. Lanes, regions, and every named system. No jump.

const Atlas = preload("res://ui/chart_atlas.gd")

var atlas: Dictionary = {}
var by_id: Dictionary = {}
var view_center := Vector2.ZERO
var view_span := 5.0
var selected := ""
var drag_on := false
var drag_origin := Vector2.ZERO
var drag_center := Vector2.ZERO
var drag_moved := false
var was_open := false
var card: PanelContainer
var card_title: Label
var card_body: Label
var close_button: Button
var zoom_in: Button
var zoom_out: Button
var fit_button: Button
var title: Label
var hint: Label


func _ready() -> void:
	name = "SpaceMap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 40
	set_anchors_preset(Control.PRESET_FULL_RECT)
	title = ThemeKit.label("SPACE MAP", 18, Color("f0c27a"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	hint = ThemeKit.label("Drag to move. Tap a system. F10, Esc, or Close.", 12, Color("8aa8b0"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	close_button = ThemeKit.button("Close", true)
	close_button.custom_minimum_size = Vector2(92, 44)
	close_button.pressed.connect(func() -> void:
		Game.set_map_open(false)
	)
	add_child(close_button)
	zoom_in = ThemeKit.button("+")
	zoom_in.custom_minimum_size = Vector2(44, 40)
	zoom_in.pressed.connect(func() -> void: _zoom_map(0.82, size * 0.5))
	add_child(zoom_in)
	zoom_out = ThemeKit.button("–")
	zoom_out.custom_minimum_size = Vector2(44, 40)
	zoom_out.pressed.connect(func() -> void: _zoom_map(1.22, size * 0.5))
	add_child(zoom_out)
	fit_button = ThemeKit.button("Fit")
	fit_button.custom_minimum_size = Vector2(72, 40)
	fit_button.pressed.connect(_fit_all)
	add_child(fit_button)
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", ThemeKit.glass(true))
	add_child(card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	card_title = ThemeKit.label("", 18, Color("f2fbff"))
	card_body = ThemeKit.label("", 14, Color("c5d6dc"))
	box.add_child(card_title)
	box.add_child(card_body)


func _process(_delta: float) -> void:
	var open := Game.map_open and Game.mode == "sector" and Game.sim != null
	if open != was_open:
		visible = open
		mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
		if open:
			_ensure_atlas()
			_fit_all()
			selected = _here()
			_fill_card()
			_layout()
		was_open = open
	if open:
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if close_button == null or size.x < 32.0:
		return
	title.position = Vector2(16, 12)
	title.size = Vector2(minf(280.0, size.x - 140.0), 26)
	hint.position = Vector2(16, 40)
	hint.size = Vector2(minf(460.0, size.x - 130.0), 36)
	close_button.position = Vector2(size.x - 108.0, 12)
	close_button.size = Vector2(92, 44)
	zoom_in.position = Vector2(size.x - 108.0, 64)
	zoom_in.size = Vector2(44, 40)
	zoom_out.position = Vector2(size.x - 58.0, 64)
	zoom_out.size = Vector2(44, 40)
	fit_button.position = Vector2(size.x - 108.0, 112)
	fit_button.size = Vector2(92, 40)
	var card_w := 320.0 if size.x >= 720.0 else size.x - 24.0
	var card_h := 210.0 if size.y >= 560.0 else 150.0
	card.position = Vector2(12, size.y - card_h - 12)
	card.size = Vector2(card_w, card_h)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_map(0.85, button.position)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_map(1.18, button.position)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				drag_on = true
				drag_moved = false
				drag_origin = button.position
				drag_center = view_center
			else:
				if drag_on and not drag_moved:
					var hit := _pick(button.position)
					if hit != "":
						selected = hit
						_fill_card()
				drag_on = false
			accept_event()
	elif event is InputEventMouseMotion and drag_on:
		var motion := event as InputEventMouseMotion
		if motion.position.distance_to(drag_origin) > 6.0:
			drag_moved = true
		var delta := motion.position - drag_origin
		var ppu := _pixels_per_unit()
		view_center = drag_center - Vector2(delta.x, -delta.y) / ppu
		accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			drag_on = true
			drag_moved = false
			drag_origin = touch.position
			drag_center = view_center
		else:
			if drag_on and not drag_moved:
				var hit := _pick(touch.position)
				if hit != "":
					selected = hit
					_fill_card()
			drag_on = false
		accept_event()
	elif event is InputEventScreenDrag and drag_on:
		var drag := event as InputEventScreenDrag
		if drag.position.distance_to(drag_origin) > 8.0:
			drag_moved = true
		var delta := drag.position - drag_origin
		var ppu := _pixels_per_unit()
		view_center = drag_center - Vector2(delta.x, -delta.y) / ppu
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.02, 0.03, 1.0))
	if atlas.is_empty():
		return
	_draw_grid()
	_draw_regions()
	_draw_lanes()
	_draw_systems()
	_draw_legend()


func _ensure_atlas() -> void:
	var defs: Dictionary = Game.defs
	if Game.sim != null:
		defs = Game.sim.defs
	atlas = Atlas.build(defs)
	by_id = {}
	var systems: Array = atlas.get("systems", [])
	for raw in systems:
		var row: Dictionary = raw
		by_id[str(row.get("id", ""))] = row


func _fit_all() -> void:
	var bounds: Rect2 = atlas.get("bounds", Rect2(-1, -1, 2, 2))
	view_center = bounds.position + bounds.size * 0.5
	var aspect := size.x / maxf(size.y, 1.0)
	var half_h := bounds.size.y * 0.5 + 0.95
	var half_w := bounds.size.x * 0.5 + 0.95
	view_span = maxf(half_h, half_w / maxf(aspect, 0.25)) * 1.08
	view_span = clampf(view_span, 0.4, 14.0)
	queue_redraw()


func _zoom_map(factor: float, focus: Vector2) -> void:
	var before := _unproject(focus)
	view_span = clampf(view_span * factor, 0.35, 14.0)
	var after := _unproject(focus)
	view_center += before - after
	queue_redraw()


func _pixels_per_unit() -> float:
	return (size.y * 0.5 - 28.0) / maxf(view_span, 0.2)


func _origin() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.46)


func _project(world: Vector2) -> Vector2:
	var delta := world - view_center
	var ppu := _pixels_per_unit()
	return _origin() + Vector2(delta.x, -delta.y) * ppu


func _unproject(screen_at: Vector2) -> Vector2:
	var delta := screen_at - _origin()
	var ppu := maxf(_pixels_per_unit(), 0.001)
	return view_center + Vector2(delta.x, -delta.y) / ppu


func _here() -> String:
	if Game.sim == null:
		return ""
	return str(Game.sim.defs.system.get("id", ""))


func _visited(system_id: String) -> bool:
	if Game.sim == null:
		return false
	return Game.sim.visited.has(system_id)


func _pick(screen_at: Vector2) -> String:
	var best := ""
	var best_d := 22.0
	var systems: Array = atlas.get("systems", [])
	for raw in systems:
		var row: Dictionary = raw
		var world: Vector2 = row.get("pos", Vector2.ZERO)
		var at := _project(world)
		var dist := at.distance_to(screen_at)
		if dist < best_d:
			best_d = dist
			best = str(row.get("id", ""))
	return best


func _fill_card() -> void:
	var row: Dictionary = by_id.get(selected, {})
	if row.is_empty():
		card_title.text = "Haven chart"
		card_body.text = "Tap a system. The chart is the whole catalog. It does not move the ship."
		return
	card_title.text = str(row.get("name", ""))
	var lines := str(row.get("region_name", ""))
	if str(row.get("id", "")) == _here():
		lines += "\nYou are here."
	elif _visited(str(row.get("id", ""))):
		lines += "\nLogged."
	else:
		lines += "\nNot yet logged."
	var hops: Array = Atlas.links(atlas, str(row.get("id", "")))
	if hops.is_empty():
		lines += "\nNo charted lane."
	else:
		lines += "\nLanes"
		for hop in hops:
			var hop_row: Dictionary = hop
			var other: Dictionary = by_id.get(str(hop_row.get("id", "")), {})
			var hop_name := str(other.get("name", hop_row.get("id", "")))
			var traffic := str(hop_row.get("traffic", ""))
			var rule := str(hop_row.get("color", ""))
			if traffic != "":
				lines += "\n%s · %s · %s" % [hop_name, rule, traffic]
			else:
				lines += "\n%s · %s" % [hop_name, rule]
	card_body.text = lines


func _draw_grid() -> void:
	var ink := Color(1, 1, 1, 0.045)
	for x in range(-1, 6):
		draw_line(_project(Vector2(x, -4)), _project(Vector2(x, 8)), ink, 1.0)
	for y in range(-3, 8):
		draw_line(_project(Vector2(-2, y)), _project(Vector2(6, y)), ink, 1.0)


func _draw_regions() -> void:
	var font := ThemeDB.fallback_font
	var regions: Array = atlas.get("regions", [])
	for raw in regions:
		var row: Dictionary = raw
		var home := Vector2(float(row.get("x", 0.0)), float(row.get("y", 0.0)))
		var at := _project(home)
		var rad := _pixels_per_unit() * 0.72
		draw_arc(at, rad, 0.0, TAU, 40, Color(0.62, 0.78, 0.7, 0.16), 1.0)
		if font != null and view_span > 1.8:
			var label := str(row.get("name", ""))
			draw_string(font, at + Vector2(-70, -rad - 4), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color(0.78, 0.7, 0.5, 0.7))


func _draw_lanes() -> void:
	var lanes: Array = atlas.get("lanes", [])
	for raw in lanes:
		var lane: Dictionary = raw
		var a: Dictionary = by_id.get(str(lane.get("from", "")), {})
		var b: Dictionary = by_id.get(str(lane.get("to", "")), {})
		if a.is_empty() or b.is_empty():
			continue
		var ink := Atlas.lane_color(str(lane.get("color", "amber")))
		ink.a = 0.85
		var from_at: Vector2 = a.get("pos", Vector2.ZERO)
		var to_at: Vector2 = b.get("pos", Vector2.ZERO)
		draw_line(_project(from_at), _project(to_at), ink, 2.0)


func _draw_systems() -> void:
	var font := ThemeDB.fallback_font
	var here := _here()
	var systems: Array = atlas.get("systems", [])
	var show_names := view_span < 2.35
	for raw in systems:
		var row: Dictionary = raw
		var sid := str(row.get("id", ""))
		var world: Vector2 = row.get("pos", Vector2.ZERO)
		var at := _project(world)
		if at.x < -20.0 or at.y < -20.0 or at.x > size.x + 20.0 or at.y > size.y + 20.0:
			continue
		var ink := Color(0.38, 0.48, 0.52)
		if _visited(sid):
			ink = Color("cbb892")
		if sid == here:
			ink = Color("9eecf5")
		var rad := 4.5
		if int(row.get("slot", 1)) == 1:
			rad = 6.0
		if sid == here:
			rad = 8.0
			draw_arc(at, 12.0, 0.0, TAU, 20, Color("9eecf5"), 1.5)
		draw_circle(at, rad, ink)
		if sid == selected:
			draw_arc(at, rad + 5.0, 0.0, TAU, 18, Color("f0c27a"), 1.5)
		var named := show_names or sid == here or sid == selected
		if named and font != null:
			draw_string(font, at + Vector2(-48, rad + 14), str(row.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, 96, 12, Color("e7f3f6"))


func _draw_legend() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var x := size.x - 168.0
	var y := size.y - 78.0
	if card != null and card.position.x + card.size.x > x - 8.0 and card.position.y < y + 70.0:
		return
	var rows := [["green", "green lane"], ["amber", "amber lane"], ["red", "red lane"]]
	var i := 0
	for row in rows:
		var pair: Array = row
		var at := Vector2(x, y + float(i) * 18.0)
		draw_line(at, at + Vector2(18, 0), Atlas.lane_color(str(pair[0])), 3.0)
		draw_string(font, at + Vector2(24, 4), str(pair[1]), HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color("c5d6dc"))
		i += 1
