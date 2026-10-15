extends Control

## Local sky, north up. The ship stays in the middle. A tap opens the 3D chart.

const Atlas = preload("res://ui/chart_atlas.gd")
const RANGE := 1600.0

var _glass: StyleBoxFlat


func _ready() -> void:
	name = "MiniMap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_glass = ThemeKit.glass(true)
	_glass.content_margin_left = 0
	_glass.content_margin_right = 0
	_glass.content_margin_top = 0
	_glass.content_margin_bottom = 0


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			Game.set_map_open(true)
			accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			Game.set_map_open(true)
			accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _glass != null:
		_glass.draw(get_canvas_item(), rect)
	else:
		draw_rect(rect, Color(0.025, 0.04, 0.06, 0.82))
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(8, 16), "MAP", HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 12, Color("f0c27a"))
	if size.x < 48.0 or size.y < 48.0:
		return
	if Game.sim == null or Game.mode != "sector":
		return
	var sim = Game.sim
	var player: Dictionary = sim.player
	var origin: Vector2 = player.get("pos", Vector2.ZERO)
	var center := size * 0.5
	var span := minf(size.x, size.y) * 0.5 - 12.0
	var scale := span / RANGE
	draw_arc(center, span, 0.0, TAU, 48, Color(0.45, 0.7, 0.76, 0.28), 1.0)
	draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), Color(1, 1, 1, 0.12), 1.0)
	draw_line(center + Vector2(0, -6), center + Vector2(0, 6), Color(1, 1, 1, 0.12), 1.0)
	if int(sim.layer) != ScaleFrame.BAND:
		if font != null:
			draw_string(font, Vector2(8, size.y * 0.5), "local sky", HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 12, Color("8aa8b0"))
		_draw_chevron(center, float(player.get("rot", 0.0)))
		return
	_draw_green(sim, origin, center, scale, span)
	_draw_star(sim, origin, center, scale, span)
	_draw_planets(sim, origin, center, scale, span)
	_draw_pocket(sim, origin, center, scale, span)
	_draw_gates(sim, origin, center, scale, span)
	_draw_field(sim, origin, center, scale, span)
	_draw_dock(sim, origin, center, scale, span)
	_draw_bands(sim, player, center, scale)
	_draw_contacts(sim, player, origin, center, scale, span)
	_draw_chevron(center, float(player.get("rot", 0.0)))
	if font != null:
		var room: Dictionary = HelmCombat.presence(sim)
		var caption := "%s  ·  %d cap" % [str(sim.defs.system.get("name", "")), int(room.captains)]
		if int(room.hostiles) > 0:
			caption += "  %d host" % int(room.hostiles)
		draw_string(font, Vector2(8, size.y - 8), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 11, Color("9eecf5"))


func _plot(world: Vector2, origin: Vector2, center: Vector2, scale: float, span: float) -> Dictionary:
	var delta := world - origin
	var local := Vector2(delta.x, -delta.y) * scale
	var inside := local.length() <= span
	if not inside and local.length() > 0.001:
		local = local.normalized() * span
	return {"at": center + local, "inside": inside}


func _draw_star(sim, origin: Vector2, center: Vector2, scale: float, span: float) -> void:
	var plotted: Dictionary = _plot(Vector2.ZERO, origin, center, scale, span)
	var at: Vector2 = plotted.at
	var rad := 4.0
	if bool(plotted.inside):
		rad = clampf(float(sim.star_radius) * scale, 3.0, 18.0)
	draw_circle(at, rad, Color("f0c27a"))


func _draw_planets(sim, origin: Vector2, center: Vector2, scale: float, span: float) -> void:
	for body in sim.planets:
		var row: Dictionary = body
		var plotted: Dictionary = _plot(row.pos, origin, center, scale, span)
		var at: Vector2 = plotted.at
		if bool(plotted.inside):
			var rad := clampf(float(row.radius) * scale, 2.5, 16.0)
			draw_circle(at, rad, Color(0.62, 0.74, 0.76, 0.9))
			draw_arc(at, rad + 1.5, 0.0, TAU, 16, Color("c5d6dc"), 1.0)
		else:
			draw_circle(at, 3.0, Color(0.62, 0.74, 0.76, 0.85))


func _draw_green(sim, origin: Vector2, center: Vector2, scale: float, span: float) -> void:
	var zones: Dictionary = sim.defs.system.get("zones", {})
	var green: Dictionary = zones.get("green", {})
	if green.is_empty():
		return
	var anchor = sim.planet(str(green.get("anchor", "")))
	if anchor == null:
		return
	var reach := float(green.get("radius", 0.0)) * scale
	if reach < 4.0:
		return
	var plotted: Dictionary = _plot(anchor.pos, origin, center, scale, span)
	if bool(plotted.inside) == false and reach < span:
		return
	var at: Vector2 = plotted.at
	draw_arc(at, reach, 0.0, TAU, 40, Color(0.45, 0.75, 0.5, 0.35), 1.0)


func _draw_pocket(sim, origin: Vector2, center: Vector2, scale: float, span: float) -> void:
	if sim.pocket_pos == Vector2.ZERO:
		return
	var plotted: Dictionary = _plot(sim.pocket_pos, origin, center, scale, span)
	var at: Vector2 = plotted.at
	if bool(plotted.inside):
		var pocket: Dictionary = sim.defs.system.get("pocket", {})
		var rad := clampf(float(pocket.get("radius", 80.0)) * scale, 3.0, span)
		draw_arc(at, rad, 0.0, TAU, 28, Color(0.55, 0.82, 0.62, 0.7), 1.0)
	else:
		draw_circle(at, 2.5, Color(0.55, 0.82, 0.62, 0.8))


func _draw_gates(sim, origin: Vector2, center: Vector2, scale: float, span: float) -> void:
	for gate in sim.gates:
		var row: Dictionary = gate
		var plotted: Dictionary = _plot(row.pos, origin, center, scale, span)
		var at: Vector2 = plotted.at
		var ink: Color = Atlas.lane_color(str(row.get("color", "amber")))
		var rad := 4.0
		if bool(plotted.inside):
			rad = clampf(float(row.get("radius", 80.0)) * scale, 3.5, 10.0)
		draw_arc(at, rad, 0.0, TAU, 12, ink, 1.5)


func _draw_field(sim, origin: Vector2, center: Vector2, scale: float, span: float) -> void:
	for rock in sim.asteroids:
		var row: Dictionary = rock
		var plotted: Dictionary = _plot(row.pos, origin, center, scale, span)
		if bool(plotted.inside):
			draw_circle(plotted.at, 2.2, Color(str(row.get("tint", "#e0a05a"))))
	for rock in sim.meteors:
		var row: Dictionary = rock
		var plotted: Dictionary = _plot(row.pos, origin, center, scale, span)
		if bool(plotted.inside):
			draw_circle(plotted.at, 2.0, Color("d5e6f0"))
	for hull in sim.trash:
		var row: Dictionary = hull
		var plotted: Dictionary = _plot(row.pos, origin, center, scale, span)
		if bool(plotted.inside):
			draw_rect(Rect2(plotted.at - Vector2(1.6, 1.6), Vector2(3.2, 3.2)), Color("c4a882"))


func _draw_dock(sim, origin: Vector2, center: Vector2, scale: float, span: float) -> void:
	if sim.beacon_pos == Vector2.ZERO:
		return
	var plotted: Dictionary = _plot(sim.beacon_pos, origin, center, scale, span)
	var at: Vector2 = plotted.at
	var arm := 5.0 if bool(plotted.inside) else 3.5
	var diamond := PackedVector2Array([
		at + Vector2(0, -arm),
		at + Vector2(arm, 0),
		at + Vector2(0, arm),
		at + Vector2(-arm, 0),
	])
	draw_colored_polygon(diamond, Color("9eecf5"))


func _draw_bands(sim, player: Dictionary, center: Vector2, scale: float) -> void:
	var bands: Dictionary = HelmCombat.range_bands(sim, player)
	draw_arc(center, float(bands.sensor) * scale, 0.0, TAU, 40, Color(0.45, 0.82, 0.9, 0.32), 1.0)
	var threats := HelmCombat.lockers(sim, player)
	var armed := str(player.get("lock_id", "")) != "" or str(player.get("engage", "")) != ""
	if threats.is_empty() and not armed:
		return
	draw_arc(center, float(bands.optimal) * scale, 0.0, TAU, 32, Color(0.45, 0.92, 0.62, 0.45), 1.1)
	draw_arc(center, float(bands.falloff) * scale, 0.0, TAU, 32, Color(0.95, 0.72, 0.28, 0.38), 1.0)


func _draw_contacts(sim, player: Dictionary, origin: Vector2, center: Vector2, scale: float, span: float) -> void:
	var self_id := str(player.get("agent_id", player.get("id", "")))
	var lock_id := str(player.get("lock_id", ""))
	for raw in sim.captains:
		var mate: Dictionary = raw
		if str(mate.get("agent_id", "")) == self_id:
			continue
		if not bool(mate.get("alive", false)):
			continue
		var plotted: Dictionary = _plot(mate.pos, origin, center, scale, span)
		if bool(plotted.inside):
			draw_circle(plotted.at, 3.0, Color("8fc7ff"))
	for item in sim.craft:
		var row: Dictionary = item
		if str(row.get("state", "")) == "lost" or str(row.get("state", "")) == "docked":
			continue
		var plotted: Dictionary = _plot(row.pos, origin, center, scale, span)
		if bool(plotted.inside):
			draw_circle(plotted.at, 2.0, Color("7ed0dc"))
	for wreck in sim.wrecks:
		var hull: Dictionary = wreck
		if bool(hull.get("stripped", false)):
			continue
		var plotted: Dictionary = _plot(hull.pos, origin, center, scale, span)
		if not bool(plotted.inside):
			continue
		var at: Vector2 = plotted.at
		var arm := 3.2
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(0, -arm),
			at + Vector2(arm, 0),
			at + Vector2(0, arm),
			at + Vector2(-arm, 0),
		]), Color("c4b48a"))
	for actor in sim.actors:
		var ship: Dictionary = actor
		if str(ship.get("agent_id", ship.get("id", ""))) == self_id:
			continue
		if bool(ship.get("alive", true)) == false:
			continue
		var plotted: Dictionary = _plot(ship.pos, origin, center, scale, span)
		var hostile := str(ship.get("team", "")) == "red_keel"
		var locking := str(ship.get("lock_id", "")) == self_id
		if bool(plotted.inside) == false and not hostile and not locking:
			continue
		var ink := Color(0.9, 0.94, 0.95, 0.85)
		if hostile:
			var paint := str(ship.get("paint", "#ff6a5c"))
			ink = Color(paint)
		elif locking:
			ink = Color("ff6a5c")
		var rad := 3.4 if hostile or locking else 2.0
		draw_circle(plotted.at, rad, ink)
		if locking or str(ship.get("agent_id", "")) == lock_id:
			draw_arc(plotted.at, rad + 3.0, 0.0, TAU, 16, ink, 1.2)


func _draw_chevron(center: Vector2, rot: float) -> void:
	var nose := Vector2.from_angle(-rot) * 9.0
	var left := Vector2.from_angle(-rot + 2.45) * 7.0
	var right := Vector2.from_angle(-rot - 2.45) * 7.0
	draw_colored_polygon(PackedVector2Array([center + nose, center + left, center + right]), Color("e9fbff"))
