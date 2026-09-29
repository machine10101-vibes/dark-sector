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
	ci.draw_colored_polygon(_inset_world(pts, 1.1 * scale, lit * (1.0 * scale)), worn.darkened(0.16))
	ci.draw_colored_polygon(_inset_world(pts, 2.6 * scale, lit * (3.0 * scale)), worn.lightened(0.06))
	ci.draw_colored_polygon(_inset_world(pts, 4.4 * scale, lit * (5.2 * scale)), worn.lightened(0.26))
	var spec := _centroid(pts) + lit * (5.5 * scale)
	var tangent := Vector2(-lit.y, lit.x)
	ci.draw_line(spec - tangent * (2.8 * scale), spec + tangent * (0.8 * scale) + lit * (1.6 * scale), Color(1, 0.97, 0.9, 0.62), maxf(1.0, 0.9 * scale), true)
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
	for extra in geom.extras:
		var extra_pts := PackedVector2Array()
		for point in extra:
			extra_pts.append(xf * (point * scale))
		if extra_pts.size() >= 3:
			ci.draw_colored_polygon(extra_pts, accent.darkened(0.38))
			ci.draw_colored_polygon(_inset_world(extra_pts, 1.1 * scale, lit * (0.8 * scale)), accent.darkened(0.08))
			ci.draw_colored_polygon(_inset_world(extra_pts, 2.2 * scale, lit * (1.8 * scale)), accent.lightened(0.18))
			var mid_i := int(extra_pts.size() / 2)
			ci.draw_line(extra_pts[0], extra_pts[mid_i], accent.darkened(0.5), 1.0, true)
			_rim(ci, extra_pts, lit, accent.lightened(0.35), 1.0)
	for circle in geom.circles:
		var center := xf * (Vector2(float(circle.x), float(circle.y)) * scale)
		var rad := float(circle.r) * scale
		ci.draw_circle(center, rad, accent.darkened(0.42))
		ci.draw_circle(center + lit * rad * 0.22, rad * 0.78, accent.darkened(0.08))
		ci.draw_circle(center + lit * rad * 0.4, rad * 0.42, accent.lightened(0.16))
		ci.draw_circle(center + lit * rad * 0.48, rad * 0.16, Color(1, 1, 1, 0.32))
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
		ci.draw_colored_polygon(haze, Color(0.91, 0.55, 0.22, 0.45))
		ci.draw_colored_polygon(flame, Color("e7b15a"))
		ci.draw_colored_polygon(core, Color("fff1d2"))
		ci.draw_circle(xf * (Vector2(tail - 7.0, 0.0) * scale), 3.4 * scale, Color(1.0, 0.62, 0.28, 0.28))


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
	ci.draw_circle(xf * (Vector2(2.2, -0.4) * scale), 0.55 * scale, Color(0.85, 0.92, 0.88, 0.5))


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
