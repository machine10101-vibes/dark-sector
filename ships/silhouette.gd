class_name Silhouette
extends RefCounted

## Top-down keel geometry. Modules append real shape; they are not stat stickers.


static func shapes_of(defs: Dictionary, module_ids: Array) -> Array:
	var shapes: Array = []
	for module_id in module_ids:
		var mod: Dictionary = defs.modules.get(module_id, {})
		shapes.append(str(mod.get("shape", "")))
	return shapes


static func layers_of(defs: Dictionary, module_ids: Array) -> Array:
	var layers: Array = []
	for module_id in module_ids:
		var mod: Dictionary = defs.modules.get(module_id, {})
		var raw: Array = mod.get("layer", [])
		for poly in raw:
			layers.append(poly)
	return layers


static func parts(class_id: String, shapes: Array, layers: Array = []) -> Dictionary:
	var hull := PackedVector2Array()
	var extras: Array = []
	var circles: Array = []
	match class_id:
		"vesper":
			hull = PackedVector2Array([
				Vector2(52, 0), Vector2(18, 5), Vector2(-22, 3.5),
				Vector2(-40, 1.4), Vector2(-40, -1.4), Vector2(-22, -3.5), Vector2(18, -5)
			])
		"anvil":
			hull = PackedVector2Array([
				Vector2(26, 0), Vector2(22, 12), Vector2(10, 22), Vector2(-18, 24),
				Vector2(-34, 14), Vector2(-34, -14), Vector2(-18, -24), Vector2(10, -22), Vector2(22, -12)
			])
		"kestrel":
			hull = PackedVector2Array([
				Vector2(48, 0), Vector2(12, 7), Vector2(-6, 16), Vector2(-28, 10),
				Vector2(-22, 0), Vector2(-28, -10), Vector2(-6, -16), Vector2(12, -7)
			])
		"skiff":
			hull = PackedVector2Array([
				Vector2(22, 0), Vector2(4, 8), Vector2(-16, 5), Vector2(-16, -5), Vector2(4, -8)
			])
		"cutter":
			hull = PackedVector2Array([
				Vector2(30, 0), Vector2(8, 10), Vector2(-18, 12), Vector2(-24, 0),
				Vector2(-18, -12), Vector2(8, -10)
			])
		_:
			hull = PackedVector2Array([Vector2(16, 0), Vector2(-12, 8), Vector2(-12, -8)])
	if layers.is_empty() and shapes.has("mast"):
		extras.append(PackedVector2Array([
			Vector2(46, 1.6), Vector2(86, 0), Vector2(46, -1.6)
		]))
	if layers.is_empty() and shapes.has("blister"):
		circles.append({"x": -4.0, "y": 32.0, "r": 11.0})
		circles.append({"x": -4.0, "y": -32.0, "r": 11.0})
		extras.append(PackedVector2Array([
			Vector2(-2, 20), Vector2(6, 24), Vector2(-10, 24)
		]))
		extras.append(PackedVector2Array([
			Vector2(-2, -20), Vector2(6, -24), Vector2(-10, -24)
		]))
	if layers.is_empty() and shapes.has("sponson"):
		extras.append(PackedVector2Array([
			Vector2(4, 10), Vector2(16, 26), Vector2(-8, 22), Vector2(-6, 12)
		]))
		extras.append(PackedVector2Array([
			Vector2(4, -10), Vector2(16, -26), Vector2(-8, -22), Vector2(-6, -12)
		]))
	for poly in layers:
		var packed := PackedVector2Array()
		for pt in poly:
			packed.append(Vector2(float(pt[0]), float(pt[1])))
		if packed.size() >= 3:
			extras.append(packed)
	var tail := 0.0
	if hull.size() > 0:
		tail = hull[0].x
		for point in hull:
			tail = minf(tail, point.x)
	return {"hull": hull, "extras": extras, "circles": circles, "tail": tail}


static func extent(geom: Dictionary) -> Vector2:
	var max_x := 0.0
	var max_y := 0.0
	var lists: Array = [geom.hull]
	lists.append_array(geom.extras)
	for poly in lists:
		for point in poly:
			max_x = maxf(max_x, point.x)
			max_y = maxf(max_y, absf(point.y))
	for circle in geom.circles:
		max_x = maxf(max_x, absf(float(circle.x)) + float(circle.r))
		max_y = maxf(max_y, absf(float(circle.y)) + float(circle.r))
	return Vector2(max_x, max_y)


static func draw(ci: CanvasItem, origin: Vector2, rot: float, class_id: String, shapes: Array, scale: float, body: Color, accent: Color, hp_ratio: float = 1.0, thrusting: bool = false, layers: Array = [], light: Vector2 = Vector2(0, -1)) -> void:
	var geom := parts(class_id, shapes, layers)
	var hull: PackedVector2Array = geom.hull
	if hull.is_empty():
		return
	var lit := _unit(light)
	var xf := Transform2D(rot, origin)
	var worn := body.lerp(Color("3a1818"), clampf((1.0 - hp_ratio) * 0.75, 0.0, 0.75))
	var pts := PackedVector2Array()
	for point in hull:
		pts.append(xf * (point * scale))
	var shadow := PackedVector2Array()
	var cast := PackedVector2Array()
	for point in pts:
		shadow.append(point - lit * (3.4 * scale))
		cast.append(point - lit * (8.0 * scale))
	ci.draw_colored_polygon(cast, Color(0, 0, 0, 0.14))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	ci.draw_colored_polygon(pts, worn.darkened(0.5))
	ci.draw_colored_polygon(_inset_world(pts, 2.4 * scale, -lit * (2.2 * scale)), Color(0.02, 0.025, 0.03, 0.34))
	ci.draw_colored_polygon(_inset_world(pts, 1.1 * scale, lit * (1.0 * scale)), worn.darkened(0.16))
	ci.draw_colored_polygon(_inset_world(pts, 2.6 * scale, lit * (3.0 * scale)), worn.lightened(0.06))
	ci.draw_colored_polygon(_inset_world(pts, 4.4 * scale, lit * (5.2 * scale)), worn.lightened(0.26))
	var spec := _centroid(pts) + lit * (5.5 * scale)
	var tangent := Vector2(-lit.y, lit.x)
	ci.draw_line(spec - tangent * (2.8 * scale), spec + tangent * (0.8 * scale) + lit * (1.6 * scale), Color(1, 0.97, 0.9, 0.62), maxf(1.0, 0.9 * scale), true)
	var cool := spec - tangent * (1.6 * scale) - lit * (1.8 * scale)
	ci.draw_line(cool, cool + lit * (3.2 * scale) + tangent * (0.4 * scale), Color(0.72, 0.86, 0.94, 0.32), maxf(1.0, 0.55 * scale), true)
	if class_id == "vesper":
		_paint_needle(ci, xf, scale, worn, accent, shapes, thrusting)
	elif class_id == "anvil":
		_paint_barn(ci, xf, scale, worn, accent)
	elif class_id == "kestrel":
		_paint_beak(ci, xf, scale, worn, accent)
	elif class_id == "cutter" or class_id == "skiff":
		_paint_small(ci, xf, scale, worn, accent)
	_paint_lights(ci, xf, scale, class_id)
	_rim(ci, pts, lit, accent.lightened(0.2), 1.35)
	_paint_fit(ci, xf, scale, class_id, shapes, accent)
	if class_id == "vesper" and (shapes.has("mast") or _layer_reaches(layers, 80.0)):
		ci.draw_circle(xf * (Vector2(46, 0) * scale), 1.25 * scale, worn.darkened(0.2))
	if hp_ratio < 0.72:
		var scar_a := xf * (Vector2(-10, -7) * scale)
		var scar_b := xf * (Vector2(14, 8) * scale)
		ci.draw_line(scar_a, scar_b, Color("140808"), 1.6, true)
	if thrusting:
		var tail := float(geom.tail)
		var haze := PackedVector2Array([
			xf * (Vector2(tail + 1.0, 6.5) * scale),
			xf * (Vector2(tail - 26.0, 0.0) * scale),
			xf * (Vector2(tail + 1.0, -6.5) * scale),
		])
		var flame := PackedVector2Array([
			xf * (Vector2(tail + 2.0, 3.2) * scale),
			xf * (Vector2(tail - 14.0, 0.0) * scale),
			xf * (Vector2(tail + 2.0, -3.2) * scale),
		])
		var core := PackedVector2Array([
			xf * (Vector2(tail + 1.0, 1.3) * scale),
			xf * (Vector2(tail - 8.0, 0.0) * scale),
			xf * (Vector2(tail + 1.0, -1.3) * scale),
		])
		var sheath := PackedVector2Array([
			xf * (Vector2(tail + 1.0, 9.2) * scale),
			xf * (Vector2(tail - 40.0, 0.0) * scale),
			xf * (Vector2(tail + 1.0, -9.2) * scale),
		])
		var ion := PackedVector2Array([
			xf * (Vector2(tail + 0.6, 0.7) * scale),
			xf * (Vector2(tail - 6.2, 0.0) * scale),
			xf * (Vector2(tail + 0.6, -0.7) * scale),
		])
		ci.draw_colored_polygon(sheath, Color(0.95, 0.38, 0.1, 0.18))
		ci.draw_colored_polygon(haze, Color(0.91, 0.55, 0.22, 0.45))
		ci.draw_colored_polygon(flame, Color("e7b15a"))
		ci.draw_colored_polygon(core, Color("fff1d2"))
		ci.draw_colored_polygon(ion, Color(0.82, 0.92, 1.0, 0.92))
		ci.draw_circle(xf * (Vector2(tail - 7.0, 0.0) * scale), 3.4 * scale, Color(1.0, 0.62, 0.28, 0.28))
		for diamond in 3:
			var along := tail - 8.0 - float(diamond) * 7.0
			ci.draw_circle(xf * (Vector2(along, 0.0) * scale), (1.15 - float(diamond) * 0.22) * scale, Color(1.0, 0.94, 0.82, 0.32))


static func _unit(v: Vector2) -> Vector2:
	if v.length_squared() < 0.0001:
		return Vector2(0, -1)
	return v.normalized()


static func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	if pts.is_empty():
		return c
	for point in pts:
		c += point
	return c / float(pts.size())


static func _inset_world(pts: PackedVector2Array, amount: float, nudge: Vector2) -> PackedVector2Array:
	var c := _centroid(pts)
	var out := PackedVector2Array()
	for point in pts:
		var delta := point - c
		var len := delta.length()
		if len < 0.01:
			out.append(point + nudge)
		else:
			var keep := maxf(len * 0.42, len - amount)
			out.append(c + delta * (keep / len) + nudge)
	return out


static func _rim(ci: CanvasItem, pts: PackedVector2Array, lit: Vector2, col: Color, width: float) -> void:
	var c := _centroid(pts)
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var edge := b - a
		if edge.length_squared() < 0.01:
			continue
		var normal := Vector2(-edge.y, edge.x).normalized()
		var mid := (a + b) * 0.5
		if normal.dot(mid - c) < 0.0:
			normal = -normal
		var face := clampf(normal.dot(lit), 0.0, 1.0)
		if face < 0.18:
			continue
		var tone := col
		tone.a = 0.28 + face * 0.72
		ci.draw_line(a, b, tone, width, true)


static func _layer_reaches(layers: Array, reach: float) -> bool:
	for poly in layers:
		for pt in poly:
			if absf(float(pt[0])) >= reach or absf(float(pt[1])) >= reach:
				return true
	return false


static func _paint_needle(ci: CanvasItem, xf: Transform2D, scale: float, plate: Color, accent: Color, shapes: Array, thrusting: bool) -> void:
	# Material gate on the existing Needle planform. Same teal plate and bone trim.
	# Seams, canopy, collar, and nozzle sit inside the hull. They do not change extent.
	var seam := plate.darkened(0.42)
	var weight := maxf(1.0, 0.55 * scale)
	ci.draw_line(xf * (Vector2(36, 0) * scale), xf * (Vector2(-32, 0) * scale), seam, weight, true)
	ci.draw_line(xf * (Vector2(32, 1.55) * scale), xf * (Vector2(-26, 1.15) * scale), seam, maxf(1.0, weight * 0.65), true)
	ci.draw_line(xf * (Vector2(32, -1.55) * scale), xf * (Vector2(-26, -1.15) * scale), seam, maxf(1.0, weight * 0.65), true)
	ci.draw_circle(xf * (Vector2(-28, 0) * scale), 1.7 * scale, Color(0.42, 0.2, 0.1, 0.5))
	for station in [24.0, 12.0, 2.0, -8.0, -16.0]:
		var half := 1.35
		ci.draw_line(
			xf * (Vector2(station, half) * scale),
			xf * (Vector2(station, -half) * scale),
			seam,
			maxf(1.0, weight * 0.8),
			true
		)
	var nose := PackedVector2Array([
		xf * (Vector2(52, 0) * scale),
		xf * (Vector2(40, 1.15) * scale),
		xf * (Vector2(40, -1.15) * scale),
	])
	ci.draw_colored_polygon(nose, accent)
	var glass := Color("143e42")
	var canopy := PackedVector2Array([
		xf * (Vector2(34, 0) * scale),
		xf * (Vector2(22, 2.6) * scale),
		xf * (Vector2(14, 0) * scale),
		xf * (Vector2(22, -2.6) * scale),
	])
	ci.draw_colored_polygon(canopy, glass)
	ci.draw_line(
		xf * (Vector2(30, -1.1) * scale),
		xf * (Vector2(18, 0.55) * scale),
		Color(0.78, 0.93, 0.9, 0.72),
		maxf(1.0, 0.55 * scale),
		true
	)
	ci.draw_line(
		xf * (Vector2(27, 1.35) * scale),
		xf * (Vector2(19, -0.35) * scale),
		Color(0.9, 0.97, 0.95, 0.32),
		maxf(1.0, 0.4 * scale),
		true
	)
	for rivet_i in 5:
		var rx := 18.0 - float(rivet_i) * 7.5
		ci.draw_circle(xf * (Vector2(rx, 2.05) * scale), 0.36 * scale, seam.lightened(0.2))
		ci.draw_circle(xf * (Vector2(rx, -2.05) * scale), 0.36 * scale, seam.lightened(0.2))
	ci.draw_circle(xf * (Vector2(-29, 0) * scale), 2.2 * scale, Color(0.42, 0.2, 0.08, 0.4))
	ci.draw_line(
		xf * (Vector2(-40, 1.05) * scale),
		xf * (Vector2(-40, -1.05) * scale),
		accent.lightened(0.35),
		maxf(1.0, 0.7 * scale),
		true
	)
	var collar := PackedVector2Array([
		xf * (Vector2(-32, 1.35) * scale),
		xf * (Vector2(-40, 1.05) * scale),
		xf * (Vector2(-40, -1.05) * scale),
		xf * (Vector2(-32, -1.35) * scale),
	])
	ci.draw_colored_polygon(collar, accent)
	var throat := PackedVector2Array([
		xf * (Vector2(-35.5, 0.55) * scale),
		xf * (Vector2(-40, 0.42) * scale),
		xf * (Vector2(-40, -0.42) * scale),
		xf * (Vector2(-35.5, -0.55) * scale),
	])
	ci.draw_colored_polygon(throat, plate.darkened(0.82))
	if thrusting:
		var ember := PackedVector2Array([
			xf * (Vector2(-36.2, 0.28) * scale),
			xf * (Vector2(-39.6, 0.18) * scale),
			xf * (Vector2(-39.6, -0.18) * scale),
			xf * (Vector2(-36.2, -0.28) * scale),
		])
		ci.draw_colored_polygon(ember, Color("e7b15a"))


static func _paint_barn(ci: CanvasItem, xf: Transform2D, scale: float, plate: Color, accent: Color) -> void:
	var seam := plate.darkened(0.48)
	var bay := plate.darkened(0.3)
	ci.draw_line(xf * (Vector2(8, 0) * scale), xf * (Vector2(-22, 0) * scale), seam, maxf(1.0, 0.7 * scale), true)
	for y in [-12.0, 12.0]:
		var hold := PackedVector2Array([
			xf * (Vector2(6, y - 4.0) * scale),
			xf * (Vector2(-12, y - 4.0) * scale),
			xf * (Vector2(-14, y + 4.0) * scale),
			xf * (Vector2(4, y + 4.0) * scale),
		])
		ci.draw_colored_polygon(hold, bay)
		ci.draw_polyline(PackedVector2Array([hold[0], hold[1], hold[2], hold[3], hold[0]]), accent.darkened(0.2), 1.0, true)
	var bridge := PackedVector2Array([
		xf * (Vector2(16, 3.2) * scale),
		xf * (Vector2(8, 3.2) * scale),
		xf * (Vector2(8, -3.2) * scale),
		xf * (Vector2(16, -3.2) * scale),
	])
	ci.draw_colored_polygon(bridge, Color("1c2420"))
	ci.draw_line(xf * (Vector2(14.5, -1.5) * scale), xf * (Vector2(9.5, 1.1) * scale), Color(0.72, 0.84, 0.76, 0.6), 1.0, true)
	ci.draw_line(xf * (Vector2(13.2, 1.6) * scale), xf * (Vector2(10.2, -0.4) * scale), Color(0.9, 0.95, 0.9, 0.28), 1.0, true)
	ci.draw_line(xf * (Vector2(-8, 6) * scale), xf * (Vector2(-8, -6) * scale), seam, 1.2, true)
	ci.draw_circle(xf * (Vector2(-26, 0) * scale), 2.6 * scale, Color(0.28, 0.14, 0.08, 0.35))
	for stud in [2.0, -6.0, -16.0]:
		ci.draw_circle(xf * (Vector2(stud, 7.2) * scale), 0.6 * scale, seam)
		ci.draw_circle(xf * (Vector2(stud, -7.2) * scale), 0.6 * scale, seam)
	for vent in [4.0, -6.0]:
		ci.draw_line(xf * (Vector2(vent, 15.5) * scale), xf * (Vector2(vent - 5.0, 15.5) * scale), seam, 1.3, true)
		ci.draw_line(xf * (Vector2(vent, -15.5) * scale), xf * (Vector2(vent - 5.0, -15.5) * scale), seam, 1.3, true)
	var hatch := PackedVector2Array([
		xf * (Vector2(20, 2.2) * scale),
		xf * (Vector2(12, 2.2) * scale),
		xf * (Vector2(12, -2.2) * scale),
		xf * (Vector2(20, -2.2) * scale),
	])
	ci.draw_colored_polygon(hatch, plate.darkened(0.22))
	ci.draw_circle(xf * (Vector2(18, 0) * scale), 1.4 * scale, accent.lightened(0.25))


static func _paint_beak(ci: CanvasItem, xf: Transform2D, scale: float, plate: Color, accent: Color) -> void:
	var seam := plate.darkened(0.4)
	ci.draw_line(xf * (Vector2(30, 0) * scale), xf * (Vector2(-16, 0) * scale), seam, maxf(1.0, 0.55 * scale), true)
	var canopy := PackedVector2Array([
		xf * (Vector2(22, 0) * scale),
		xf * (Vector2(12, 3.4) * scale),
		xf * (Vector2(4, 0) * scale),
		xf * (Vector2(12, -3.4) * scale),
	])
	ci.draw_colored_polygon(canopy, Color("1a2428"))
	ci.draw_line(xf * (Vector2(18, -1.5) * scale), xf * (Vector2(8, 0.7) * scale), Color(0.78, 0.88, 0.92, 0.62), 1.0, true)
	ci.draw_line(xf * (Vector2(16, 1.8) * scale), xf * (Vector2(9, -0.2) * scale), Color(0.92, 0.96, 0.98, 0.28), 1.0, true)
	var intake := PackedVector2Array([
		xf * (Vector2(-8, 2.2) * scale),
		xf * (Vector2(-16, 1.4) * scale),
		xf * (Vector2(-16, -1.4) * scale),
		xf * (Vector2(-8, -2.2) * scale),
	])
	ci.draw_colored_polygon(intake, plate.darkened(0.7))
	for y in [9.0, -9.0]:
		ci.draw_line(xf * (Vector2(6, y) * scale), xf * (Vector2(-18, y * 0.7) * scale), accent.darkened(0.15), 1.1, true)
		ci.draw_line(xf * (Vector2(-2, y * 0.85) * scale), xf * (Vector2(-14, y * 0.55) * scale), plate.darkened(0.55), 1.5, true)
	ci.draw_circle(xf * (Vector2(-16, 2.6) * scale), 1.15 * scale, plate.darkened(0.72))
	ci.draw_circle(xf * (Vector2(-16, -2.6) * scale), 1.15 * scale, plate.darkened(0.72))
	ci.draw_circle(xf * (Vector2(34, 0) * scale), 1.2 * scale, accent)


static func _paint_small(ci: CanvasItem, xf: Transform2D, scale: float, plate: Color, accent: Color) -> void:
	ci.draw_line(xf * (Vector2(10, 0) * scale), xf * (Vector2(-8, 0) * scale), plate.darkened(0.45), 1.0, true)
	ci.draw_line(xf * (Vector2(8, 1.7) * scale), xf * (Vector2(-5, 1.7) * scale), plate.darkened(0.28), 1.0, true)
	ci.draw_line(xf * (Vector2(8, -1.7) * scale), xf * (Vector2(-5, -1.7) * scale), plate.darkened(0.28), 1.0, true)
	ci.draw_line(xf * (Vector2(1.5, 2.6) * scale), xf * (Vector2(1.5, -2.6) * scale), plate.darkened(0.4), 1.0, true)
	ci.draw_circle(xf * (Vector2(6, 0) * scale), 1.3 * scale, accent.darkened(0.1))
	ci.draw_circle(xf * (Vector2(5.2, -0.35) * scale), 0.4 * scale, Color(0.9, 0.96, 0.94, 0.55))
	ci.draw_circle(xf * (Vector2(2.2, -0.4) * scale), 0.55 * scale, Color(0.85, 0.92, 0.88, 0.5))
	ci.draw_circle(xf * (Vector2(-6, 0) * scale), 1.1 * scale, plate.darkened(0.65))


static func _paint_lights(ci: CanvasItem, xf: Transform2D, scale: float, class_id: String) -> void:
	var nose_x := 12.0
	var nose_y := 3.0
	var tail_x := -12.0
	match class_id:
		"vesper":
			nose_x = 26.0
			nose_y = 2.2
			tail_x = -24.0
		"anvil":
			nose_x = 8.0
			nose_y = 9.0
			tail_x = -22.0
		"kestrel":
			nose_x = 14.0
			nose_y = 4.2
			tail_x = -12.0
		"skiff":
			nose_x = 6.0
			nose_y = 2.4
			tail_x = -8.0
		"cutter":
			nose_x = 8.0
			nose_y = 3.6
			tail_x = -10.0
	var port := Color("c4512c")
	var starboard := Color("7d9a86")
	ci.draw_circle(xf * (Vector2(nose_x, nose_y) * scale), 1.5 * scale, Color(port.r, port.g, port.b, 0.28))
	ci.draw_circle(xf * (Vector2(nose_x, -nose_y) * scale), 1.5 * scale, Color(starboard.r, starboard.g, starboard.b, 0.28))
	ci.draw_circle(xf * (Vector2(nose_x, nose_y) * scale), 0.75 * scale, port)
	ci.draw_circle(xf * (Vector2(nose_x, -nose_y) * scale), 0.75 * scale, starboard)
	ci.draw_circle(xf * (Vector2(tail_x, 0.0) * scale), 0.65 * scale, Color("e7b15a"))


static func _paint_fit(ci: CanvasItem, xf: Transform2D, scale: float, class_id: String, shapes: Array, accent: Color) -> void:
	var seen := {}
	for raw in shapes:
		var shape := str(raw)
		if shape == "":
			continue
		var index := int(seen.get(shape, 0))
		seen[shape] = index + 1
		_paint_shape(ci, xf, scale, class_id, shape, index, accent)


static func _half_beam(class_id: String, along: float) -> float:
	var hull: PackedVector2Array = parts(class_id, []).hull
	var best := 0.0
	var count := hull.size()
	for i in count:
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i + 1) % count]
		if along < minf(a.x, b.x) - 0.01 or along > maxf(a.x, b.x) + 0.01:
			continue
		var span := b.x - a.x
		var t := 0.0 if absf(span) < 0.001 else clampf((along - a.x) / span, 0.0, 1.0)
		best = maxf(best, absf(lerpf(a.y, b.y, t)))
	return best


static func _fit_x(class_id: String, shape: String) -> float:
	if class_id == "anvil":
		match shape:
			"pack", "scale":
				return -2.0
			"fans", "lighter":
				return -22.0
			"keel", "collar":
				return 20.0
			"hold", "bell":
				return -8.0
			"hopper":
				return -16.0
			"dome", "pen":
				return 6.0
			"vault":
				return -20.0
			"lamp", "shear", "fighter":
				return 14.0
			_:
				return -6.0
	if class_id == "kestrel":
		match shape:
			"pack", "dome", "bell":
				return -4.0
			"fans", "hopper":
				return -12.0
			"keel", "collar", "lamp":
				return 36.0
			"hold":
				return -8.0
			_:
				return -2.0
	match shape:
		"pack":
			return -8.0
		"fans":
			return -24.0
		"keel", "collar", "lamp", "shear":
			return 42.0
		"hold":
			return -16.0
		"hopper":
			return -20.0
		"dome":
			return 2.0
		_:
			return -10.0


static func _quad(ci: CanvasItem, xf: Transform2D, scale: float, center: Vector2, size: Vector2, yaw: float, color: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var corners: Array[Vector2] = [Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)]
	var pts := PackedVector2Array()
	for corner in corners:
		pts.append(xf * ((center + corner.rotated(yaw)) * scale))
	ci.draw_colored_polygon(pts, color)
	ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), color.darkened(0.4), maxf(1.0, 0.45 * scale), true)


static func _mark(ci: CanvasItem, xf: Transform2D, scale: float, at: Vector2, radius: float, color: Color) -> void:
	ci.draw_circle(xf * (at * scale), radius * scale, color)
	ci.draw_arc(xf * (at * scale), radius * scale, 0.0, TAU, 12, color.darkened(0.45), maxf(1.0, 0.4 * scale), true)


static func _paint_shape(ci: CanvasItem, xf: Transform2D, scale: float, class_id: String, shape: String, index: int, _accent: Color) -> void:
	var along := _fit_x(class_id, shape) + float(index) * 4.0
	var skin := _half_beam(class_id, along)
	var side := 1.0 if index % 2 == 0 else -1.0
	var flank := 0.0
	if class_id == "anvil":
		flank = side * minf(maxf(skin * 0.38, 3.0), 10.0)
	elif class_id == "kestrel":
		flank = side * maxf(skin * 0.72, 2.0)
	elif shape != "pack" and shape != "dome" and shape != "keel" and shape != "lamp" and shape != "collar":
		flank = side * maxf(skin * 0.82, 1.4)
	var yaw := 0.0
	if class_id == "kestrel" and absf(flank) > 2.0:
		var ahead := _half_beam(class_id, along + 3.0)
		var behind := _half_beam(class_id, along - 3.0)
		yaw = atan2((ahead - behind) * side, 6.0)
	match shape:
		"mast":
			if class_id == "anvil":
				_mark(ci, xf, scale, Vector2(2.0, 0.0), 3.2, Color("c4b49a"))
				_mark(ci, xf, scale, Vector2(2.0, 0.0), 1.1, Color("9fd0c8"))
			elif class_id == "kestrel":
				ci.draw_line(xf * (Vector2(8.0, 8.0) * scale), xf * (Vector2(22.0, 16.0) * scale), Color("c4b49a"), maxf(1.2, 0.7 * scale), true)
				_mark(ci, xf, scale, Vector2(22.0, 16.0), 1.6, Color("9fd0c8"))
			else:
				ci.draw_line(xf * (Vector2(46.0, 0.0) * scale), xf * (Vector2(74.0, 0.0) * scale), Color("c4b49a"), maxf(1.2, 0.55 * scale), true)
				_mark(ci, xf, scale, Vector2(74.0, 0.0), 1.5, Color("9fd0c8"))
		"blister":
			if class_id == "anvil":
				_quad(ci, xf, scale, Vector2(-6.0, 0.0), Vector2(18.0, 16.0), 0.0, Color("a89880"))
				_quad(ci, xf, scale, Vector2(2.0, 0.0), Vector2(2.0, 10.0), 0.0, Color("5c5348"))
			elif class_id == "kestrel":
				_quad(ci, xf, scale, Vector2(-4.0, 9.0), Vector2(10.0, 2.4), 0.4, Color("a89880"))
				_quad(ci, xf, scale, Vector2(-4.0, -9.0), Vector2(10.0, 2.4), -0.4, Color("a89880"))
			else:
				_quad(ci, xf, scale, Vector2(-8.0, 2.6), Vector2(10.0, 2.2), 0.0, Color("a89880"))
				_quad(ci, xf, scale, Vector2(-8.0, -2.6), Vector2(10.0, 2.2), 0.0, Color("a89880"))
				ci.draw_line(xf * (Vector2(-8.0, -2.6) * scale), xf * (Vector2(-8.0, 2.6) * scale), Color("5c5348"), maxf(1.0, 0.8 * scale), true)
		"sponson":
			if class_id == "anvil":
				_quad(ci, xf, scale, Vector2(-4.0, 18.0), Vector2(8.0, 5.0), 0.0, Color("8e8680"))
				_quad(ci, xf, scale, Vector2(-4.0, -18.0), Vector2(8.0, 5.0), 0.0, Color("8e8680"))
				ci.draw_line(xf * (Vector2(-2.0, 18.0) * scale), xf * (Vector2(8.0, 18.0) * scale), Color("1a1e24"), maxf(1.4, scale), true)
				ci.draw_line(xf * (Vector2(-2.0, -18.0) * scale), xf * (Vector2(8.0, -18.0) * scale), Color("1a1e24"), maxf(1.4, scale), true)
			elif class_id == "kestrel":
				ci.draw_line(xf * (Vector2(2.0, 6.0) * scale), xf * (Vector2(16.0, 12.0) * scale), Color("1a1e24"), maxf(1.6, scale), true)
				ci.draw_line(xf * (Vector2(2.0, -6.0) * scale), xf * (Vector2(16.0, -12.0) * scale), Color("1a1e24"), maxf(1.6, scale), true)
			else:
				_quad(ci, xf, scale, Vector2(12.0, 2.4), Vector2(6.0, 1.3), 0.0, Color("8e8680"))
				_quad(ci, xf, scale, Vector2(12.0, -2.4), Vector2(6.0, 1.3), 0.0, Color("8e8680"))
				ci.draw_line(xf * (Vector2(10.0, 2.4) * scale), xf * (Vector2(24.0, 2.4) * scale), Color("1a1e24"), maxf(1.2, 0.7 * scale), true)
				ci.draw_line(xf * (Vector2(10.0, -2.4) * scale), xf * (Vector2(24.0, -2.4) * scale), Color("1a1e24"), maxf(1.2, 0.7 * scale), true)
		"belt":
			var x_from := 14.0 if class_id != "anvil" else 10.0
			var x_to := -28.0 if class_id != "kestrel" else -20.0
			var plates := 7 if class_id != "anvil" else 5
			for i in plates:
				var t := float(i) / float(plates - 1)
				var x := lerpf(x_from, x_to, t)
				var beam := _half_beam(class_id, x)
				if beam < 1.0:
					continue
				var edge := atan2(_half_beam(class_id, x + 2.0) - _half_beam(class_id, x - 2.0), 4.0)
				var tone := Color("7a8490") if i % 2 == 0 else Color("454e58")
				var bite := 0.55 if class_id == "vesper" else 1.3 if class_id == "anvil" else 0.8
				_quad(ci, xf, scale, Vector2(x, beam - bite), Vector2(4.4, 1.5 if class_id != "anvil" else 2.4), edge, tone)
				_quad(ci, xf, scale, Vector2(x, -(beam - bite)), Vector2(4.4, 1.5 if class_id != "anvil" else 2.4), -edge, tone)
				_mark(ci, xf, scale, Vector2(x, beam - bite * 0.2), 0.28, Color("c6b48a"))
				_mark(ci, xf, scale, Vector2(x, -(beam - bite * 0.2)), 0.28, Color("c6b48a"))
		"pack":
			var cells := 6 if class_id == "vesper" else 4
			var span := 2.0 if class_id == "vesper" else 1.6
			var row := 1.35 if class_id == "vesper" else flank
			if class_id == "vesper":
				row = 1.35
			for i in cells:
				var x := along + (-float(cells) * 0.5 + float(i)) * span
				_mark(ci, xf, scale, Vector2(x, row if class_id == "vesper" else flank), 0.55, Color("d7dee4"))
				_mark(ci, xf, scale, Vector2(x, -row if class_id == "vesper" else flank + 1.4), 0.55 if class_id == "vesper" else 0.42, Color("d7dee4"))
				if i == cells - 1:
					_mark(ci, xf, scale, Vector2(x + 0.9, row if class_id == "vesper" else flank), 0.28, Color("d23b2a"))
			ci.draw_line(xf * (Vector2(along - 2.0, 0.0) * scale), xf * (Vector2(along - 6.0, 0.0) * scale), Color("14161a"), maxf(1.0, 0.7 * scale), true)
		"fans":
			if class_id == "anvil":
				_mark(ci, xf, scale, Vector2(along, flank - 1.2), 1.5, Color("c5ccd2"))
				_mark(ci, xf, scale, Vector2(along + 2.4, flank + 1.2), 1.5, Color("c5ccd2"))
				_mark(ci, xf, scale, Vector2(along, flank - 1.2), 0.35, Color("1c2228"))
				_mark(ci, xf, scale, Vector2(along + 2.4, flank + 1.2), 0.35, Color("1c2228"))
			else:
				_quad(ci, xf, scale, Vector2(along, flank), Vector2(3.2, 1.3), yaw, Color("d5dde4"))
				for i in 4:
					var fin := along - 1.2 + float(i) * 0.7
					ci.draw_line(xf * (Vector2(fin, flank - 0.5) * scale), xf * (Vector2(fin, flank + 0.5) * scale), Color("5c646c"), maxf(1.0, 0.4 * scale), true)
		"keel":
			var reach := 16.0 if class_id == "vesper" else 8.0
			_quad(ci, xf, scale, Vector2(along + reach * 0.35, 0.0), Vector2(reach, 1.1 if class_id != "anvil" else 3.2), 0.0, Color("8d9398"))
		"hold":
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(6.0, 2.2), yaw, Color("1f4e79"))
			_quad(ci, xf, scale, Vector2(along + 2.6, flank), Vector2(0.4, 1.4), yaw, Color("d7e6c8"))
		"hopper":
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(4.2, 2.6), yaw, Color("8c3a24"))
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(2.2, 1.2), yaw, Color("a34a2e"))
		"dome":
			_mark(ci, xf, scale, Vector2(along, flank), 2.2 if class_id == "anvil" else 1.5, Color("7eb8a2"))
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(3.2, 0.4), 0.0, Color("6d6558"))
		"ring":
			var rad := 8.0 if class_id == "vesper" else 14.0 if class_id == "anvil" else 7.0
			ci.draw_arc(xf * (Vector2(along, 0.0) * scale), rad * scale, 0.0, TAU, 28, Color("9ee7c8"), maxf(1.2, 0.8 * scale), true)
		"lamp":
			ci.draw_line(xf * (Vector2(along, 0.0) * scale), xf * (Vector2(along + 12.0, 0.0) * scale), Color("c4b49a"), maxf(1.0, 0.45 * scale), true)
			for i in 3:
				_mark(ci, xf, scale, Vector2(along + 2.0 + float(i) * 3.0, 0.0), 0.45, Color("e7d7a2"))
		"fighter":
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(5.5, 0.8), yaw, Color("d7e6c8"))
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(1.6, 2.2), yaw, Color("b7c4c0"))
		"lighter":
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(5.0, 2.0), yaw, Color("c4a882"))
		"beacon":
			_mark(ci, xf, scale, Vector2(along, flank), 0.9, Color("e7b15a"))
			ci.draw_line(xf * (Vector2(along, flank - 1.4) * scale), xf * (Vector2(along, flank + 1.4) * scale), Color("8a8274"), maxf(1.0, 0.4 * scale), true)
		"bell":
			_mark(ci, xf, scale, Vector2(along, flank), 1.2, Color("d7c48a"))
		"baffle":
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(4.4, 1.6), yaw, Color("6e6558"))
		"collar":
			ci.draw_arc(xf * (Vector2(along, 0.0) * scale), maxf(skin + 1.2, 2.2) * scale, 0.0, TAU, 16, Color("8d8680"), maxf(1.4, 0.7 * scale), true)
		"hook":
			ci.draw_line(xf * (Vector2(along, 0.0) * scale), xf * (Vector2(along + 3.5, 1.2) * scale), Color("c6b48a"), maxf(1.4, 0.8 * scale), true)
		"vault":
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(2.8, 2.0), yaw, Color("4a5560"))
			_mark(ci, xf, scale, Vector2(along + 0.4, flank), 0.55, Color("c6b48a"))
		"locker":
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(1.6, 2.4), yaw, Color("3e4650"))
		"stack":
			for i in 3:
				_quad(ci, xf, scale, Vector2(along, flank + float(i - 1) * 0.45), Vector2(3.0, 0.28), yaw, Color("7eb88a"))
		"scale":
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(3.4, 1.8), 0.0, Color("6a7a62"))
			_mark(ci, xf, scale, Vector2(along + 0.8, flank), 0.45, Color("d7c48a"))
		"pen":
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(4.0, 2.8), yaw, Color("8a6a48"))
		"coop":
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(3.2, 2.0), yaw, Color("8a6a48"))
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(3.6, 0.4), yaw, Color("6a3a2a"))
		"cage":
			_quad(ci, xf, scale, Vector2(along, flank * 0.4), Vector2(2.6, 1.8), 0.0, Color("5c6a62"))
		"shear":
			_quad(ci, xf, scale, Vector2(along + 2.0, 0.0), Vector2(4.5, 0.7), -0.15, Color("e7eef2"))
		"stakes":
			for i in 3:
				ci.draw_line(xf * (Vector2(along + float(i) * 0.7, flank) * scale), xf * (Vector2(along + float(i) * 0.7, flank + side * 2.2) * scale), Color("d7c48a"), maxf(1.0, 0.45 * scale), true)
		"probes":
			_quad(ci, xf, scale, Vector2(along, 0.0), Vector2(6.0, 1.2), 0.0, Color("b7c4c0"))
		_:
			_quad(ci, xf, scale, Vector2(along, flank), Vector2(2.4, 1.4), yaw, Color("7a7368"))
