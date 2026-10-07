class_name Silhouette
extends RefCounted

## Top-down keel geometry. Bolted modules are hardware on the hull, not accent stickers.


static func shapes_of(defs: Dictionary, module_ids: Array) -> Array:
	var shapes: Array = []
	for module_id in module_ids:
		var mod: Dictionary = defs.modules.get(module_id, {})
		shapes.append(str(mod.get("shape", "")))
	return shapes


static func parts(class_id: String, shapes: Array) -> Dictionary:
	var hull := _hull_of(class_id)
	var extras: Array = []
	var circles: Array = []
	var plan := _plan(hull, shapes)
	for key in ["mast", "blister", "sponson"]:
		var item: Dictionary = plan[key]
		if item.is_empty():
			continue
		var poly := PackedVector2Array()
		for point in item.bound:
			poly.append(point)
		if poly.size() >= 3:
			extras.append(poly)
		for circle in item.get("circles", []):
			circles.append(circle)
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
	var hull := _hull_of(class_id)
	if hull.is_empty():
		return
	var xf := Transform2D(rot, origin)
	var pal := _palette(body, accent, hp_ratio)
	var plan := _plan(hull, shapes)
	if not plan.blister.is_empty():
		_draw_blister_body(ci, xf, scale, plan.blister, pal)
	if not plan.sponson.is_empty():
		_draw_sponson_body(ci, xf, scale, plan.sponson, pal)
	_draw_hull(ci, xf, scale, hull, pal, accent)
	if not plan.mast.is_empty():
		_draw_mast(ci, xf, scale, plan.mast, pal, accent)
	if not plan.blister.is_empty():
		_draw_blister_fit(ci, xf, scale, plan.blister, pal, accent)
	if not plan.sponson.is_empty():
		_draw_sponson_fit(ci, xf, scale, plan.sponson, pal, accent)
	if hp_ratio < 0.72:
		var scar_a := xf * (Vector2(-10, -7) * scale)
		var scar_b := xf * (Vector2(14, 8) * scale)
		ci.draw_line(scar_a, scar_b, Color("140808"), maxf(1.4, scale * 0.35), true)
	if thrusting:
		_draw_plumes(ci, xf, scale, hull)


static func draw_fitted(ci: CanvasItem, box: Vector2, class_id: String, shapes: Array, fit_shapes: Array, body: Color, accent: Color, hp_ratio: float, rotation: float) -> void:
	if box.x < 8.0 or box.y < 8.0:
		return
	var margin := 12.0
	var fit_bounds := _bounds(parts(class_id, fit_shapes))
	var span := _rotated_size(fit_bounds, rotation)
	var fit_scale := minf((box.x - margin) / maxf(span.x, 1.0), (box.y - margin) / maxf(span.y, 1.0))
	fit_scale = clampf(fit_scale, 0.25, 8.0)
	var drawn := _bounds(parts(class_id, shapes))
	var center := drawn.get_center()
	var origin := box * 0.5 - Transform2D(rotation, Vector2.ZERO) * (center * fit_scale)
	draw(ci, origin, rotation, class_id, shapes, fit_scale, body, accent, hp_ratio, false)


static func _hull_of(class_id: String) -> PackedVector2Array:
	match class_id:
		"vesper":
			return PackedVector2Array([
				Vector2(52, 0), Vector2(18, 5), Vector2(-22, 3.5),
				Vector2(-40, 1.4), Vector2(-40, -1.4), Vector2(-22, -3.5), Vector2(18, -5)
			])
		"anvil":
			return PackedVector2Array([
				Vector2(26, 0), Vector2(22, 12), Vector2(10, 22), Vector2(-18, 24),
				Vector2(-34, 14), Vector2(-34, -14), Vector2(-18, -24), Vector2(10, -22), Vector2(22, -12)
			])
		"kestrel":
			return PackedVector2Array([
				Vector2(48, 0), Vector2(12, 7), Vector2(-6, 16), Vector2(-28, 10),
				Vector2(-22, 0), Vector2(-28, -10), Vector2(-6, -16), Vector2(12, -7)
			])
		"skiff":
			return PackedVector2Array([
				Vector2(22, 0), Vector2(4, 8), Vector2(-16, 5), Vector2(-16, -5), Vector2(4, -8)
			])
		"cutter":
			return PackedVector2Array([
				Vector2(30, 0), Vector2(8, 10), Vector2(-18, 12), Vector2(-24, 0),
				Vector2(-18, -12), Vector2(8, -10)
			])
		_:
			return PackedVector2Array([Vector2(16, 0), Vector2(-12, 8), Vector2(-12, -8)])


static func _palette(body: Color, accent: Color, hp_ratio: float) -> Dictionary:
	var soot := Color("3a1818")
	var wear := clampf((1.0 - hp_ratio) * 0.7, 0.0, 0.7)
	var pod := Color("d9cdb8").lerp(body, 0.14)
	var armor := body.lerp(Color("4a5564"), 0.62)
	return {
		"body": body.lerp(soot, wear),
		"body_dark": body.darkened(0.42).lerp(soot, wear),
		"body_light": body.lightened(0.14).lerp(soot, wear * 0.45),
		"seam": body.darkened(0.55).lerp(soot, wear),
		"accent": accent.lerp(soot, wear * 0.35),
		"graphite": Color("3a3833").lerp(soot, wear * 0.35),
		"graphite_lit": Color("7c7568").lerp(soot, wear * 0.25),
		"ceramic": Color("e6dfd2").lerp(soot, wear * 0.2),
		"dish": Color("7a8491").lerp(soot, wear * 0.25),
		"dish_deep": Color("2a3138").lerp(soot, wear * 0.15),
		"glass": Color("102226").lerp(soot, wear * 0.15),
		"glass_lit": Color("b7e0d4").lerp(soot, wear * 0.2),
		"brass": Color("c6b48a").lerp(soot, wear * 0.3),
		"barrel": Color("1c2128").lerp(soot, wear * 0.25),
		"barrel_lit": Color("a0a8b4").lerp(soot, wear * 0.2),
		"pod": pod.lerp(soot, wear * 0.35),
		"pod_lit": Color("f4ecdf").lerp(body, 0.08).lerp(soot, wear * 0.25),
		"pod_dark": Color("6a5e50").lerp(soot, wear * 0.3),
		"hatch": Color("161310").lerp(soot, wear * 0.15),
		"gasket": Color("6d5b46").lerp(soot, wear * 0.25),
		"armor": armor.lerp(soot, wear * 0.3),
		"armor_edge": armor.lightened(0.22).lerp(soot, wear * 0.25),
		"shadow": Color(0, 0, 0, 0.4),
	}


static func _plan(hull: PackedVector2Array, shapes: Array) -> Dictionary:
	return {
		"mast": _plan_mast(hull) if shapes.has("mast") else {},
		"blister": _plan_blister(hull) if shapes.has("blister") else {},
		"sponson": _plan_sponson(hull) if shapes.has("sponson") else {},
	}


static func _plan_mast(hull: PackedVector2Array) -> Dictionary:
	var nose := _nose(hull)
	var reach := 34.0
	var dish_r := 8.1
	var root := nose + Vector2(1.2, 0)
	var tip := nose + Vector2(reach, 0)
	var dish := nose + Vector2(23.5, 0)
	var radome := nose + Vector2(reach + 1.6, 0)
	var plate_half := clampf(_side_y(hull, nose.x - 7.0, 1.0) + 1.15, 1.7, 4.2)
	var array_c := nose + Vector2(12.5, -6.4)
	var bound := [
		nose + Vector2(-11.0, plate_half),
		nose + Vector2(reach + 8.5, 2.4),
		nose + Vector2(23.5, dish_r),
		array_c + Vector2(5.2, -3.3),
		array_c + Vector2(-5.2, -3.3),
		nose + Vector2(23.5, -dish_r),
		nose + Vector2(-11.0, -plate_half),
	]
	return {
		"nose": nose,
		"root": root,
		"tip": tip,
		"dish": dish,
		"dish_r": dish_r,
		"radome": radome,
		"plate_half": plate_half,
		"array": array_c,
		"bound": bound,
		"circles": [
			{"x": dish.x, "y": dish.y, "r": dish_r},
			{"x": radome.x + 6.4, "y": 2.3, "r": 0.6},
		],
	}


static func _plan_blister(hull: PackedVector2Array) -> Dictionary:
	var xs: Array = _station_xs(hull, 0.34, 0.30)
	var proud := [12.4, 14.8, 15.6, 14.8, 12.4]
	var sides: Array = []
	var bound: Array = []
	for raw_sign in [1.0, -1.0]:
		var sign := float(raw_sign)
		var stations: Array = []
		for i in xs.size():
			var x := float(xs[i])
			var skin := _side_y(hull, x, sign)
			var y_in := skin - sign * 4.0
			var y_out := skin + sign * float(proud[i])
			stations.append({"x": x, "skin": skin, "y_in": y_in, "y_out": y_out})
			bound.append(Vector2(x, y_in))
			bound.append(Vector2(x, y_out))
		var cap := _cap_radius(stations[0])
		bound.append(Vector2(float(stations[0].x) - cap, (float(stations[0].y_in) + float(stations[0].y_out)) * 0.5))
		cap = _cap_radius(stations[stations.size() - 1])
		var last: Dictionary = stations[stations.size() - 1]
		bound.append(Vector2(float(last.x) + cap, (float(last.y_in) + float(last.y_out)) * 0.5))
		sides.append({"sign": sign, "stations": stations})
	return {"sides": sides, "bound": bound, "circles": []}


static func _plan_sponson(hull: PackedVector2Array) -> Dictionary:
	var span := _span_x(hull)
	var length := maxf(span.y - span.x, 8.0)
	var xs: Array = _station_xs(hull, 0.20, 0.26)
	var proud := [5.4, 9.2, 13.0, 8.6, 5.8]
	var muzzle_x := minf(span.y - length * 0.08, float(xs[xs.size() - 1]) + maxf(18.0, length * 0.28))
	var sides: Array = []
	var bound: Array = []
	for raw_sign in [1.0, -1.0]:
		var sign := float(raw_sign)
		var stations: Array = []
		for i in xs.size():
			var x := float(xs[i])
			var skin := _side_y(hull, x, sign)
			var y_in := skin - sign * 3.4
			var y_out := skin + sign * float(proud[i])
			stations.append({"x": x, "skin": skin, "y_in": y_in, "y_out": y_out})
			bound.append(Vector2(x, y_out))
		var mid: Dictionary = stations[2]
		var barrel_y := float(mid.y_out) - sign * 2.4
		var muzzle := Vector2(muzzle_x, barrel_y)
		bound.append(muzzle + Vector2(2.2, sign * 4.6))
		bound.append(Vector2(float(stations[0].x), float(stations[0].y_in)))
		sides.append({
			"sign": sign,
			"stations": stations,
			"barrel_y": barrel_y,
			"muzzle_x": muzzle_x,
		})
	return {"sides": sides, "bound": bound, "circles": []}


static func _station_xs(hull: PackedVector2Array, aft_bias: float, fwd_bias: float) -> Array:
	var span := _span_x(hull)
	var length := maxf(span.y - span.x, 8.0)
	var widest := _widest_x(hull)
	var x0 := clampf(widest - length * aft_bias, span.x + length * 0.07, span.y - length * 0.24)
	var x1 := clampf(widest + length * fwd_bias, x0 + length * 0.16, span.y - length * 0.05)
	if x1 < x0 + 8.0:
		x1 = minf(span.y - 1.0, x0 + 8.0)
	var mid := clampf(widest, x0 + 0.8, x1 - 0.8)
	return [x0, lerpf(x0, mid, 0.55), mid, lerpf(mid, x1, 0.5), x1]


static func _skin_at(stations: Array, x: float) -> float:
	var prev: Dictionary = stations[0]
	if x <= float(prev.x):
		return float(prev.skin)
	for station in stations:
		var sx := float(station.x)
		if sx >= x:
			var span := sx - float(prev.x)
			if span < 0.001:
				return float(station.skin)
			return lerpf(float(prev.skin), float(station.skin), (x - float(prev.x)) / span)
		prev = station
	return float(prev.skin)


static func _cap_radius(station: Dictionary) -> float:
	return absf(float(station.y_out) - float(station.y_in)) * 0.5


static func _draw_hull(ci: CanvasItem, xf: Transform2D, scale: float, hull: PackedVector2Array, pal: Dictionary, accent: Color) -> void:
	_poly(ci, xf, scale, _array_of(hull), pal.body_dark)
	var inset := _inset(hull, 0.11)
	if inset.size() >= 3:
		_poly(ci, xf, scale, _array_of(inset), pal.body)
	var core := _inset(hull, 0.24)
	if core.size() >= 3:
		_poly(ci, xf, scale, _array_of(core), pal.body_light)
	_draw_frames(ci, xf, scale, hull, pal)
	_draw_bridge(ci, xf, scale, hull, pal)
	_draw_nozzles(ci, xf, scale, hull, pal, false)
	_stroke(ci, xf, scale, _array_of(hull), accent.darkened(0.22), _px(scale) * 1.15, true)


static func _draw_frames(ci: CanvasItem, xf: Transform2D, scale: float, hull: PackedVector2Array, pal: Dictionary) -> void:
	var span := _span_x(hull)
	var nose := _nose(hull)
	_line(ci, xf, scale, Vector2(span.x + 3.0, 0), nose + Vector2(-6.0, 0), pal.seam, _px(scale))
	for raw_t in [0.28, 0.46, 0.64]:
		var t := float(raw_t)
		var x := lerpf(span.x, span.y, t)
		var y := _side_y(hull, x, 1.0) * 0.78
		if y > 1.2:
			_line(ci, xf, scale, Vector2(x, -y), Vector2(x, y), pal.seam, _px(scale))


static func _draw_bridge(ci: CanvasItem, xf: Transform2D, scale: float, hull: PackedVector2Array, pal: Dictionary) -> void:
	var nose := _nose(hull)
	var station := nose.x - 9.0
	var skin := _side_y(hull, station, 1.0)
	if skin < 0.6:
		station = nose.x - 5.0
		skin = _side_y(hull, station, 1.0)
	var half := minf(maxf(skin * 0.46, 0.55), 3.5)
	if half > skin - 0.35:
		half = maxf(skin * 0.5, 0.4)
	var aft := nose.x - maxf(skin, 2.0) * 1.6
	var glass := [
		Vector2(nose.x - 3.2, 0),
		Vector2(lerpf(nose.x, aft, 0.45), half),
		Vector2(aft, half * 0.55),
		Vector2(aft, -half * 0.55),
		Vector2(lerpf(nose.x, aft, 0.45), -half),
	]
	_poly(ci, xf, scale, glass, pal.glass)
	_line(ci, xf, scale, glass[1], glass[4], pal.glass_lit, _px(scale))
	_stroke(ci, xf, scale, glass, pal.seam, _px(scale), true)


static func _draw_nozzles(ci: CanvasItem, xf: Transform2D, scale: float, hull: PackedVector2Array, pal: Dictionary, hot: bool) -> void:
	for nozzle in _nozzles(hull):
		var center: Vector2 = nozzle.center
		var radius := float(nozzle.radius)
		_circ(ci, xf, scale, center, radius, pal.body_dark)
		_circ(ci, xf, scale, center, radius * 0.62, Color("12100e") if not hot else Color("e07a32"))
		_circ(ci, xf, scale, center, radius * 0.28, Color("2a241c") if not hot else Color("f6e2b0"))
		_stroke_circle(ci, xf, scale, center, radius, pal.seam)


static func _draw_plumes(ci: CanvasItem, xf: Transform2D, scale: float, hull: PackedVector2Array) -> void:
	for nozzle in _nozzles(hull):
		var center: Vector2 = nozzle.center
		var radius := float(nozzle.radius)
		var reach := 11.0 + radius * 2.4
		var outer := [
			center + Vector2(1.2, radius * 0.85),
			center + Vector2(-reach, 0),
			center + Vector2(1.2, -radius * 0.85),
		]
		var inner := [
			center + Vector2(0.6, radius * 0.38),
			center + Vector2(-reach * 0.62, 0),
			center + Vector2(0.6, -radius * 0.38),
		]
		_poly(ci, xf, scale, outer, Color("e07a32"))
		_poly(ci, xf, scale, inner, Color("f6e2b0"))


static func _nozzles(hull: PackedVector2Array) -> Array:
	var span := _span_x(hull)
	var aft: Array = []
	for point in hull:
		if point.x <= span.x + 3.2:
			aft.append(point)
	if aft.is_empty():
		return [{"center": Vector2(span.x + 2.0, 0), "radius": 1.6}]
	var spread := 0.0
	for point in aft:
		spread = maxf(spread, absf(point.y))
	if spread < 3.2:
		var mid := Vector2.ZERO
		for point in aft:
			mid += point
		mid /= float(aft.size())
		return [{"center": mid + Vector2(2.6, 0), "radius": clampf(spread + 0.8, 1.05, 1.8)}]
	var nozzles: Array = []
	for point in aft:
		var inward := -signf(point.y) * minf(absf(point.y) * 0.16, 2.6)
		var radius := clampf(absf(point.y) * 0.16, 1.8, 3.4)
		nozzles.append({
			"center": Vector2(point.x + radius + 0.8, point.y + inward),
			"radius": radius,
		})
	return nozzles


static func _draw_mast(ci: CanvasItem, xf: Transform2D, scale: float, plan: Dictionary, pal: Dictionary, accent: Color) -> void:
	var nose: Vector2 = plan.nose
	var root: Vector2 = plan.root
	var tip: Vector2 = plan.tip
	var dish: Vector2 = plan.dish
	var dish_r := float(plan.dish_r)
	var radome: Vector2 = plan.radome
	var plate_half := float(plan.plate_half)
	var array_c: Vector2 = plan.array
	var collar := nose + Vector2(-0.4, 0)
	_circ(ci, xf, scale, collar, plate_half + 1.8, pal.graphite)
	_stroke_circle(ci, xf, scale, collar, plate_half + 1.8, pal.graphite_lit)
	_circ(ci, xf, scale, collar, plate_half * 0.45, pal.body_dark)
	var shoe := [
		nose + Vector2(-10.5, plate_half),
		nose + Vector2(2.4, plate_half * 0.72),
		nose + Vector2(2.4, -plate_half * 0.72),
		nose + Vector2(-10.5, -plate_half),
	]
	_poly(ci, xf, scale, shoe, pal.graphite)
	_stroke(ci, xf, scale, shoe, pal.graphite_lit, _px(scale), true)
	for raw_x in [-8.2, -4.6, -1.2]:
		var bolt_x := float(raw_x)
		_bolt(ci, xf, scale, nose + Vector2(bolt_x, plate_half * 0.62), pal)
		_bolt(ci, xf, scale, nose + Vector2(bolt_x, -plate_half * 0.62), pal)
	_poly(ci, xf, scale, [
		nose + Vector2(-1.0, plate_half * 0.55),
		root + Vector2(1.4, 1.35),
		root + Vector2(1.4, -1.35),
		nose + Vector2(-1.0, -plate_half * 0.55),
	], pal.accent.darkened(0.15))
	_truss(ci, xf, scale, root, tip, 2.05, 1.2, pal.graphite, pal.graphite_lit)
	var boom_anchor := Vector2(array_c.x, root.y)
	_strut(ci, xf, scale, boom_anchor, array_c, 0.95, pal.graphite)
	_circ(ci, xf, scale, boom_anchor, 1.2, pal.graphite_lit)
	_bolt(ci, xf, scale, boom_anchor, pal)
	var array := _round_rect(array_c, 5.4, 3.15, 0.7)
	_poly(ci, xf, scale, array, pal.glass)
	_stroke(ci, xf, scale, array, pal.graphite_lit, _px(scale), true)
	for i in 4:
		var y := array_c.y - 2.2 + float(i) * 1.45
		_line(ci, xf, scale, Vector2(array_c.x - 4.6, y), Vector2(array_c.x + 4.6, y), pal.glass_lit.darkened(0.35), _px(scale) * 0.8)
	for i in 3:
		var x := array_c.x - 3.2 + float(i) * 3.2
		_line(ci, xf, scale, Vector2(x, array_c.y - 2.5), Vector2(x, array_c.y + 2.5), pal.glass_lit.darkened(0.35), _px(scale) * 0.8)
	_poly(ci, xf, scale, _round_rect(array_c + Vector2(2.3, -1.15), 0.7, 0.45, 0.15), pal.glass_lit)
	_circ(ci, xf, scale, dish, dish_r, pal.ceramic)
	_circ(ci, xf, scale, dish, dish_r * 0.84, pal.dish)
	_circ(ci, xf, scale, dish, dish_r * 0.56, pal.dish.darkened(0.18))
	_circ(ci, xf, scale, dish, dish_r * 0.3, pal.dish_deep)
	_strut(ci, xf, scale, dish + Vector2(-dish_r * 0.62, -dish_r * 0.5), dish, 0.28, pal.graphite_lit)
	_strut(ci, xf, scale, dish + Vector2(-dish_r * 0.62, dish_r * 0.5), dish, 0.28, pal.graphite_lit)
	_strut(ci, xf, scale, dish + Vector2(dish_r * 0.72, 0), dish, 0.28, pal.graphite_lit)
	_poly(ci, xf, scale, _round_rect(dish + Vector2(1.5, 0), 1.15, 0.55, 0.2), pal.brass.darkened(0.1))
	_circ(ci, xf, scale, dish, dish_r * 0.12, pal.brass)
	_stroke_circle(ci, xf, scale, dish, dish_r, pal.graphite)
	for raw_corner in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		var corner := raw_corner as Vector2
		_bolt(ci, xf, scale, dish + corner * dish_r * 0.72, pal)
	_circ(ci, xf, scale, radome, 2.55, pal.ceramic.darkened(0.08))
	_circ(ci, xf, scale, radome + Vector2(-0.7, -0.7), 0.7, pal.ceramic)
	_stroke_circle(ci, xf, scale, radome, 2.55, pal.graphite_lit)
	_line(ci, xf, scale, radome + Vector2(-2.3, 0.4), radome + Vector2(2.3, 0.4), pal.graphite, _px(scale))
	_draw_whip(ci, xf, scale, radome + Vector2(1.6, 0.2), 0.42, pal)
	_draw_whip(ci, xf, scale, radome + Vector2(1.6, -0.2), -0.38, pal)
	_circ(ci, xf, scale, tip + Vector2(-1.2, 1.15), 0.55, pal.glass_lit)


static func _draw_whip(ci: CanvasItem, xf: Transform2D, scale: float, root: Vector2, angle: float, pal: Dictionary) -> void:
	var dir := Vector2.from_angle(angle)
	var tip := root + dir * 7.4
	_strut(ci, xf, scale, root, tip, 0.22, pal.graphite_lit)
	_circ(ci, xf, scale, root + dir * 4.4, 0.42, pal.ceramic)
	_circ(ci, xf, scale, tip, 0.36, pal.glass_lit)


static func _draw_blister_body(ci: CanvasItem, xf: Transform2D, scale: float, plan: Dictionary, pal: Dictionary) -> void:
	for side in plan.sides:
		var sign := float(side.sign)
		var stations: Array = side.stations
		var skin_tone: Color = pal.pod.darkened(0.06) if sign > 0.0 else pal.pod.lightened(0.04)
		_pod_shell(ci, xf, scale, stations, pal.pod_dark, pal.shadow, Vector2(-0.8, sign * 1.5), false)
		_pod_shell(ci, xf, scale, stations, pal.pod_dark, pal.pod_dark, Vector2.ZERO, true)
		_pod_shell(ci, xf, scale, _station_inset(stations, 1.8), skin_tone, skin_tone, Vector2.ZERO, false)
		_pod_shell(ci, xf, scale, _station_inset(stations, 4.6), pal.pod_lit, pal.pod_lit, Vector2.ZERO, false)
		_pod_grooves(ci, xf, scale, stations, pal)
		_pod_hatch(ci, xf, scale, stations, sign, pal)


static func _draw_blister_fit(ci: CanvasItem, xf: Transform2D, scale: float, plan: Dictionary, pal: Dictionary, accent: Color) -> void:
	for side in plan.sides:
		var sign := float(side.sign)
		var stations: Array = side.stations
		_seam(ci, xf, scale, stations, pal)
		for raw_index in [1, 2, 3]:
			var index := int(raw_index)
			var station: Dictionary = stations[index]
			var x := float(station.x)
			var skin := float(station.skin)
			var doubler := [
				Vector2(x - 3.6, skin - sign * 7.4),
				Vector2(x + 3.6, skin - sign * 7.4),
				Vector2(x + 3.6, skin - sign * 0.2),
				Vector2(x - 3.6, skin - sign * 0.2),
			]
			_poly(ci, xf, scale, doubler, pal.body_light)
			_stroke(ci, xf, scale, doubler, pal.seam, _px(scale), true)
			_poly(ci, xf, scale, [
				Vector2(x - 2.05, skin - sign * 6.4),
				Vector2(x + 2.05, skin - sign * 6.4),
				Vector2(x + 2.05, skin + sign * 7.2),
				Vector2(x - 2.05, skin + sign * 7.2),
			], pal.graphite)
			_poly(ci, xf, scale, [
				Vector2(x - 0.55, skin - sign * 6.0),
				Vector2(x + 0.55, skin - sign * 6.0),
				Vector2(x + 0.55, skin + sign * 6.6),
				Vector2(x - 0.55, skin + sign * 6.6),
			], pal.graphite_lit)
			_bolt(ci, xf, scale, Vector2(x - 1.7, skin - sign * 4.6), pal)
			_bolt(ci, xf, scale, Vector2(x + 1.7, skin - sign * 4.6), pal)
			_bolt(ci, xf, scale, Vector2(x, skin + sign * 3.2), pal)
			_poly(ci, xf, scale, _round_rect(Vector2(x, skin + sign * 0.4), 1.15, 0.7, 0.15), accent.darkened(0.05))
		var nose_station: Dictionary = stations[stations.size() - 1]
		var pipe_x := float(nose_station.x) - 1.6
		var skin_f := float(nose_station.skin)
		_strut(ci, xf, scale, Vector2(pipe_x, skin_f - sign * 1.4), Vector2(pipe_x, skin_f + sign * 4.8), 0.55, pal.graphite_lit)
		_circ(ci, xf, scale, Vector2(pipe_x, skin_f + sign * 5.6), 1.35, pal.graphite)
		_line(ci, xf, scale, Vector2(pipe_x - 0.9, skin_f + sign * 5.6), Vector2(pipe_x + 0.9, skin_f + sign * 5.6), pal.brass, _px(scale))
		_line(ci, xf, scale, Vector2(pipe_x, skin_f + sign * 4.7), Vector2(pipe_x, skin_f + sign * 6.5), pal.brass, _px(scale))
		for station in stations:
			_bolt(ci, xf, scale, Vector2(float(station.x), float(station.skin) + sign * 1.3), pal)


static func _pod_shell(ci: CanvasItem, xf: Transform2D, scale: float, stations: Array, fill: Color, shadow: Color, shift: Vector2, rim: bool = true) -> void:
	for i in stations.size() - 1:
		var a: Dictionary = stations[i]
		var b: Dictionary = stations[i + 1]
		_poly(ci, xf, scale, [
			Vector2(float(a.x), float(a.y_in)) + shift,
			Vector2(float(b.x), float(b.y_in)) + shift,
			Vector2(float(b.x), float(b.y_out)) + shift,
			Vector2(float(a.x), float(a.y_out)) + shift,
		], shadow if shift != Vector2.ZERO else fill)
	_end_cap(ci, xf, scale, stations[0], false, shadow if shift != Vector2.ZERO else fill, shift)
	_end_cap(ci, xf, scale, stations[stations.size() - 1], true, shadow if shift != Vector2.ZERO else fill, shift)
	if rim and shift == Vector2.ZERO:
		_outer_rim(ci, xf, scale, stations, fill.darkened(0.35))


static func _station_inset(stations: Array, edge: float) -> Array:
	var out: Array = []
	for station in stations:
		var y_in := float(station.y_in)
		var y_out := float(station.y_out)
		var sign := 1.0 if y_out >= y_in else -1.0
		out.append({
			"x": station.x,
			"skin": station.skin,
			"y_in": y_in + sign * edge * 0.2,
			"y_out": y_out - sign * edge,
		})
	return out


static func _outer_rim(ci: CanvasItem, xf: Transform2D, scale: float, stations: Array, color: Color) -> void:
	var pts: Array = []
	for station in stations:
		pts.append(Vector2(float(station.x), float(station.y_out)))
	_stroke(ci, xf, scale, pts, color, _px(scale), false)
	var first: Dictionary = stations[0]
	var last: Dictionary = stations[stations.size() - 1]
	_line(ci, xf, scale, Vector2(float(first.x), float(first.y_in)), Vector2(float(first.x), float(first.y_out)), color, _px(scale))
	_line(ci, xf, scale, Vector2(float(last.x), float(last.y_in)), Vector2(float(last.x), float(last.y_out)), color, _px(scale))


static func _end_cap(ci: CanvasItem, xf: Transform2D, scale: float, station: Dictionary, forward: bool, color: Color, shift: Vector2) -> void:
	var y_in := float(station.y_in)
	var y_out := float(station.y_out)
	var mid := (y_in + y_out) * 0.5
	var radius := absf(y_out - y_in) * 0.5
	var center := Vector2(float(station.x), mid) + shift
	var a0 := -PI * 0.5 if forward else PI * 0.5
	var a1 := PI * 0.5 if forward else PI * 1.5
	_poly(ci, xf, scale, _arc_poly(center, radius, a0, a1, 7), color)


static func _pod_grooves(ci: CanvasItem, xf: Transform2D, scale: float, stations: Array, pal: Dictionary) -> void:
	for raw_t in [0.22, 0.4, 0.62, 0.8]:
		var t := float(raw_t)
		for i in stations.size() - 1:
			var a: Dictionary = stations[i]
			var b: Dictionary = stations[i + 1]
			var a_lo := lerpf(float(a.y_in), float(a.y_out), t - 0.018)
			var a_hi := lerpf(float(a.y_in), float(a.y_out), t + 0.018)
			var b_lo := lerpf(float(b.y_in), float(b.y_out), t - 0.018)
			var b_hi := lerpf(float(b.y_in), float(b.y_out), t + 0.018)
			_poly(ci, xf, scale, [
				Vector2(float(a.x), a_lo),
				Vector2(float(b.x), b_lo),
				Vector2(float(b.x), b_hi),
				Vector2(float(a.x), a_hi),
			], pal.pod_dark)


static func _pod_hatch(ci: CanvasItem, xf: Transform2D, scale: float, stations: Array, sign: float, pal: Dictionary) -> void:
	var a: Dictionary = stations[1]
	var b: Dictionary = stations[3]
	var x0 := lerpf(float(a.x), float(b.x), 0.08)
	var x1 := lerpf(float(a.x), float(b.x), 0.92)
	var mid_x := (x0 + x1) * 0.5
	var sample: Dictionary = stations[2]
	var inner := float(sample.skin) + sign * 2.2
	var outer := float(sample.y_out) - sign * 2.4
	var mid_y := (inner + outer) * 0.5
	var hw := (x1 - x0) * 0.5
	var hh := absf(outer - inner) * 0.5
	if hw < 2.0 or hh < 1.6:
		return
	var hatch := _round_rect(Vector2(mid_x, mid_y), hw, hh, minf(1.1, hh * 0.35))
	_poly(ci, xf, scale, hatch, pal.hatch)
	var gasket := _round_rect(Vector2(mid_x, mid_y), hw - 0.7, hh - 0.55, 0.6)
	_stroke(ci, xf, scale, gasket, pal.gasket, _px(scale), true)
	_stroke(ci, xf, scale, hatch, pal.graphite_lit, _px(scale), true)
	var hinge_x := x0 + 1.1
	var latch_x := x1 - 1.3
	for raw_t in [0.25, 0.5, 0.75]:
		var t := float(raw_t)
		var y := lerpf(inner, outer, t)
		_circ(ci, xf, scale, Vector2(hinge_x, y), 0.7, pal.brass.darkened(0.15))
		_poly(ci, xf, scale, _round_rect(Vector2(latch_x, y), 0.7, 0.38, 0.12), pal.brass)
	for raw_corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner := raw_corner as Vector2
		var cx := mid_x + corner.x * (hw - 1.3)
		var cy := mid_y + corner.y * (hh - 1.0)
		_poly(ci, xf, scale, _round_rect(Vector2(cx, cy), 0.85, 0.7, 0.12), pal.graphite_lit)
	var plate := _round_rect(Vector2(mid_x, mid_y + sign * hh * 0.15), hw * 0.42, hh * 0.22, 0.3)
	_poly(ci, xf, scale, plate, pal.pod_dark)
	_line(ci, xf, scale, Vector2(mid_x - hw * 0.28, mid_y), Vector2(mid_x + hw * 0.22, mid_y), pal.gasket, _px(scale))


static func _seam(ci: CanvasItem, xf: Transform2D, scale: float, stations: Array, pal: Dictionary) -> void:
	var pts: Array = []
	for station in stations:
		pts.append(Vector2(float(station.x), float(station.skin)))
	_stroke(ci, xf, scale, pts, Color(0, 0, 0, 0.65), _px(scale) * 1.2, false)


static func _draw_sponson_body(ci: CanvasItem, xf: Transform2D, scale: float, plan: Dictionary, pal: Dictionary) -> void:
	for side in plan.sides:
		var sign := float(side.sign)
		var stations: Array = side.stations
		var fill: Color = pal.armor.darkened(0.06) if sign > 0.0 else pal.armor.lightened(0.08)
		for i in stations.size() - 1:
			var a: Dictionary = stations[i]
			var b: Dictionary = stations[i + 1]
			_poly(ci, xf, scale, [
				Vector2(float(a.x) - 0.4, float(a.y_in) + sign * 1.5),
				Vector2(float(b.x) + 0.4, float(b.y_in) + sign * 1.5),
				Vector2(float(b.x) + 0.4, float(b.y_out) + sign * 1.4),
				Vector2(float(a.x) - 0.4, float(a.y_out) + sign * 1.4),
			], pal.shadow)
		for i in stations.size() - 1:
			var a: Dictionary = stations[i]
			var b: Dictionary = stations[i + 1]
			_poly(ci, xf, scale, [
				Vector2(float(a.x), float(a.y_in)),
				Vector2(float(b.x), float(b.y_in)),
				Vector2(float(b.x), float(b.y_out)),
				Vector2(float(a.x), float(a.y_out)),
			], fill)
		var outer: Array = []
		for station in stations:
			outer.append(Vector2(float(station.x), float(station.y_out)))
		_stroke(ci, xf, scale, outer, pal.armor_edge, _px(scale), false)
		var inset_edge: Array = []
		for station in stations:
			inset_edge.append(Vector2(float(station.x), float(station.y_out) - sign * 2.2))
		_stroke(ci, xf, scale, inset_edge, pal.armor.lightened(0.12), _px(scale), false)


static func _draw_sponson_fit(ci: CanvasItem, xf: Transform2D, scale: float, plan: Dictionary, pal: Dictionary, accent: Color) -> void:
	for side in plan.sides:
		var sign := float(side.sign)
		var stations: Array = side.stations
		var seat: Dictionary = stations[2]
		var turret := Vector2(float(seat.x) + 1.4, float(side.barrel_y))
		var muzzle_x := float(side.muzzle_x)
		var x0 := turret.x - 7.2
		var x1 := turret.x + 8.4
		var outer := float(side.barrel_y) + sign * 6.6
		var cheek := [
			Vector2(x0, _skin_at(stations, x0) - sign * 3.4),
			Vector2(x1, _skin_at(stations, x1) - sign * 3.4),
			Vector2(x1, outer),
			Vector2(x0, outer),
		]
		_poly(ci, xf, scale, cheek, pal.armor)
		_stroke(ci, xf, scale, cheek, pal.armor_edge, _px(scale), true)
		for raw_dx in [-4.6, -1.4, 2.2, 5.4]:
			var dx := float(raw_dx)
			var bolt_x := turret.x + dx
			_bolt(ci, xf, scale, Vector2(bolt_x, _skin_at(stations, bolt_x) - sign * 1.35), pal)
		var ring := 5.2
		_circ(ci, xf, scale, turret, ring, pal.armor_edge)
		_circ(ci, xf, scale, turret, ring * 0.74, pal.armor.darkened(0.08))
		_circ(ci, xf, scale, turret, ring * 0.42, pal.barrel)
		_stroke_circle(ci, xf, scale, turret, ring, pal.graphite_lit)
		for i in 6:
			var angle := TAU * float(i) / 6.0
			_bolt(ci, xf, scale, turret + Vector2(cos(angle), sin(angle)) * ring * 0.84, pal)
		var house := _round_rect(turret + Vector2(3.4, 0), 4.2, 3.3, 0.45)
		_poly(ci, xf, scale, house, pal.barrel.lightened(0.1))
		_stroke(ci, xf, scale, house, pal.armor_edge, _px(scale), true)
		_poly(ci, xf, scale, _round_rect(turret + Vector2(3.2, -sign * 1.5), 2.2, 0.42, 0.1), accent)
		var spread := 1.85
		_draw_barrel(ci, xf, scale, turret + Vector2(0.2, sign * spread), Vector2(muzzle_x, turret.y + sign * spread), 1.45, pal)
		_draw_barrel(ci, xf, scale, turret + Vector2(0.2, -sign * spread), Vector2(muzzle_x, turret.y - sign * spread), 1.45, pal)
		_poly(ci, xf, scale, _round_rect(turret + Vector2(4.6, sign * 3.15), 1.05, 0.5, 0.12), Color("0c0e12"))


static func _draw_barrel(ci: CanvasItem, xf: Transform2D, scale: float, root: Vector2, muzzle: Vector2, radius: float, pal: Dictionary) -> void:
	var delta := muzzle - root
	var length := delta.length()
	if length < 1.0:
		return
	var dir := delta / length
	var side := Vector2(-dir.y, dir.x)
	var lit := side if side.y < 0.0 else -side
	_poly(ci, xf, scale, [
		root + side * radius,
		muzzle + side * radius * 0.9,
		muzzle - side * radius * 0.9,
		root - side * radius,
	], pal.barrel)
	_poly(ci, xf, scale, [
		root + lit * radius * 0.1,
		muzzle + lit * radius * 0.08,
		muzzle + lit * radius * 0.62,
		root + lit * radius * 0.7,
	], pal.barrel_lit)
	var brake := muzzle - dir * radius * 2.1
	_poly(ci, xf, scale, [
		brake + side * radius * 1.28,
		muzzle + dir * 0.8 + side * radius * 1.4,
		muzzle + dir * 0.8 - side * radius * 1.4,
		brake - side * radius * 1.28,
	], pal.barrel.lightened(0.06))
	_line(ci, xf, scale, brake + dir * 0.7 + side * radius * 0.15, brake + dir * 0.7 + side * radius * 1.25, Color("0c0e12"), _px(scale))
	_line(ci, xf, scale, brake + dir * 1.3 - side * radius * 0.15, brake + dir * 1.3 - side * radius * 1.25, Color("0c0e12"), _px(scale))
	_line(ci, xf, scale, root + dir * 1.4, muzzle - dir * 0.3, Color("07080c"), maxf(_px(scale), 1.2))
	_circ(ci, xf, scale, muzzle + dir * 0.5, radius * 0.32, Color("050608"))
	_stroke(ci, xf, scale, [
		root + side * radius,
		muzzle + side * radius * 0.9,
		muzzle - side * radius * 0.9,
		root - side * radius,
	], pal.armor_edge, _px(scale), true)


static func _span_x(hull: PackedVector2Array) -> Vector2:
	var lo := hull[0].x
	var hi := hull[0].x
	for point in hull:
		lo = minf(lo, point.x)
		hi = maxf(hi, point.x)
	return Vector2(lo, hi)


static func _nose(hull: PackedVector2Array) -> Vector2:
	var best := hull[0]
	for point in hull:
		if point.x > best.x:
			best = point
	return best


static func _widest_x(hull: PackedVector2Array) -> float:
	var best_x := hull[0].x
	var best_y := -1.0
	for point in hull:
		if absf(point.y) > best_y:
			best_y = absf(point.y)
			best_x = point.x
	return best_x


static func _side_y(hull: PackedVector2Array, x: float, side: float) -> float:
	var best := 0.0
	var hit := false
	var count := hull.size()
	for i in count:
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i + 1) % count]
		var min_x := minf(a.x, b.x)
		var max_x := maxf(a.x, b.x)
		if x < min_x - 0.001 or x > max_x + 0.001:
			continue
		var y: float
		if absf(b.x - a.x) < 0.0001:
			y = a.y if (side > 0.0) == (a.y > b.y) else b.y
		else:
			y = lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
		var on_side := (side > 0.0 and y >= -0.02) or (side < 0.0 and y <= 0.02)
		if not on_side:
			continue
		if not hit or (side > 0.0 and y > best) or (side < 0.0 and y < best):
			best = y
			hit = true
	return best


static func _inset(hull: PackedVector2Array, fraction: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point in hull:
		center += point
	center /= float(hull.size())
	var out := PackedVector2Array()
	for point in hull:
		out.append(point.lerp(center, fraction))
	return out


static func _bounds(geom: Dictionary) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var lists: Array = [geom.hull]
	lists.append_array(geom.extras)
	for poly in lists:
		for point in poly:
			lo.x = minf(lo.x, point.x)
			lo.y = minf(lo.y, point.y)
			hi.x = maxf(hi.x, point.x)
			hi.y = maxf(hi.y, point.y)
	for circle in geom.circles:
		var c := Vector2(float(circle.x), float(circle.y))
		var radius := float(circle.r)
		lo.x = minf(lo.x, c.x - radius)
		lo.y = minf(lo.y, c.y - radius)
		hi.x = maxf(hi.x, c.x + radius)
		hi.y = maxf(hi.y, c.y + radius)
	if lo.x > hi.x:
		return Rect2(0, 0, 1, 1)
	return Rect2(lo, hi - lo)


static func _rotated_size(bounds: Rect2, rotation: float) -> Vector2:
	var xf := Transform2D(rotation, Vector2.ZERO)
	var corners: Array = [
		bounds.position,
		bounds.position + Vector2(bounds.size.x, 0),
		bounds.position + Vector2(0, bounds.size.y),
		bounds.position + bounds.size,
	]
	var lo: Vector2 = xf * corners[0]
	var hi := lo
	for corner in corners:
		var turned: Vector2 = xf * corner
		lo = lo.min(turned)
		hi = hi.max(turned)
	return hi - lo


static func _array_of(poly: PackedVector2Array) -> Array:
	var pts: Array = []
	for point in poly:
		pts.append(point)
	return pts


static func _truss(ci: CanvasItem, xf: Transform2D, scale: float, a: Vector2, b: Vector2, half_a: float, half_b: float, metal: Color, lit: Color) -> void:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	_strut(ci, xf, scale, a + n * half_a, b + n * half_b, 0.7, metal)
	_strut(ci, xf, scale, a - n * half_a, b - n * half_b, 0.7, lit)
	var steps := 4
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		var h0 := lerpf(half_a, half_b, t0)
		var h1 := lerpf(half_a, half_b, t1)
		if i % 2 == 0:
			_strut(ci, xf, scale, p0 + n * h0, p1 - n * h1, 0.46, metal)
		else:
			_strut(ci, xf, scale, p0 - n * h0, p1 + n * h1, 0.46, lit)


static func _strut(ci: CanvasItem, xf: Transform2D, scale: float, a: Vector2, b: Vector2, half: float, color: Color) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.05:
		return
	var n := Vector2(-delta.y, delta.x) / length * half
	_poly(ci, xf, scale, [a + n, b + n, b - n, a - n], color)


static func _round_rect(center: Vector2, hw: float, hh: float, rad: float) -> Array:
	var radius := minf(rad, minf(hw, hh))
	var pts: Array = []
	var corners: Array = [
		[Vector2(hw - radius, hh - radius), 0.0],
		[Vector2(-hw + radius, hh - radius), PI * 0.5],
		[Vector2(-hw + radius, -hh + radius), PI],
		[Vector2(hw - radius, -hh + radius), PI * 1.5],
	]
	for corner in corners:
		var origin: Vector2 = corner[0]
		var a0: float = corner[1]
		for i in 4:
			var angle := a0 + PI * 0.5 * float(i) / 3.0
			pts.append(center + origin + Vector2(cos(angle), sin(angle)) * radius)
	return pts


static func _arc_poly(center: Vector2, radius: float, a0: float, a1: float, segs: int) -> Array:
	var pts: Array = [center]
	for i in segs + 1:
		var angle := lerpf(a0, a1, float(i) / float(segs))
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts


static func _poly(ci: CanvasItem, xf: Transform2D, scale: float, pts: Array, color: Color) -> void:
	if pts.size() < 3:
		return
	var out := PackedVector2Array()
	for point in pts:
		out.append(xf * ((point as Vector2) * scale))
	ci.draw_colored_polygon(out, color)


static func _line(ci: CanvasItem, xf: Transform2D, scale: float, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	ci.draw_line(xf * (a * scale), xf * (b * scale), color, maxf(width, 1.0), true)


static func _stroke(ci: CanvasItem, xf: Transform2D, scale: float, pts: Array, color: Color, width: float, close: bool) -> void:
	if pts.size() < 2:
		return
	var out := PackedVector2Array()
	for point in pts:
		out.append(xf * ((point as Vector2) * scale))
	if close:
		out.append(out[0])
	ci.draw_polyline(out, color, maxf(width, 1.0), true)


static func _circ(ci: CanvasItem, xf: Transform2D, scale: float, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.05:
		return
	ci.draw_circle(xf * (center * scale), radius * scale, color)


static func _stroke_circle(ci: CanvasItem, xf: Transform2D, scale: float, center: Vector2, radius: float, color: Color) -> void:
	var pts: Array = []
	for i in 16:
		var angle := TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	_stroke(ci, xf, scale, pts, color, _px(scale), true)


static func _bolt(ci: CanvasItem, xf: Transform2D, scale: float, point: Vector2, pal: Dictionary) -> void:
	var radius := 0.95
	_circ(ci, xf, scale, point, radius, (pal.brass as Color).darkened(0.5))
	_circ(ci, xf, scale, point, radius * 0.68, pal.brass)
	var slot := Vector2(0.62, 0.18) * radius
	_line(ci, xf, scale, point - slot, point + slot, (pal.brass as Color).darkened(0.55), _px(scale) * 0.85)


static func _px(scale: float) -> float:
	return clampf(0.9 + scale * 0.16, 1.0, 2.5)
