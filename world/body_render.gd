class_name BodyRender
extends RefCounted

## Top-down volumetric draw for ore, torn hull, derelicts, and the plasma gatherer.
## Facets are lit from Ash Lamp so a rock reads as a body, not a sticker.


static func bake(node: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(node.get("seed", 1))
	var kind := str(node.get("kind", "meteor"))
	var size := float(node.get("size", 24.0))
	if kind == "derelict":
		node.visual = _bake_derelict(rng, size)
	elif kind == "wreckage":
		node.visual = _bake_wreck(rng, size, int(node.get("variant", 0)))
	else:
		node.visual = _bake_meteor(rng, size)


static func draw_node(ci: CanvasItem, sim, node: Dictionary, view: Rect2, zoom: float) -> void:
	var pos: Vector2 = node.pos
	var size := float(node.size)
	if not view.grow(size * 4.0 + 80.0).has_point(pos):
		return
	if node.get("visual") == null:
		bake(node)
	var gathering := bool(sim.gather.get("active", false)) and str(sim.gather.get("target", "")) == str(node.id)
	var shake := Vector2.ZERO
	if gathering:
		var mag := 0.7 + float(sim.gather.progress) * 2.4 + float(sim.gather.flash) * 3.0
		shake = Vector2(sin(sim.time * 48.0), cos(sim.time * 39.0)) * mag
	var origin := pos + shake
	var rot: float = float(node.rot) + float(sim.time) * float(node.spin)
	var spent := PlasmaHarvest.remaining(node) <= 0
	var mat := PlasmaHarvest.material_of(sim, str(node.material))
	if size * zoom < 6.2:
		_draw_simple(ci, origin, size, mat, spent, sim, node)
		return
	match str(node.kind):
		"derelict":
			_draw_derelict(ci, sim, node, origin, rot, spent, gathering)
		"wreckage":
			_draw_wreck(ci, sim, node, origin, rot, mat, spent, gathering)
		_:
			_draw_meteor(ci, sim, node, origin, rot, mat, spent, gathering)
	_draw_mark(ci, sim, node, pos, size, mat, gathering)


static func draw_matter(ci: CanvasItem, sim) -> void:
	if sim.player == null or not bool(sim.player.get("alive", false)):
		return
	var pose := aim_pose(sim)
	_draw_tool(ci, sim, pose)
	if float(pose.extend) < 0.08 or not bool(pose.active):
		return
	var a: Vector2 = pose.muzzle
	var b: Vector2 = pose.impact
	var pts := _curve(a, b, float(sim.time), float(pose.extend))
	var extend := float(pose.extend)
	_strip(ci, pts, 7.5 * extend, Color(0.25, 0.55, 1.0, 0.22))
	_strip(ci, pts, 3.4 * extend, Color(0.55, 0.88, 1.0, 0.55))
	_strip(ci, pts, 1.35 * extend, Color(0.96, 0.98, 1.0, 0.95))
	_draw_chunks(ci, sim, pose)


static func draw_beam(ci: CanvasItem, sim) -> void:
	if sim.player == null or not bool(sim.player.get("alive", false)):
		return
	var pose := aim_pose(sim)
	if float(pose.extend) < 0.05:
		return
	_draw_tool_glow(ci, pose)
	if not bool(pose.active):
		return
	var a: Vector2 = pose.muzzle
	var b: Vector2 = pose.impact
	var pts := _curve(a, b, sim.time, float(pose.extend))
	var flicker := 0.82 + 0.18 * sin(sim.time * 54.0)
	var extend := float(pose.extend) * flicker
	_strip(ci, pts, 16.0 * extend, Color(0.45, 0.18, 0.95, 0.09))
	_strip(ci, pts, 9.0 * extend, Color(0.2, 0.55, 1.0, 0.12))
	_strip(ci, pts, 4.2 * extend, Color(0.55, 0.9, 1.0, 0.22))
	_strip(ci, pts, 1.6 * extend, Color(0.9, 0.97, 1.0, 0.45))
	var mat := PlasmaHarvest.material_of(sim, str(pose.material))
	var vein := Color(str(mat.get("vein", "d7e6c8")))
	for i in 9:
		var t := fposmod(sim.time * 1.65 + float(i) / 9.0, 1.0)
		var p := _sample(pts, t)
		var rad := (1.2 + sin(t * PI) * 2.4) * extend
		ci.draw_circle(p, rad, Color(0.75, 0.95, 1.0, 0.28))
	for i in 7:
		var life := fposmod(sim.time * 2.4 + float(i) * 0.17, 1.0)
		var ang: float = float(i) * 2.39996 + float(sim.time) * 1.3
		var spark := b + Vector2.from_angle(ang) * (4.0 + life * 26.0)
		ci.draw_line(b, spark, Color(vein.r, vein.g, vein.b, (1.0 - life) * 0.65), 1.4, true)
		ci.draw_circle(spark, 1.6, Color(1.0, 0.95, 0.85, (1.0 - life) * 0.5))
	var bloom := 10.0 + float(sim.gather.progress) * 14.0 + float(sim.gather.flash) * 18.0
	ci.draw_circle(b, bloom, Color(1.0, 0.86, 0.55, 0.22))
	ci.draw_circle(b, bloom * 0.45, Color(1.0, 0.97, 0.9, 0.38))
	ci.draw_circle(a, 7.0 * extend, Color(0.7, 0.92, 1.0, 0.4))


static func aim_pose(sim) -> Dictionary:
	var ship: Dictionary = sim.player
	var housing := housing(sim, ship)
	var aim := Vector2(float(sim.gather.get("aim_x", 1.0)), float(sim.gather.get("aim_y", 0.0)))
	if aim.length() < 0.001:
		aim = Vector2.from_angle(float(ship.rot))
	else:
		aim = aim.normalized()
	var extend := float(sim.gather.get("extend", 0.0))
	var kick := float(sim.gather.get("flash", 0.0)) * 10.0
	var muzzle := housing + aim * (10.0 + extend * 28.0 - kick)
	var active := bool(sim.gather.get("active", false))
	var impact := muzzle + aim * 40.0
	var material := "iron"
	var node := {}
	if active:
		node = PlasmaHarvest.by_id(sim, str(sim.gather.get("target", "")))
		if not node.is_empty():
			material = str(node.material)
			var to_ship: Vector2 = ship.pos - node.pos
			if to_ship.length() > 0.01:
				impact = node.pos + to_ship.normalized() * float(node.size) * 0.72
			else:
				impact = node.pos
	return {
		"housing": housing,
		"muzzle": muzzle,
		"aim": aim,
		"extend": extend,
		"impact": impact,
		"active": active,
		"material": material,
		"node": node,
	}


static func housing(sim, ship: Dictionary) -> Vector2:
	var forward := Vector2.from_angle(float(ship.rot))
	var side := forward.orthogonal()
	var reach := float(Fit.stats(sim.defs, ship).hit_radius) * 0.55
	return ship.pos + side * reach + forward * 8.0


static func _draw_meteor(ci: CanvasItem, sim, node: Dictionary, origin: Vector2, rot: float, mat: Dictionary, spent: bool, gathering: bool) -> void:
	var visual: Dictionary = node.visual
	var size := float(node.size)
	var to_star := _to_star(origin)
	ci.draw_circle(origin - to_star * size * 0.16, size * 0.96, Color(0, 0, 0, 0.30 if not spent else 0.18))
	var xf := Transform2D(rot, origin)
	var gloss := float(mat.get("gloss", 0.4))
	for face in visual.faces:
		var pts: Array = face.pts
		var world := PackedVector2Array()
		for point in pts:
			world.append(xf * point)
		var outward := _outward(origin, world)
		var ndot := outward.dot(to_star)
		var height := float(face.height)
		var lambert := clampf(0.22 + height * 0.18 + ndot * 0.34 + float(face.get("bias", 0.0)), 0.08, 0.92)
		var metal := 0.0 if spent else pow(maxf(ndot, 0.0), 10.0) * gloss * height * 0.55
		var col := _shade(mat, lambert, metal, spent)
		ci.draw_colored_polygon(world, col)
		if height > 0.72 and not spent:
			var raised := PackedVector2Array([
				world[0].lerp(world[1], 0.42),
				world[1],
				world[2],
				world[0].lerp(world[2], 0.42),
			])
			ci.draw_colored_polygon(raised, _shade(mat, lambert + 0.18, metal + gloss * 0.25, false))
	var rim: PackedVector2Array = visual.rim
	var outline := PackedVector2Array()
	for point in rim:
		outline.append(xf * point)
	if outline.size() > 2:
		var closed := outline.duplicate()
		closed.append(outline[0])
		ci.draw_polyline(closed, _shade(mat, 0.2, 0.0, spent).darkened(0.2), 1.35, true)
	if not spent:
		for crater in visual.craters:
			var c: Vector2 = xf * crater.p
			var radius := float(crater.r)
			ci.draw_circle(c, radius, _shade(mat, 0.12, 0.0, false))
			ci.draw_arc(c - to_star * radius * 0.15, radius * 0.92, 0.0, TAU, 14, _shade(mat, 0.72, gloss * 0.3, false), 1.3, true)
		var vein := Color(str(mat.vein))
		for line in visual.veins:
			var poly := PackedVector2Array()
			for point in line:
				poly.append(xf * point)
			if poly.size() >= 2:
				ci.draw_polyline(poly, vein.darkened(0.25), 3.4, true)
				ci.draw_polyline(poly, vein, 1.6, true)
		var patina := Color(str(mat.patina))
		for spot in visual.spots:
			ci.draw_circle(xf * spot.p, float(spot.r), Color(patina.r, patina.g, patina.b, 0.85))
		if gloss > 0.55:
			var spec := Color(str(mat.spec))
			ci.draw_circle(origin + to_star * size * 0.32, size * (0.05 + gloss * 0.05), Color(spec.r, spec.g, spec.b, 0.35 + gloss * 0.4))
	for pebble in visual.pebbles:
		var orbit: float = float(pebble.p.angle()) + float(sim.time) * 0.25
		var pebble_pos: Vector2 = origin + Vector2.from_angle(orbit) * float(pebble.p.length())
		_draw_simple(ci, pebble_pos, float(pebble.r), mat, spent, sim, node)
	if gathering:
		_draw_kerf(ci, sim, origin, size, mat)


static func _draw_wreck(ci: CanvasItem, sim, node: Dictionary, origin: Vector2, rot: float, mat: Dictionary, spent: bool, gathering: bool) -> void:
	var visual: Dictionary = node.visual
	var size := float(node.size)
	var to_star := _to_star(origin)
	ci.draw_circle(origin - to_star * size * 0.12, size * 0.9, Color(0, 0, 0, 0.32))
	var xf := Transform2D(rot, origin)
	var fan: Array = visual.fan
	for i in fan.size():
		var world := PackedVector2Array([
			xf * Vector2.ZERO,
			xf * fan[i],
			xf * fan[(i + 1) % fan.size()],
		])
		var outward := _outward(origin, world)
		var ndot := outward.dot(to_star)
		var lambert := clampf(0.28 + ndot * 0.7, 0.08, 1.0)
		var col := _shade(mat, lambert, 0.0 if spent else pow(maxf(ndot, 0.0), 4.0) * 0.25, spent)
		if i % 4 == 0 and not spent:
			col = col.lerp(Color(str(mat.patina)), 0.35)
		ci.draw_colored_polygon(world, col)
	var edge := PackedVector2Array()
	for point in fan:
		edge.append(xf * point)
	if edge.size() > 2:
		var closed := edge.duplicate()
		closed.append(edge[0])
		var steel := Color(str(mat.vein)) if not spent else Color("3a3532")
		ci.draw_polyline(closed, steel, 1.8, true)
		if visual.has("tear") and not spent:
			var tear := PackedVector2Array()
			for point in visual.tear:
				tear.append(xf * point)
			if tear.size() >= 2:
				ci.draw_polyline(tear, Color(str(mat.spec)), 2.6, true)
				ci.draw_polyline(tear, Color("fff4e4"), 1.1, true)
	for rib in visual.ribs:
		var poly := PackedVector2Array()
		for point in rib:
			poly.append(xf * point)
		if poly.size() >= 2:
			ci.draw_polyline(poly, Color("1a1614"), 1.5, true)
	if not spent:
		for rivet in visual.rivets:
			ci.draw_circle(xf * rivet, 1.35, Color(str(mat.spec)))
		var scorch: Vector2 = xf * visual.scorch
		ci.draw_circle(scorch, size * 0.28, Color(0.15, 0.05, 0.02, 0.55))
	if gathering:
		_draw_kerf(ci, sim, origin, size, mat)


static func _draw_derelict(ci: CanvasItem, sim, node: Dictionary, origin: Vector2, rot: float, spent: bool, gathering: bool) -> void:
	var class_id := str(node.get("class_id", "skiff"))
	if not sim.defs.ships.has(class_id):
		class_id = "skiff"
	var hull: Dictionary = sim.defs.ships[class_id]
	var size := float(node.size)
	var to_star := _to_star(origin)
	ci.draw_circle(origin - to_star * 8.0, size * 0.85, Color(0, 0, 0, 0.34))
	var body := Color(str(hull.color)).darkened(0.55 if not spent else 0.72)
	var accent := Color(str(hull.accent)).darkened(0.35)
	var scale := size / 34.0
	Silhouette.draw(ci, origin, rot, class_id, [], scale, body, accent, 0.18 if not spent else 0.05, false)
	var visual: Dictionary = node.visual
	var xf := Transform2D(rot, origin)
	var bite := PackedVector2Array([
		xf * Vector2(size * 0.15, -size * 0.18),
		xf * Vector2(size * 0.55, -size * 0.05),
		xf * Vector2(size * 0.22, size * 0.2),
	])
	ci.draw_colored_polygon(bite, Color(0.04, 0.02, 0.015, 0.92))
	for scar in visual.scars:
		ci.draw_line(xf * scar.a, xf * scar.b, Color(0.05, 0.02, 0.01, 0.9), 1.8, true)
	for plate in visual.plates:
		var poly := PackedVector2Array()
		for point in plate:
			var spun: Vector2 = point.rotated(sim.time * 0.4)
			poly.append(origin + spun)
		if poly.size() >= 3:
			ci.draw_colored_polygon(poly, Color("3a3532") if spent else Color("6a5848"))
	var blink := sin(sim.time * 3.2 + float(node.seed % 7)) > 0.35
	if blink and not spent:
		var lamp: Vector2 = xf * Vector2(size * 0.2, 0)
		ci.draw_circle(lamp, 2.4, Color("c4512c"))
	if gathering:
		_draw_kerf(ci, sim, origin, size * 0.72, PlasmaHarvest.material_of(sim, "wreck_plate"))


static func _draw_simple(ci: CanvasItem, origin: Vector2, size: float, mat: Dictionary, spent: bool, _sim, _node: Dictionary) -> void:
	if mat.is_empty():
		ci.draw_circle(origin, maxf(size * 0.45, 1.6), Color("5a5048"))
		return
	var to_star := _to_star(origin)
	var albedo := _shade(mat, 0.62, 0.0, spent)
	var vein := Color(str(mat.get("vein", "8a8070")))
	var body := albedo.lerp(vein, 0.34)
	var deep := _shade(mat, 0.16, 0.0, spent)
	ci.draw_circle(origin - to_star * size * 0.12, size * 0.5, Color(0, 0, 0, 0.28))
	ci.draw_circle(origin, size * 0.46, deep.lerp(body, 0.72))
	ci.draw_circle(origin + to_star * size * 0.16, size * 0.2, body)
	if not spent and float(mat.get("gloss", 0.0)) > 0.5:
		var spec := Color(str(mat.spec))
		ci.draw_circle(origin + to_star * size * 0.2, size * 0.08, Color(spec.r, spec.g, spec.b, 0.8))


static func _draw_mark(ci: CanvasItem, sim, node: Dictionary, pos: Vector2, size: float, mat: Dictionary, gathering: bool) -> void:
	var aimed := str(node.id) == str(sim.aim_id)
	if not aimed and not gathering:
		return
	var col := Color(str(mat.get("vein", "e6d7bf"))) if not mat.is_empty() else Color("e6d7bf")
	ci.draw_arc(pos, size + 10.0, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.85), 1.4, true)
	if gathering:
		var progress := clampf(float(sim.gather.progress), 0.0, 1.0)
		ci.draw_arc(pos, size + 16.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 28, Color("f7fbff"), 2.1, true)


static func _draw_kerf(ci: CanvasItem, sim, origin: Vector2, size: float, mat: Dictionary) -> void:
	var pose := aim_pose(sim)
	var impact: Vector2 = pose.impact
	var into := (origin - impact).normalized()
	if into.length() < 0.5:
		into = Vector2.RIGHT
	var side := into.orthogonal()
	var depth := (4.0 + float(sim.gather.progress) * size * 0.45) 
	var cut := PackedVector2Array([
		impact + side * 3.2,
		impact - side * 3.2,
		impact + into * depth,
	])
	ci.draw_colored_polygon(cut, Color(0.05, 0.02, 0.01, 0.88))
	var hot := Color("fff1d2").lerp(Color(str(mat.get("vein", "ffb060"))), 0.35)
	ci.draw_circle(impact, 3.2 + float(sim.gather.progress) * 5.0, hot)
	ci.draw_circle(impact, 1.6, Color("ffffff"))
	for i in 3:
		var crack := impact + into.rotated((float(i) - 1.0) * 0.45) * (depth * 0.8 + float(i) * 2.0)
		ci.draw_line(impact, crack, Color(hot.r, hot.g, hot.b, 0.75), 1.2, true)


static func _draw_chunks(ci: CanvasItem, sim, pose: Dictionary) -> void:
	var mat := PlasmaHarvest.material_of(sim, str(pose.material))
	var vein := Color(str(mat.get("vein", "e6d7bf"))) if not mat.is_empty() else Color("e6d7bf")
	var albedo := Color(str(mat.get("albedo", "8a8070"))) if not mat.is_empty() else Color("8a8070")
	var impact: Vector2 = pose.impact
	var muzzle: Vector2 = pose.muzzle
	var away := (impact - muzzle).normalized()
	if away.length() < 0.5:
		away = Vector2.RIGHT
	var side := away.orthogonal()
	for i in 5:
		var life := fposmod(sim.time * 0.85 + float(i) * 0.19, 1.0)
		var lateral := sin(float(i) * 1.7) * 10.0
		var p: Vector2
		if life < 0.32:
			var out_t := life / 0.32
			p = impact + away * (out_t * 16.0) + side * lateral * out_t
		else:
			var in_t := (life - 0.32) / 0.68
			var start := impact + away * 16.0 + side * lateral
			p = start.lerp(muzzle, in_t * in_t)
		var chip := PackedVector2Array([
			p + Vector2(-2.2, -1.2),
			p + Vector2(2.4, -0.4),
			p + Vector2(0.2, 2.2),
		])
		ci.draw_colored_polygon(chip, albedo.lerp(vein, life))
	if float(sim.gather.flash) > 0.0:
		var t := 1.0 - clampf(float(sim.gather.flash) / 0.45, 0.0, 1.0)
		var chunk := impact.lerp(muzzle, t)
		ci.draw_circle(chunk, 4.5 * (1.0 - t * 0.65), vein)


static func _draw_tool(ci: CanvasItem, sim, pose: Dictionary) -> void:
	var housing: Vector2 = pose.housing
	var aim: Vector2 = pose.aim
	var side := aim.orthogonal()
	var extend := float(pose.extend)
	var base := PackedVector2Array([
		housing - aim * 6.0 + side * 5.0,
		housing - aim * 6.0 - side * 5.0,
		housing + aim * 4.0 - side * 3.6,
		housing + aim * 4.0 + side * 3.6,
	])
	ci.draw_colored_polygon(base, Color("2c3138"))
	ci.draw_polyline(PackedVector2Array([base[0], base[1], base[2], base[3], base[0]]), Color("9aa4b0"), 1.2, true)
	var length := 8.0 + extend * 26.0
	var barrel := PackedVector2Array([
		housing + side * 2.4,
		housing - side * 2.4,
		housing + aim * length - side * 1.5,
		housing + aim * length + side * 1.5,
	])
	ci.draw_colored_polygon(barrel, Color("3e4650").lerp(Color("8fd0e0"), extend * 0.45))
	for i in 3:
		var ring_t := 0.28 + float(i) * 0.22
		var ring := housing + aim * length * ring_t
		ci.draw_circle(ring, 3.1, Color("6a3a28").lerp(Color("e7b15a"), extend))
	var aperture: Vector2 = pose.muzzle
	ci.draw_circle(aperture, 2.6 + extend * 1.4, Color("d7f6ff"))
	ci.draw_circle(aperture, 1.3, Color("ffffff"))


static func _draw_tool_glow(ci: CanvasItem, pose: Dictionary) -> void:
	var extend := float(pose.extend)
	if extend <= 0.02:
		return
	ci.draw_circle(pose.muzzle, 8.0 * extend, Color(0.6, 0.9, 1.0, 0.35))
	ci.draw_circle(pose.housing + pose.aim * 6.0, 5.0 * extend, Color(0.4, 0.7, 1.0, 0.18))


static func _bake_meteor(rng: RandomNumberGenerator, size: float) -> Dictionary:
	var count := rng.randi_range(12, 16)
	var rim := PackedVector2Array()
	var heights: Array = []
	for i in count:
		var ang := (float(i) + 0.5) / float(count) * TAU
		var rr := size * rng.randf_range(0.78, 1.12)
		rim.append(Vector2.from_angle(ang) * rr)
		heights.append(rng.randf_range(0.22, 0.96))
	var center_h := rng.randf_range(0.72, 1.0)
	var faces: Array = []
	for i in count:
		var h := (float(heights[i]) + float(heights[(i + 1) % count]) + center_h) / 3.0
		faces.append({
			"pts": [Vector2.ZERO, rim[i], rim[(i + 1) % count]],
			"height": h,
			"bias": rng.randf_range(-0.06, 0.06),
		})
	var craters: Array = []
	for _i in rng.randi_range(1, 3):
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, size * 0.48)
		craters.append({"p": p, "r": rng.randf_range(size * 0.08, size * 0.16)})
	var veins: Array = []
	for _i in 2:
		var start := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(size * 0.1, size * 0.35)
		var line := PackedVector2Array()
		var cursor := start
		for _s in 4:
			line.append(cursor)
			cursor += Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(size * 0.08, size * 0.18)
		veins.append(line)
	var spots: Array = []
	for _i in rng.randi_range(2, 4):
		spots.append({
			"p": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, size * 0.7),
			"r": rng.randf_range(1.4, 3.2),
		})
	var pebbles: Array = []
	for _i in 2:
		pebbles.append({
			"p": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(size * 1.25, size * 1.7),
			"r": rng.randf_range(size * 0.12, size * 0.22),
		})
	return {"faces": faces, "rim": rim, "craters": craters, "veins": veins, "spots": spots, "pebbles": pebbles}


static func _bake_wreck(rng: RandomNumberGenerator, size: float, variant: int) -> Dictionary:
	var length := size * 1.35
	var width := size * 0.62
	if variant == 1:
		length = size * 1.7
		width = size * 0.34
	elif variant == 2:
		length = size * 0.95
		width = size * 0.8
	var jag := rng.randf_range(0.15, 0.42)
	var fan: Array = [
		Vector2(-length, -width),
		Vector2(length * 0.15, -width * 1.05),
		Vector2(length, -width * 0.15),
		Vector2(length * (0.45 + jag), width * 0.05),
		Vector2(length * 0.92, width * 0.85),
		Vector2(-length * 0.2, width),
		Vector2(-length * 0.95, width * 0.25),
	]
	var ribs: Array = [PackedVector2Array([
		Vector2(-length * 0.7, 0.0),
		Vector2(length * 0.35, width * 0.08),
	])]
	var rivets: Array = []
	for i in 4:
		rivets.append(Vector2(-length * 0.75 + float(i) * length * 0.28, -width * 0.62))
	var scorch := Vector2(length * 0.35, width * 0.1)
	var tear := PackedVector2Array([
		Vector2(length, -width * 0.15),
		Vector2(length * (0.45 + jag), width * 0.05),
		Vector2(length * 0.92, width * 0.85),
	])
	return {"fan": fan, "ribs": ribs, "rivets": rivets, "scorch": scorch, "tear": tear}


static func _bake_derelict(rng: RandomNumberGenerator, size: float) -> Dictionary:
	var scars: Array = []
	for _i in 3:
		scars.append({
			"a": Vector2(rng.randf_range(-size * 0.4, size * 0.2), rng.randf_range(-size * 0.25, size * 0.25)),
			"b": Vector2(rng.randf_range(-size * 0.1, size * 0.45), rng.randf_range(-size * 0.3, size * 0.3)),
		})
	var plates: Array = []
	for i in 2:
		var center := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(size * 0.9, size * 1.35)
		var plate := PackedVector2Array()
		for s in 4:
			plate.append(center + Vector2.from_angle(float(s) / 4.0 * TAU + float(i)) * rng.randf_range(4.0, 9.0))
		plates.append(plate)
	return {"scars": scars, "plates": plates}


static func _shade(mat: Dictionary, lambert: float, metal: float, spent: bool) -> Color:
	if mat.is_empty():
		return Color("5a5048")
	var albedo := Color(str(mat.albedo))
	var deep := Color(str(mat.deep))
	var spec := Color(str(mat.spec))
	var col := deep.lerp(albedo, clampf(lambert, 0.0, 1.0))
	if metal > 0.0:
		col = col.lerp(spec, clampf(metal, 0.0, 0.72))
	if spent:
		col = col.lerp(Color(0.1, 0.09, 0.08), 0.78)
	return col


static func _to_star(origin: Vector2) -> Vector2:
	if origin.length_squared() < 4.0:
		return Vector2.LEFT
	return -origin.normalized()


static func _outward(origin: Vector2, world: PackedVector2Array) -> Vector2:
	if world.size() < 3:
		return Vector2.RIGHT
	var mid := (world[1] + world[2]) * 0.5
	var outward := mid - origin
	if outward.length_squared() < 0.01:
		return Vector2.RIGHT
	return outward.normalized()


static func _curve(a: Vector2, b: Vector2, time: float, extend: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir := b - a
	var n := Vector2.UP
	if dir.length_squared() > 0.01:
		n = dir.orthogonal().normalized()
	var steps := 16
	for i in steps + 1:
		var t := float(i) / float(steps)
		var wobble := sin(time * 19.0 + t * 11.0) * 6.5 + sin(time * 43.0 + t * 23.0) * 2.4
		wobble *= sin(t * PI) * extend
		pts.append(a.lerp(b, t) + n * wobble)
	return pts


static func _sample(pts: PackedVector2Array, t: float) -> Vector2:
	if pts.size() == 0:
		return Vector2.ZERO
	if pts.size() == 1:
		return pts[0]
	var scaled := clampf(t, 0.0, 0.999) * float(pts.size() - 1)
	var i := int(scaled)
	var frac := scaled - float(i)
	return pts[i].lerp(pts[i + 1], frac)


static func _strip(ci: CanvasItem, pts: PackedVector2Array, width: float, color: Color) -> void:
	if pts.size() < 2 or width <= 0.05 or color.a <= 0.001:
		return
	var stroke := maxf(width * 1.65, 0.8)
	for i in pts.size() - 1:
		if pts[i].distance_squared_to(pts[i + 1]) < 0.04:
			continue
		ci.draw_line(pts[i], pts[i + 1], color, stroke, true)
	for i in pts.size():
		ci.draw_circle(pts[i], width * (0.72 + 0.28 * sin(float(i) * 1.3)), color)
