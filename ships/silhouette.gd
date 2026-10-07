class_name Silhouette
extends RefCounted

## Top-down keel geometry. Modules append real shape; they are not stat stickers.
## The draw pass builds each hull from individual steel plates.


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
	if shapes.has("coil"):
		extras.append(PackedVector2Array([
			Vector2(50, 2.2), Vector2(100, 4.6), Vector2(100, 1.1), Vector2(50, 0.4)
		]))
		circles.append({"x": 64.0, "y": 3.2, "r": 3.4})
		circles.append({"x": 80.0, "y": 3.6, "r": 3.8})
		circles.append({"x": 96.0, "y": 3.4, "r": 3.0})
	if shapes.has("lance"):
		extras.append(PackedVector2Array([
			Vector2(48, 1.4), Vector2(124, 2.2), Vector2(124, 0.4), Vector2(48, -0.2)
		]))
		circles.append({"x": 78.0, "y": 1.6, "r": 2.4})
		circles.append({"x": 100.0, "y": 1.5, "r": 2.2})
		circles.append({"x": 118.0, "y": 1.2, "r": 2.6})
	if shapes.has("plate"):
		extras.append(PackedVector2Array([
			Vector2(16, 8), Vector2(18, 20), Vector2(-18, 22), Vector2(-22, 9)
		]))
		extras.append(PackedVector2Array([
			Vector2(16, -8), Vector2(18, -20), Vector2(-18, -22), Vector2(-22, -9)
		]))
	if shapes.has("composite"):
		extras.append(PackedVector2Array([
			Vector2(20, 7), Vector2(22, 26), Vector2(-22, 28), Vector2(-26, 8)
		]))
		extras.append(PackedVector2Array([
			Vector2(20, -7), Vector2(22, -26), Vector2(-22, -28), Vector2(-26, -8)
		]))
		extras.append(PackedVector2Array([
			Vector2(8, 12), Vector2(6, 18), Vector2(-8, 18), Vector2(-6, 12)
		]))
		extras.append(PackedVector2Array([
			Vector2(8, -12), Vector2(6, -18), Vector2(-8, -18), Vector2(-6, -12)
		]))
	var tail := 0.0
	if hull.size() > 0:
		tail = hull[0].x
		for point in hull:
			tail = minf(tail, point.x)
	if shapes.has("booster"):
		var aft := tail - 2.0
		extras.append(PackedVector2Array([
			Vector2(aft + 8.0, 5.0), Vector2(aft - 16.0, 12.0), Vector2(aft - 18.0, 3.5), Vector2(aft, 2.0)
		]))
		extras.append(PackedVector2Array([
			Vector2(aft + 8.0, -5.0), Vector2(aft - 16.0, -12.0), Vector2(aft - 18.0, -3.5), Vector2(aft, -2.0)
		]))
		circles.append({"x": aft - 12.0, "y": 8.0, "r": 3.2})
		circles.append({"x": aft - 12.0, "y": -8.0, "r": 3.2})
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


static func plate_grid(class_id: String) -> Vector2i:
	var cuts := _length_cuts(class_id)
	var rows := _row_count(class_id)
	if cuts.size() < 2 or rows < 1:
		return Vector2i(6, 2)
	return Vector2i(cuts.size() - 1, rows)


static func build_of(class_id: String) -> String:
	match class_id:
		"vesper":
			return "needle-spine"
		"anvil":
			return "hold-plates"
		"kestrel":
			return "beak-armor"
		"skiff":
			return "patchwork"
		"cutter":
			return "regulation"
		_:
			return "stock"


static func boat_grid(kind: String) -> Vector2i:
	match kind:
		"survey_probe":
			return Vector2i(6, 2)
		"harvest_drone":
			return Vector2i(4, 3)
		"salvage_tender":
			return Vector2i(5, 3)
		"away_shuttle":
			return Vector2i(5, 2)
		"fighter":
			return Vector2i(6, 2)
		"pathfinder":
			return Vector2i(7, 2)
		"prospector":
			return Vector2i(4, 3)
		_:
			return Vector2i(4, 2)


static func boat_build(kind: String) -> String:
	match kind:
		"survey_probe":
			return "probe-spine"
		"harvest_drone":
			return "claw-body"
		"salvage_tender":
			return "open-bay"
		"away_shuttle":
			return "cabin-glass"
		"fighter":
			return "gun-cheeks"
		"pathfinder":
			return "sensor-nose"
		"prospector":
			return "cutter-head"
		_:
			return "boat"


static func section_spans(hull: PackedVector2Array, x: float) -> Array:
	var ys: Array[float] = []
	var count := hull.size()
	for i in count:
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i + 1) % count]
		var crosses := (a.x <= x and b.x > x) or (b.x <= x and a.x > x)
		if not crosses:
			continue
		var t := (x - a.x) / (b.x - a.x)
		ys.append(lerpf(a.y, b.y, t))
	ys.sort()
	var spans: Array = []
	var index := 0
	while index + 1 < ys.size():
		var lo: float = ys[index]
		var hi: float = ys[index + 1]
		if hi - lo > 0.35:
			spans.append(Vector2(lo, hi))
		index += 2
	return spans


static func draw(ci: CanvasItem, origin: Vector2, rot: float, class_id: String, shapes: Array, scale: float, body: Color, accent: Color, hp_ratio: float = 1.0, thrusting: bool = false) -> void:
	var geom := parts(class_id, shapes)
	var hull: PackedVector2Array = geom.hull
	if hull.is_empty():
		return
	var xf := Transform2D(rot, origin)
	var paint := _paint(class_id, body, accent)
	var worn := clampf((1.0 - hp_ratio) * 0.82, 0.0, 0.82)
	_draw_shadow(ci, xf, hull, scale)
	_draw_thickness(ci, xf, hull, scale, paint)
	_draw_skin(ci, xf, hull, scale, paint)
	_draw_panels(ci, xf, hull, scale, plate_grid(class_id), class_id, paint, worn, true)
	_draw_rim(ci, xf, hull, scale)
	_draw_features(ci, xf, hull, scale, class_id, paint, accent)
	for extra in geom.extras:
		var poly: PackedVector2Array = extra
		_draw_hardware_poly(ci, xf, poly, scale, paint, worn)
	var tail := float(geom.tail)
	for circle in geom.circles:
		var at := Vector2(float(circle.x), float(circle.y))
		var center := xf * (at * scale)
		var radius := float(circle.r)
		if at.x < tail - 4.0:
			_draw_bell(ci, center, radius, scale, thrusting)
		elif radius >= 6.0:
			_draw_tank(ci, center, radius, scale, paint)
		else:
			_draw_collar(ci, center, radius, scale, paint)
	_draw_nozzles(ci, xf, hull, scale, thrusting, shapes.has("booster"))
	if hp_ratio < 0.72:
		var scar_a := xf * (Vector2(-10, -7) * scale)
		var scar_b := xf * (Vector2(14, 8) * scale)
		ci.draw_line(scar_a, scar_b, Color("140808"), 1.6, true)
		ci.draw_line(scar_a + xf.y * 1.4, scar_b + xf.y * 1.4, Color("5a2a22"), 0.8, true)


static func draw_boat(ci: CanvasItem, origin: Vector2, rot: float, kind: String, scale: float, body: Color) -> void:
	var hull := _boat_hull(kind)
	if hull.is_empty():
		return
	var xf := Transform2D(rot, origin)
	var paint := _paint(kind, body, body.lightened(0.35))
	_draw_shadow(ci, xf, hull, scale)
	_draw_thickness(ci, xf, hull, scale, paint)
	_draw_skin(ci, xf, hull, scale, paint)
	_draw_panels(ci, xf, hull, scale, boat_grid(kind), kind, paint, 0.0, false)
	_draw_rim(ci, xf, hull, scale)
	_draw_boat_feature(ci, xf, hull, scale, kind, paint)
	_draw_nozzles(ci, xf, hull, scale, false, false)


static func _paint(class_id: String, body: Color, accent: Color) -> Dictionary:
	var steel := Color("c5ced4")
	var mix := 0.28
	var grit := 0.16
	match class_id:
		"vesper", "survey_probe", "pathfinder":
			mix = 0.34
			grit = 0.1
			steel = Color("d5e0e4")
		"anvil", "salvage_tender", "prospector":
			mix = 0.46
			grit = 0.28
			steel = Color("b7b1a8")
		"kestrel", "fighter":
			mix = 0.18
			grit = 0.12
			steel = Color("c8cdd2")
		"skiff":
			mix = 0.22
			grit = 0.42
			steel = Color("8d8680")
		"cutter", "away_shuttle":
			mix = 0.3
			grit = 0.08
			steel = Color("c9d0cc")
		"harvest_drone":
			mix = 0.4
			grit = 0.2
			steel = Color("c4b7a4")
	var paint := steel.lerp(body, mix)
	return {
		"steel": steel,
		"paint": paint,
		"primer": Color("101418"),
		"seam": Color("07080a"),
		"accent": accent,
		"grit": grit,
		"glass": Color("8ec9d4"),
	}


static func _bounds_x(hull: PackedVector2Array) -> Vector2:
	var lo := float(hull[0].x)
	var hi := lo
	for point in hull:
		lo = minf(lo, point.x)
		hi = maxf(hi, point.x)
	return Vector2(lo, hi)


static func _length_cuts(class_id: String) -> PackedFloat32Array:
	match class_id:
		"vesper":
			return PackedFloat32Array([0.0, 0.05, 0.11, 0.19, 0.3, 0.44, 0.58, 0.72, 0.84, 0.93, 1.0])
		"anvil":
			return PackedFloat32Array([0.0, 0.08, 0.16, 0.28, 0.42, 0.55, 0.68, 0.8, 0.9, 1.0])
		"kestrel":
			return PackedFloat32Array([0.0, 0.09, 0.18, 0.3, 0.44, 0.58, 0.72, 0.86, 1.0])
		"skiff":
			return PackedFloat32Array([0.0, 0.16, 0.34, 0.5, 0.72, 1.0])
		"cutter":
			return PackedFloat32Array([0.0, 0.08, 0.18, 0.32, 0.46, 0.6, 0.74, 0.88, 1.0])
		_:
			return PackedFloat32Array()


static func _row_count(class_id: String) -> int:
	match class_id:
		"vesper":
			return 2
		"anvil":
			return 5
		"kestrel":
			return 3
		"skiff":
			return 2
		"cutter":
			return 3
		_:
			return 0


static func _draw_thickness(ci: CanvasItem, xf: Transform2D, hull: PackedVector2Array, scale: float, paint: Dictionary) -> void:
	var pts := PackedVector2Array()
	var off := Vector2(1.8, 2.5) * scale
	for point in hull:
		pts.append(xf * (point * scale) + off)
	if _area(pts) < 3.0:
		return
	var steel: Color = paint.steel
	ci.draw_colored_polygon(pts, steel.darkened(0.62))


static func _draw_shadow(ci: CanvasItem, xf: Transform2D, hull: PackedVector2Array, scale: float) -> void:
	var pts := PackedVector2Array()
	var off := Vector2(2.1, 2.8) * scale
	for point in hull:
		pts.append(xf * (point * scale) + off)
	if _area(pts) < 3.0:
		return
	ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.42))


static func _draw_skin(ci: CanvasItem, xf: Transform2D, hull: PackedVector2Array, scale: float, paint: Dictionary) -> void:
	var pts := _transform_poly(xf, hull, scale)
	if _area(pts) < 3.0:
		return
	ci.draw_colored_polygon(pts, paint.primer)


static func _draw_panels(ci: CanvasItem, xf: Transform2D, hull: PackedVector2Array, scale: float, grid: Vector2i, salt: String, paint: Dictionary, worn: float, hatches: bool) -> void:
	var bounds := _bounds_x(hull)
	if bounds.y - bounds.x < 1.0:
		return
	var cuts := _length_cuts(salt)
	var use_cuts := cuts.size() >= 2
	var cols := cuts.size() - 1 if use_cuts else maxi(grid.x, 1)
	var rows := _row_count(salt)
	if rows < 1:
		rows = maxi(grid.y, 1)
	for col in cols:
		var t0 := float(cuts[col]) if use_cuts else float(col) / float(cols)
		var t1 := float(cuts[col + 1]) if use_cuts else float(col + 1) / float(cols)
		var x0 := lerpf(bounds.x, bounds.y, t0)
		var x1 := lerpf(bounds.x, bounds.y, t1)
		var left: Array = section_spans(hull, lerpf(x0, x1, 0.2))
		var right: Array = section_spans(hull, lerpf(x0, x1, 0.8))
		if left.size() == right.size():
			for span_i in left.size():
				var span_l: Vector2 = left[span_i]
				var span_r: Vector2 = right[span_i]
				_draw_span_rows(ci, xf, scale, x0, x1, span_l, span_r, rows, col, span_i, salt, paint, worn, hatches, cols)
		else:
			_draw_flat_spans(ci, xf, scale, lerpf(x0, x1, 0.32), (x1 - x0) * 0.34, left, rows, col, salt, paint, worn, hatches, cols)
			_draw_flat_spans(ci, xf, scale, lerpf(x0, x1, 0.68), (x1 - x0) * 0.34, right, rows, col, salt, paint, worn, hatches, cols)


static func _draw_span_rows(ci: CanvasItem, xf: Transform2D, scale: float, x0: float, x1: float, span_l: Vector2, span_r: Vector2, rows: int, col: int, span_i: int, salt: String, paint: Dictionary, worn: float, hatches: bool, cols: int) -> void:
	var gap := 0.34
	for row in rows:
		var band_l := _band(span_l, row, rows, gap)
		var band_r := _band(span_r, row, rows, gap)
		if salt == "skiff" and col == 1 and row == 0:
			for rib in 3:
				var y := lerpf(band_l.x, band_l.y, float(rib) / 2.0)
				ci.draw_line(xf * (Vector2(x0 + 0.4, y) * scale), xf * (Vector2(x1 - 0.4, y) * scale), Color("6a5c4e"), 0.9, true)
			continue
		var along := float(col) / float(maxi(cols - 1, 1))
		var albedo := _plate_color(paint, salt, col, row + span_i * 3, along, worn, row, rows)
		var stagger := (x1 - x0) * 0.18
		var xa := x0 + 0.2 + (stagger if row % 2 == 1 else 0.0)
		var xb := x1 - 0.2 - (0.0 if row % 2 == 1 else stagger)
		var quad := PackedVector2Array([
			Vector2(xa, band_l.x),
			Vector2(xb, band_r.x),
			Vector2(xb, band_r.y),
			Vector2(xa, band_l.y),
		])
		_paint_plate(ci, xf, scale, quad, albedo, true, hatches and (col + row) % 3 == 1)


static func _draw_flat_spans(ci: CanvasItem, xf: Transform2D, scale: float, x: float, width: float, spans: Array, rows: int, col: int, salt: String, paint: Dictionary, worn: float, hatches: bool, cols: int) -> void:
	for span_i in spans.size():
		var span: Vector2 = spans[span_i]
		for row in rows:
			var band := _band(span, row, rows, 0.28)
			var along := float(col) / float(maxi(cols - 1, 1))
			var albedo := _plate_color(paint, salt, col, row, along, worn, row, rows)
			var quad := PackedVector2Array([
				Vector2(x - width * 0.5, band.x),
				Vector2(x + width * 0.5, band.x),
				Vector2(x + width * 0.5, band.y),
				Vector2(x - width * 0.5, band.y),
			])
			_paint_plate(ci, xf, scale, quad, albedo, true, hatches and row == 0)


static func _band(span: Vector2, row: int, rows: int, gap: float) -> Vector2:
	var height := (span.y - span.x) / float(rows)
	var a := span.x + height * float(row) + gap * 0.5
	var b := span.x + height * float(row + 1) - gap * 0.5
	if b - a < 0.3:
		var mid := (span.x + span.y) * 0.5
		return Vector2(mid - 0.16, mid + 0.16)
	return Vector2(a, b)


static func _plate_color(paint: Dictionary, salt: String, col: int, row: int, along: float, worn: float, row_i: int, rows: int) -> Color:
	var grit := _grit(col, row, salt.hash())
	var spread := float(paint.grit)
	var albedo: Color = paint.paint
	albedo = albedo.lerp(paint.steel, 0.18 + grit * 0.55)
	albedo = albedo.lerp(paint.paint.darkened(0.25), spread * grit)
	if col % 2 == 0:
		albedo = albedo.lightened(0.04)
	if salt == "kestrel" and (row_i == 0 or row_i == rows - 1):
		albedo = albedo.darkened(0.2)
	elif rows > 2 and (row_i == 0 or row_i == rows - 1):
		albedo = albedo.darkened(0.1)
	if salt == "kestrel" and along < 0.22:
		albedo = albedo.lerp(Color("6a4038"), 0.28)
	albedo = albedo.lerp(Color("e7eef2"), along * 0.12)
	albedo = albedo.lerp(Color("2a2420"), (1.0 - along) * 0.16)
	if salt == "skiff" and col == 2 and row == 0:
		albedo = Color("6e3b34")
	if salt == "cutter" and row_i == 0:
		albedo = albedo.lerp(Color("d7e6c8"), 0.55)
	albedo = albedo.lerp(Color("2a1210"), worn * (0.25 + grit * 0.55))
	return albedo


static func _grit(col: int, row: int, salt: int) -> float:
	var n := absi((col * 17 + row * 53 + salt * 13) % 97)
	return float(n) / 96.0


static func _paint_plate(ci: CanvasItem, xf: Transform2D, scale: float, ship_pts: PackedVector2Array, albedo: Color, rivets: bool, hatch: bool) -> void:
	var pts := _transform_poly(xf, ship_pts, scale)
	if pts.size() < 3 or _area(pts) < 1.6:
		return
	ci.draw_colored_polygon(pts, albedo)
	var center := Vector2.ZERO
	for point in pts:
		center += point
	center /= float(pts.size())
	var light := Vector2(-0.42, -0.9).normalized()
	if _area(pts) > 10.0:
		var sheen := PackedVector2Array()
		for point in pts:
			sheen.append(point.lerp(center - light * 3.0, 0.62))
		if _area(sheen) > 2.0:
			ci.draw_colored_polygon(sheen, Color(1, 1, 1, 0.16))
	if pts.size() >= 4 and _area(pts) > 16.0:
		for step in 3:
			var u := 0.28 + float(step) * 0.2
			var brush_a: Vector2 = pts[0].lerp(pts[3], u)
			var brush_b: Vector2 = pts[1].lerp(pts[2], u)
			ci.draw_line(brush_a, brush_b, Color(1, 1, 1, 0.08), 0.4, true)
	if _area(pts) > 26.0:
		var far := mini(2, pts.size() - 1)
		var scratch_a: Vector2 = pts[0].lerp(pts[far], 0.38)
		var scratch_b: Vector2 = pts[mini(1, pts.size() - 1)].lerp(center, 0.55)
		ci.draw_line(scratch_a, scratch_b, Color(1, 1, 1, 0.16), 0.55, true)
		ci.draw_line(scratch_a + light * 1.1, scratch_b + light * 0.4, Color(0, 0, 0, 0.28), 0.45, true)
	var count := pts.size()
	for i in count:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % count]
		var mid := (a + b) * 0.5
		var outward := mid - center
		if outward.length() < 0.001:
			continue
		var lit := outward.normalized().dot(light)
		if lit > 0.12:
			ci.draw_line(a, b, albedo.lightened(0.62).lerp(Color.WHITE, 0.28), maxf(0.9, scale * 0.75), true)
		elif lit < -0.12:
			ci.draw_line(a, b, Color(0.02, 0.025, 0.03, 0.9), maxf(0.8, scale * 0.6), true)
		if rivets and a.distance_to(b) > 8.0:
			var bead := clampf(sqrt(_area(pts)) * 0.055, 0.4, 0.9)
			for t in [0.33, 0.66]:
				var stud: Vector2 = a.lerp(b, t)
				ci.draw_circle(stud, bead, albedo.darkened(0.42))
				ci.draw_circle(stud - light * bead * 0.35, bead * 0.35, albedo.lightened(0.3))
	if rivets:
		var rr := clampf(sqrt(_area(pts)) * 0.075, 0.5, 1.25)
		for i in count:
			var corner: Vector2 = pts[i].lerp(center, 0.24)
			ci.draw_circle(corner, rr, albedo.darkened(0.48))
			ci.draw_circle(corner - light * rr * 0.4, rr * 0.36, albedo.lightened(0.35))
	if hatch and _area(pts) > 22.0:
		var door := PackedVector2Array()
		for point in pts:
			door.append(point.lerp(center, 0.46))
		if _area(door) > 4.0:
			ci.draw_colored_polygon(door, albedo.darkened(0.16))
			var frame := door.duplicate()
			frame.append(door[0])
			ci.draw_polyline(frame, albedo.darkened(0.4), 0.7, true)


static func _draw_rim(ci: CanvasItem, xf: Transform2D, hull: PackedVector2Array, scale: float) -> void:
	var pts := _transform_poly(xf, hull, scale)
	if pts.size() < 2:
		return
	var center := Vector2.ZERO
	for point in pts:
		center += point
	center /= float(pts.size())
	var light := Vector2(-0.42, -0.9).normalized()
	var count := pts.size()
	for i in count:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % count]
		var mid := (a + b) * 0.5
		var outward := mid - center
		if outward.length() < 0.001:
			continue
		var lit := outward.normalized().dot(light)
		var col := Color("f2f6f8") if lit > 0.05 else Color("050607")
		var width := 1.45 if lit > 0.05 else 1.15
		ci.draw_line(a, b, col, width, true)


static func _draw_features(ci: CanvasItem, xf: Transform2D, hull: PackedVector2Array, scale: float, class_id: String, paint: Dictionary, accent: Color) -> void:
	var steel: Color = paint.steel
	match class_id:
		"vesper":
			_raise(ci, xf, scale, PackedVector2Array([Vector2(-12, -0.55), Vector2(34, -0.55), Vector2(34, 0.55), Vector2(-12, 0.55)]), steel.lightened(0.12), 1.3)
			for fin in 3:
				var fx := -2.0 + float(fin) * 7.0
				_raise(ci, xf, scale, PackedVector2Array([Vector2(fx, 3.4), Vector2(fx + 4.2, 3.6), Vector2(fx + 3.4, 8.2), Vector2(fx + 0.4, 8.0)]), steel.lerp(Color("7aa0b0"), 0.45), 0.8)
				_raise(ci, xf, scale, PackedVector2Array([Vector2(fx, -3.4), Vector2(fx + 4.2, -3.6), Vector2(fx + 3.4, -8.2), Vector2(fx + 0.4, -8.0)]), steel.lerp(Color("7aa0b0"), 0.45), 0.8)
			_raise(ci, xf, scale, PackedVector2Array([Vector2(18, -2.3), Vector2(34, -2.3), Vector2(34, 2.3), Vector2(18, 2.3)]), Color("141c20"), 1.6)
			_ellipse(ci, xf, scale, Vector2(26, 0), 7.4, 1.7, paint.glass)
			ci.draw_line(xf * (Vector2(22, 0) * scale), xf * (Vector2(31, 0) * scale), Color("061014"), 0.8, true)
			ci.draw_line(xf * (Vector2(26, -1.3) * scale), xf * (Vector2(26, 1.3) * scale), Color("061014"), 0.7, true)
			var glass := xf * (Vector2(28.2, -0.35) * scale)
			ci.draw_circle(glass + Vector2(-1.3, -1.1) * scale, 1.2 * scale, Color(1, 1, 1, 0.78))
			_paint_plate(ci, xf, scale, PackedVector2Array([Vector2(4, 1.2), Vector2(15, 1.2), Vector2(15, 2.6), Vector2(4, 2.6)]), Color("12181c"), false, false)
			_paint_plate(ci, xf, scale, PackedVector2Array([Vector2(4, -2.6), Vector2(15, -2.6), Vector2(15, -1.2), Vector2(4, -1.2)]), Color("12181c"), false, false)
			ci.draw_line(xf * (Vector2(46, 0) * scale), xf * (Vector2(52, 0) * scale), steel, 0.8, true)
			ci.draw_circle(xf * (Vector2(52.6, 0) * scale), 0.7 * scale, Color("e7eef2"))
		"anvil":
			for col in 3:
				for row in 2:
					var x := -8.0 + float(col) * 9.0
					var y := -10.0 + float(row) * 14.0
					ci.draw_colored_polygon(_transform_poly(xf, PackedVector2Array([
						Vector2(x - 0.4, y - 0.4), Vector2(x + 6.4, y - 0.4), Vector2(x + 6.4, y + 8.6), Vector2(x - 0.4, y + 8.6)
					]), scale), Color(0.02, 0.015, 0.01, 0.72))
					_raise(ci, xf, scale, PackedVector2Array([
						Vector2(x, y), Vector2(x + 5.6, y), Vector2(x + 5.6, y + 7.6), Vector2(x, y + 7.6)
					]), steel.darkened(0.12), 1.1)
			for lane in 4:
				var yy := -8.0 + float(lane) * 5.0
				ci.draw_line(xf * (Vector2(-16, yy) * scale), xf * (Vector2(14, yy) * scale), Color(1, 1, 1, 0.14), 0.6, true)
			_raise(ci, xf, scale, PackedVector2Array([Vector2(6, -1.1), Vector2(10, -1.1), Vector2(10, 1.1), Vector2(6, 1.1)]), Color("5c564c"), 1.8)
			ci.draw_line(xf * (Vector2(8, 1) * scale), xf * (Vector2(8, 18) * scale), Color("3a342c"), 1.8, true)
			ci.draw_line(xf * (Vector2(8, 16) * scale), xf * (Vector2(16, 16) * scale), Color("6a6258"), 1.3, true)
			ci.draw_circle(xf * (Vector2(16, 16) * scale), 1.1 * scale, Color("cbb892"))
			for streak in 3:
				var sx := -18.0 + float(streak) * 10.0
				ci.draw_line(xf * (Vector2(sx, 6) * scale), xf * (Vector2(sx + 1.2, 18) * scale), Color("7a4030"), 1.1, true)
		"kestrel":
			_raise(ci, xf, scale, PackedVector2Array([Vector2(22, -1.6), Vector2(42, 0), Vector2(22, 1.6)]), steel.lightened(0.08), 1.5)
			_raise(ci, xf, scale, PackedVector2Array([Vector2(-4, -1.3), Vector2(18, -1.3), Vector2(18, 1.3), Vector2(-4, 1.3)]), steel.darkened(0.05), 1.2)
			var lamp := xf * (Vector2(14, 0) * scale)
			ci.draw_circle(lamp, 2.8 * scale, Color("120c0a"))
			ci.draw_arc(lamp, 2.8 * scale, 0.0, TAU, 12, steel.lightened(0.2), 1.1, true)
			ci.draw_circle(lamp, 1.55 * scale, accent)
			ci.draw_circle(lamp + Vector2(-0.45, -0.5) * scale, 0.5 * scale, Color(1, 0.95, 0.85, 0.85))
			ci.draw_line(xf * (Vector2(-2, 8) * scale), xf * (Vector2(8, 12) * scale), Color("1a1c1e"), 1.6, true)
			ci.draw_line(xf * (Vector2(-2, -8) * scale), xf * (Vector2(8, -12) * scale), Color("1a1c1e"), 1.6, true)
		"skiff":
			var weld := PackedVector2Array()
			for i in 7:
				var x := -6.0 + float(i) * 2.8
				var y := 0.8 if i % 2 == 0 else -0.4
				weld.append(xf * (Vector2(x, y) * scale))
			ci.draw_polyline(weld, Color("e6d2b0"), 1.25, true)
			for bolt in 4:
				var bx := -4.0 + float(bolt) * 3.5
				var stud := xf * (Vector2(bx, 2.4) * scale)
				ci.draw_circle(stud, 1.15 * scale, Color("4a4038"))
				ci.draw_circle(stud, 0.45 * scale, Color("c4b8a4"))
			ci.draw_line(xf * (Vector2(12, 0) * scale), xf * (Vector2(18, 3.2) * scale), Color("5a4038"), 1.2, true)
		"cutter":
			_raise(ci, xf, scale, PackedVector2Array([Vector2(0.5, -3.6), Vector2(8.2, -3.6), Vector2(8.2, 3.6), Vector2(0.5, 3.6)]), steel.darkened(0.08), 1.4)
			_ellipse(ci, xf, scale, Vector2(4.2, 0), 2.5, 2.5, paint.glass.darkened(0.15))
			ci.draw_arc(xf * (Vector2(4.2, 0) * scale), 2.5 * scale, 0.0, TAU, 14, steel.lightened(0.15), 0.9, true)
			ci.draw_circle(xf * (Vector2(4.7, -0.7) * scale), 0.65 * scale, Color(1, 1, 1, 0.7))
			_raise(ci, xf, scale, PackedVector2Array([Vector2(16, -1.4), Vector2(22, -1.4), Vector2(22, 1.4), Vector2(16, 1.4)]), Color("1c2422"), 1.0)
			ci.draw_circle(xf * (Vector2(21, 0) * scale), 0.9 * scale, Color("f2f6e8"))
			for i in 4:
				var port := xf * (Vector2(-8.0 + float(i) * 3.2, 4.2) * scale)
				ci.draw_circle(port, 1.05 * scale, Color("2a3030"))
				ci.draw_circle(port, 0.62 * scale, paint.glass)
				ci.draw_circle(port + Vector2(-0.2, -0.2) * scale, 0.18 * scale, Color(1, 1, 1, 0.7))
		_:
			pass


static func _raise(ci: CanvasItem, xf: Transform2D, scale: float, quad: PackedVector2Array, albedo: Color, lift: float) -> void:
	var off := Vector2(0.9, 1.2) * lift * scale
	var side := PackedVector2Array()
	for point in quad:
		side.append(xf * (point * scale) + off)
	if _area(side) >= 1.4:
		ci.draw_colored_polygon(side, albedo.darkened(0.48))
	_paint_plate(ci, xf, scale, quad, albedo, true, false)


static func _draw_boat_feature(ci: CanvasItem, xf: Transform2D, hull: PackedVector2Array, scale: float, kind: String, paint: Dictionary) -> void:
	match kind:
		"survey_probe", "pathfinder":
			_ellipse(ci, xf, scale, Vector2(6, 0), 2.4, 1.1, paint.glass)
			ci.draw_circle(xf * (Vector2(9.5, 0) * scale), 0.7 * scale, Color.WHITE)
		"harvest_drone":
			ci.draw_line(xf * (Vector2(4, 2.2) * scale), xf * (Vector2(8, 3.4) * scale), Color("5c564c"), 1.2, true)
			ci.draw_line(xf * (Vector2(4, -2.2) * scale), xf * (Vector2(8, -3.4) * scale), Color("5c564c"), 1.2, true)
		"salvage_tender":
			ci.draw_line(xf * (Vector2(-1, 0) * scale), xf * (Vector2(2, 6) * scale), Color("c47a4a"), 1.3, true)
			_paint_plate(ci, xf, scale, PackedVector2Array([Vector2(-4, -2), Vector2(1, -2), Vector2(1, 2), Vector2(-4, 2)]), Color("141210"), false, false)
		"away_shuttle":
			for i in 3:
				ci.draw_circle(xf * (Vector2(-1.0 + float(i) * 2.4, 1.6) * scale), 0.55 * scale, paint.glass)
		"fighter":
			ci.draw_line(xf * (Vector2(2, 1.4) * scale), xf * (Vector2(9, 1.6) * scale), Color("2a120e"), 1.3, true)
			ci.draw_circle(xf * (Vector2(6, 0) * scale), 0.8 * scale, Color("c4512c"))
		"prospector":
			_ellipse(ci, xf, scale, Vector2(5, 0), 2.2, 2.2, Color("3a2418"))
			ci.draw_circle(xf * (Vector2(5.4, 0) * scale), 0.9 * scale, Color("e07a3d"))
		_:
			pass


static func _draw_hardware_poly(ci: CanvasItem, xf: Transform2D, poly: PackedVector2Array, scale: float, paint: Dictionary, worn: float) -> void:
	if poly.size() < 3:
		return
	var bounds := _bounds_x(poly)
	if bounds.y - bounds.x < 4.0:
		var albedo: Color = paint.steel.lerp(paint.accent, 0.35)
		albedo = albedo.lerp(Color("2a1210"), worn * 0.4)
		_paint_plate(ci, xf, scale, poly, albedo, true, false)
		return
	var hardware := paint.duplicate()
	hardware.paint = paint.steel.lerp(paint.accent, 0.4)
	hardware.grit = float(paint.grit) * 0.5
	_draw_panels(ci, xf, poly, scale, Vector2i(5, 1), "hardware", hardware, worn, false)


static func _draw_nozzles(ci: CanvasItem, xf: Transform2D, hull: PackedVector2Array, scale: float, thrusting: bool, boosted: bool) -> void:
	var bounds := _bounds_x(hull)
	var x := bounds.x + 1.8
	var spans: Array = section_spans(hull, x)
	var reach := 22.0 if boosted else 14.0
	for span in spans:
		var width := float(span.y) - float(span.x)
		var seats: Array[float] = []
		if width > 7.0:
			seats.append(lerpf(span.x, span.y, 0.28))
			seats.append(lerpf(span.x, span.y, 0.72))
		else:
			seats.append((float(span.x) + float(span.y)) * 0.5)
		var radius := clampf(width * 0.16, 1.05, 3.1)
		for seat in seats:
			var at := xf * (Vector2(x, seat) * scale)
			_draw_bell(ci, at, radius, scale, thrusting)
			if thrusting:
				var flame := PackedVector2Array([
					xf * (Vector2(x + 0.4, seat + radius * 0.45) * scale),
					xf * (Vector2(x - reach, seat) * scale),
					xf * (Vector2(x + 0.4, seat - radius * 0.45) * scale),
				])
				ci.draw_colored_polygon(flame, Color("e07a3d"))
				var core := PackedVector2Array([
					xf * (Vector2(x + 0.2, seat + radius * 0.18) * scale),
					xf * (Vector2(x - reach * 0.62, seat) * scale),
					xf * (Vector2(x + 0.2, seat - radius * 0.18) * scale),
				])
				ci.draw_colored_polygon(core, Color("fff1c8"))


static func _draw_bell(ci: CanvasItem, center: Vector2, radius: float, scale: float, hot: bool) -> void:
	var r := radius * scale
	ci.draw_circle(center, r, Color("1a1e22"))
	ci.draw_arc(center, r * 0.86, -0.8, 2.2, 12, Color("e7eef2"), maxf(0.8, r * 0.22), true)
	ci.draw_circle(center, r * 0.48, Color("07080a"))
	if hot:
		ci.draw_circle(center, r * 0.28, Color("ffb15a"))


static func _draw_collar(ci: CanvasItem, center: Vector2, radius: float, scale: float, paint: Dictionary) -> void:
	var r := radius * scale
	var steel: Color = paint.steel
	ci.draw_arc(center, r, 0.0, TAU, 16, steel.lightened(0.2), maxf(0.7, r * 0.22), true)
	ci.draw_arc(center, r * 0.55, 0.0, TAU, 12, steel.darkened(0.4), maxf(0.55, r * 0.12), true)


static func _draw_tank(ci: CanvasItem, center: Vector2, radius: float, scale: float, paint: Dictionary) -> void:
	var r := radius * scale
	var steel: Color = paint.steel
	var skin: Color = steel.lerp(paint.paint, 0.4)
	ci.draw_circle(center, r, steel.darkened(0.28))
	ci.draw_circle(center, r * 0.8, skin)
	ci.draw_arc(center, r * 0.8, 0.2, PI - 0.2, 14, steel.lightened(0.35), maxf(1.0, r * 0.07), true)
	ci.draw_circle(center, r * 0.28, steel.darkened(0.35))
	ci.draw_circle(center + Vector2(-r * 0.28, -r * 0.3), r * 0.14, Color(1, 1, 1, 0.4))
	ci.draw_line(center + Vector2(-r * 0.15, 0), center + Vector2(r * 0.15, 0), steel.darkened(0.45), maxf(0.6, r * 0.05), true)


static func _ellipse(ci: CanvasItem, xf: Transform2D, scale: float, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var segs := 14
	for i in segs:
		var ang := TAU * float(i) / float(segs)
		pts.append(xf * ((center + Vector2(cos(ang) * rx, sin(ang) * ry)) * scale))
	if _area(pts) < 1.2:
		return
	ci.draw_colored_polygon(pts, color)


static func _boat_hull(kind: String) -> PackedVector2Array:
	match kind:
		"survey_probe":
			return PackedVector2Array([Vector2(12, 0), Vector2(2, 1.8), Vector2(-8, 1.2), Vector2(-8, -1.2), Vector2(2, -1.8)])
		"harvest_drone":
			return PackedVector2Array([Vector2(8, 0), Vector2(4, 3.2), Vector2(-6, 3.6), Vector2(-8, 0), Vector2(-6, -3.6), Vector2(4, -3.2)])
		"salvage_tender":
			return PackedVector2Array([Vector2(9, 0), Vector2(3, 4.2), Vector2(-7, 4.6), Vector2(-9, 1.2), Vector2(-9, -1.2), Vector2(-7, -4.6), Vector2(3, -4.2)])
		"away_shuttle":
			return PackedVector2Array([Vector2(8, 0), Vector2(3, 3.1), Vector2(-7, 3.4), Vector2(-8, 0), Vector2(-7, -3.4), Vector2(3, -3.1)])
		"fighter":
			return PackedVector2Array([Vector2(11, 0), Vector2(2, 3.6), Vector2(-5, 2.4), Vector2(-7, 0), Vector2(-5, -2.4), Vector2(2, -3.6)])
		"pathfinder":
			return PackedVector2Array([Vector2(14, 0), Vector2(4, 2.1), Vector2(-7, 1.6), Vector2(-9, 0), Vector2(-7, -1.6), Vector2(4, -2.1)])
		"prospector":
			return PackedVector2Array([Vector2(7, 0), Vector2(3, 3.4), Vector2(-5, 3.8), Vector2(-7, 0), Vector2(-5, -3.8), Vector2(3, -3.4)])
		_:
			return PackedVector2Array([Vector2(8, 0), Vector2(-6, 3), Vector2(-6, -3)])


static func _transform_poly(xf: Transform2D, hull: PackedVector2Array, scale: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for point in hull:
		pts.append(xf * (point * scale))
	return pts


static func _area(pts: PackedVector2Array) -> float:
	var sum := 0.0
	var count := pts.size()
	for i in count:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % count]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5
