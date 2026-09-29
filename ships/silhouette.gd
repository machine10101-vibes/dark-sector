class_name Silhouette
extends RefCounted

## Top-down keel geometry. Modules append real shape; they are not stat stickers.


static func shapes_of(defs: Dictionary, module_ids: Array) -> Array:
	var shapes: Array = []
	for module_id in module_ids:
		var mod: Dictionary = defs.modules.get(module_id, {})
		shapes.append(str(mod.get("shape", "")))
	return shapes


static func parts(class_id: String, shapes: Array) -> Dictionary:
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
	if shapes.has("mast"):
		extras.append(PackedVector2Array([
			Vector2(46, 1.6), Vector2(86, 0), Vector2(46, -1.6)
		]))
	if shapes.has("blister"):
		circles.append({"x": -4.0, "y": 32.0, "r": 11.0})
		circles.append({"x": -4.0, "y": -32.0, "r": 11.0})
		extras.append(PackedVector2Array([
			Vector2(-2, 20), Vector2(6, 24), Vector2(-10, 24)
		]))
		extras.append(PackedVector2Array([
			Vector2(-2, -20), Vector2(6, -24), Vector2(-10, -24)
		]))
	if shapes.has("sponson"):
		extras.append(PackedVector2Array([
			Vector2(4, 10), Vector2(16, 26), Vector2(-8, 22), Vector2(-6, 12)
		]))
		extras.append(PackedVector2Array([
			Vector2(4, -10), Vector2(16, -26), Vector2(-8, -22), Vector2(-6, -12)
		]))
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


static func draw(ci: CanvasItem, origin: Vector2, rot: float, class_id: String, shapes: Array, scale: float, body: Color, accent: Color, hp_ratio: float = 1.0, thrusting: bool = false) -> void:
	var geom := parts(class_id, shapes)
	var hull: PackedVector2Array = geom.hull
	if hull.is_empty():
		return
	var xf := Transform2D(rot, origin)
	var worn := body.lerp(Color("3a1818"), clampf((1.0 - hp_ratio) * 0.75, 0.0, 0.75))
	var pts := PackedVector2Array()
	for point in hull:
		pts.append(xf * (point * scale))
	ci.draw_colored_polygon(pts, worn)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, accent.darkened(0.15), 1.4, true)
	for extra in geom.extras:
		var extra_pts := PackedVector2Array()
		for point in extra:
			extra_pts.append(xf * (point * scale))
		if extra_pts.size() >= 3:
			ci.draw_colored_polygon(extra_pts, accent)
	for circle in geom.circles:
		var center := xf * (Vector2(float(circle.x), float(circle.y)) * scale)
		ci.draw_circle(center, float(circle.r) * scale, accent)
	if hp_ratio < 0.72:
		var scar_a := xf * (Vector2(-10, -7) * scale)
		var scar_b := xf * (Vector2(14, 8) * scale)
		ci.draw_line(scar_a, scar_b, Color("140808"), 1.6, true)
	if thrusting:
		var tail := float(geom.tail)
		var flame := PackedVector2Array([
			xf * (Vector2(tail + 2.0, 4.0) * scale),
			xf * (Vector2(tail - 16.0, 0.0) * scale),
			xf * (Vector2(tail + 2.0, -4.0) * scale),
		])
		ci.draw_colored_polygon(flame, Color("e7b15a"))
