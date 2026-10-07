extends Node2D

var cam: Camera2D
var font: Font
var snapped := false
var glow: Node2D
var gather_click = null


func _ready() -> void:
	font = ThemeDB.fallback_font
	cam = Camera2D.new()
	cam.enabled = true
	add_child(cam)
	glow = GlowLayer.new()
	glow.name = "PlasmaGlow"
	add_child(glow)
	snap()


func snap() -> void:
	snapped = false
	if Game.sim != null and cam != null:
		cam.position = Game.sim.player.pos
		cam.zoom = Vector2.ONE * Game.zoom
		snapped = true


func _process(delta: float) -> void:
	if Game.mode != "sector" or Game.sim == null or cam == null:
		return
	if not Game.paused and Game.sim.player != null:
		Game.sim.tick(delta, _cmd())
	var target: Vector2 = Game.sim.player.pos
	if not snapped:
		cam.position = target
		snapped = true
	else:
		cam.position = cam.position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	cam.zoom = Vector2.ONE * Game.zoom
	queue_redraw()
	if glow != null:
		glow.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != "sector":
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(-1.0)
		elif event.button_index == MOUSE_BUTTON_RIGHT and not Game.paused and Game.sim != null and bool(Game.sim.player.alive):
			gather_click = get_global_mouse_position()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			_zoom(1.0)
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			_zoom(-1.0)


func _zoom(direction: float) -> void:
	var z := Game.zoom
	if direction > 0.0:
		z *= 1.12
	else:
		z /= 1.12
	Game.zoom = clampf(z, 0.05, 1.55)


func _cmd() -> Dictionary:
	if not Game.sim.player.alive:
		return {}
	var rot := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		rot -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		rot += 1.0
	var strafe := 0.0
	if Input.is_key_pressed(KEY_Q):
		strafe -= 1.0
	if Input.is_key_pressed(KEY_E):
		strafe += 1.0
	var cmd := {
		"thrust": 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0,
		"retro": 1.0 if (Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0,
		"rot": rot,
		"strafe": strafe,
		"fire": Input.is_key_pressed(KEY_SPACE),
		"aim": get_global_mouse_position(),
	}
	if gather_click != null:
		cmd["gather_at"] = gather_click
		gather_click = null
	return cmd


func _draw() -> void:
	if Game.sim == null or cam == null:
		return
	var sim = Game.sim
	var z: float = maxf(Game.zoom, 0.05)
	var half: Vector2 = get_viewport_rect().size * 0.5 / z
	var center: Vector2 = cam.position
	var view := Rect2(center - half, half * 2.0)
	draw_rect(view.grow(8.0), Color("07080c"), true)
	_draw_grid(view, z)
	for star in sim.stars:
		var pos: Vector2 = star.pos
		if view.grow(20).has_point(pos):
			draw_circle(pos, float(star.r), Color(0.90, 0.86, 0.75, float(star.a)))
	_draw_zones(sim)
	_draw_belt(sim)
	_draw_star(sim)
	for body in sim.planets:
		_draw_planet(sim, body)
	_draw_pocket(sim)
	_draw_homestead(sim)
	for node in sim.nodes:
		BodyRender.draw_node(self, sim, node, view, z)
	for wreck in sim.wrecks:
		_draw_wreck(wreck)
	for shot in sim.projectiles:
		var tail: Vector2 = shot.pos - shot.vel.normalized() * 14.0
		var col := Color("e7b15a") if str(shot.team) == "captain" else Color("d27a6a")
		if str(shot.team) == "vellum_compact":
			col = Color("c9d7c4")
		draw_line(tail, shot.pos, col, 2.0, true)
	for item in sim.craft:
		if str(item.state) == "docked":
			continue
		_draw_craft(sim, item)
	for actor in sim.actors:
		if bool(actor.alive):
			_draw_ship(sim, actor)
	if bool(sim.player.alive):
		_draw_ship(sim, sim.player)
		_draw_velocity(sim.player)
		BodyRender.draw_matter(self, sim)
	_draw_scale(center, half, z)
	_draw_names(sim, z)
	_draw_harvest_labels(sim, z)
	_draw_beacon(sim)


func _draw_grid(view: Rect2, zoom: float) -> void:
	var step := 500.0
	if zoom < 0.18:
		step = 2000.0
	elif zoom < 0.45:
		step = 1000.0
	var col := Color(0.16, 0.18, 0.22, 0.55)
	var x0 := floorf(view.position.x / step) * step
	var y0 := floorf(view.position.y / step) * step
	var x := x0
	while x < view.end.x:
		draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), col, 1.0)
		x += step
	var y := y0
	while y < view.end.y:
		draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), col, 1.0)
		y += step


func _draw_zones(sim) -> void:
	var vellum = sim.planet("vellum")
	var green_r := float(sim.defs.system.zones.green.radius)
	draw_circle(vellum.pos, green_r, Color(0.43, 0.66, 0.48, 0.07))
	draw_arc(vellum.pos, green_r, 0.0, TAU, 96, Color("8aa896"), 1.6, true)
	var amber_r := float(sim.defs.system.zones.amber.radius)
	draw_circle(sim.nest_pos, amber_r, Color(0.77, 0.57, 0.23, 0.06))
	draw_arc(sim.nest_pos, amber_r, 0.0, TAU, 80, Color("c4923a"), 1.6, true)


func _draw_belt(sim) -> void:
	for rock in sim.asteroids:
		var verts: PackedVector2Array = rock.verts
		draw_colored_polygon(verts, Color("3a342c"))
		if verts.size() > 1:
			var outline := verts.duplicate()
			outline.append(verts[0])
			draw_polyline(outline, Color("6a5c4a"), 1.0, true)


func _draw_star(sim) -> void:
	var radius := float(sim.defs.system.star.radius)
	draw_circle(Vector2.ZERO, radius * 2.1, Color(0.91, 0.70, 0.36, 0.08))
	draw_circle(Vector2.ZERO, radius * 1.35, Color(0.91, 0.62, 0.28, 0.18))
	draw_circle(Vector2.ZERO, radius, Color("f2d7a2"))
	draw_circle(Vector2.ZERO, radius * 0.42, Color("fff6e4"))


func _draw_planet(sim, body: Dictionary) -> void:
	var pos: Vector2 = body.pos
	var radius := float(body.radius)
	var colors: Array = body.colors
	draw_circle(pos, radius + 10.0, Color(colors[2]))
	draw_circle(pos, radius, Color(colors[0]))
	var spin := float(body.get("spin", 0.1))
	for i in 4:
		var a0: float = float(sim.time) * spin + float(i) * 1.35
		draw_arc(pos, radius * (0.38 + float(i) * 0.13), a0, a0 + 1.35, 18, Color(colors[1]), 5.0, true)
	if bool(body.ring):
		draw_arc(pos, radius + 22.0, -0.4, PI + 0.4, 48, Color(colors[2]), 3.0, true)
	if bool(body.moon):
		var moon: Vector2 = pos + Vector2.from_angle(sim.time * 0.35 + 0.6) * (radius + 42.0)
		draw_circle(moon, 9.0, Color(colors[1]))
	if bool(body.junk):
		for k in 6:
			var ang := float(k) * 1.05 + float(body.angle)
			var junk: Vector2 = pos + Vector2.from_angle(ang) * (radius + 26.0 + float(k) * 4.0)
			var tangent := Vector2.from_angle(ang + PI * 0.5)
			draw_line(junk - tangent * 5.0, junk + tangent * 5.0, Color(colors[1]), 2.0, true)


func _draw_pocket(sim) -> void:
	var radius := float(sim.defs.system.pocket.radius)
	draw_circle(sim.pocket_pos, radius, Color(0.45, 0.58, 0.42, 0.08))
	draw_arc(sim.pocket_pos, radius, 0.0, TAU, 64, Color("9aaf8c"), 1.4, true)
	for i in 8:
		var p: Vector2 = sim.pocket_pos + Vector2.from_angle(float(i) * TAU / 8.0) * radius
		draw_line(p + Vector2(0, -10), p + Vector2(0, 10), Color("cbb892"), 2.0, true)
	draw_line(sim.pocket_pos + Vector2(-14, 0), sim.pocket_pos + Vector2(14, 0), Color("cbb892"), 1.2, true)
	draw_line(sim.pocket_pos + Vector2(0, -14), sim.pocket_pos + Vector2(0, 14), Color("cbb892"), 1.2, true)


func _draw_homestead(sim) -> void:
	var claim: Dictionary = sim.claim
	if not bool(claim.get("owned", false)) and not bool(claim.get("core", false)):
		return
	var origin: Vector2 = sim.pocket_pos
	var frozen := bool(claim.get("frozen", false))
	var dome_col := Color("5c564c") if frozen else Color("9fd0c8")
	if bool(claim.get("dome", false)):
		draw_arc(origin, 78.0, 0.0, TAU, 40, dome_col, 2.2, true)
		draw_line(origin + Vector2(-78, 0), origin + Vector2(78, 0), dome_col, 1.2, true)
	if bool(claim.get("core", false)):
		draw_circle(origin, 10.0, Color("e6d7bf"))
	elif frozen:
		draw_circle(origin, 8.0, Color("5a4038"))
	var crop: Dictionary = claim.get("crop", {})
	if str(crop.get("id", "")) != "":
		var kale := Color("6a8f4e") if not bool(crop.get("ready", false)) else Color("d7e6c8")
		if frozen:
			kale = Color("3e4a38")
		for i in 5:
			var x := -28.0 + float(i) * 14.0
			var h := 10.0 + float(i % 2) * 8.0
			if bool(crop.get("ready", false)):
				h = 22.0
			draw_line(origin + Vector2(x, 18), origin + Vector2(x, 18 - h), kale, 2.0, true)
	var animal: Dictionary = claim.get("animal", {})
	if str(animal.get("id", "")) != "":
		var hen := Color("d4724a") if bool(animal.get("alive", false)) else Color("3a3532")
		if frozen and bool(animal.get("alive", false)):
			hen = Color("8a7344")
		draw_circle(origin + Vector2(36, -22), 7.0, hen)
	var defense: Dictionary = claim.get("defense", {})
	if bool(defense.get("online", false)):
		var turret := Color("6d6558") if frozen else Color("cbb892")
		var tip := origin + Vector2(0, -96)
		draw_line(origin + Vector2(-16, -70), tip, turret, 2.0, true)
		draw_line(origin + Vector2(16, -70), tip, turret, 2.0, true)
	if frozen:
		_text(origin + Vector2(-46, 96), "frozen stake", 14, Color("a08070"))


func _draw_ship(sim, ship: Dictionary) -> void:
	var hull: Dictionary = sim.defs.ships[ship.class_id]
	var shapes: Array = Silhouette.shapes_of(sim.defs, ship.modules)
	var hp_ratio := clampf(float(ship.hp) / maxf(float(ship.max_hp), 1.0), 0.0, 1.0)
	Silhouette.draw(
		self,
		ship.pos,
		ship.rot,
		str(ship.class_id),
		shapes,
		1.0,
		Color(str(hull.color)),
		Color(str(hull.accent)),
		hp_ratio,
		bool(ship.thrusting)
	)
	var bar := float(Fit.stats(sim.defs, ship).hit_radius)
	var frac := hp_ratio
	var origin: Vector2 = ship.pos + Vector2(-bar, -bar - 14.0)
	draw_rect(Rect2(origin, Vector2(bar * 2.0, 3.0)), Color(0, 0, 0, 0.55))
	var fill := Color("d7e6c8") if frac > 0.35 else Color("c4512c")
	draw_rect(Rect2(origin, Vector2(bar * 2.0 * frac, 3.0)), fill)


func _draw_craft(sim, item: Dictionary) -> void:
	var pos: Vector2 = item.pos
	var col := Color("d7e6c8")
	match str(item.def_id):
		"survey_probe":
			col = Color("9fd0c8")
		"harvest_drone":
			col = Color("d2a15a")
		"salvage_tender":
			col = Color("c47a4a")
		"away_shuttle":
			col = Color("d7d2c4")
		"fighter":
			col = Color("c4512c")
		"pathfinder":
			col = Color("e6d7bf")
		"prospector":
			col = Color("e07a3d")
	var dir := Vector2.from_angle(float(item.rot))
	var side := dir.orthogonal()
	var reach := 16.0 if str(item.def_id) == "pathfinder" else 10.0
	var nose := pos + dir * reach
	var left := pos - dir * 6.0 + side * 4.0
	var right := pos - dir * 6.0 - side * 4.0
	draw_colored_polygon(PackedVector2Array([nose, left, right]), col)
	if str(item.state) == "lost":
		draw_line(pos + Vector2(-6, -6), pos + Vector2(6, 6), Color("c4512c"), 1.4, true)
	if str(item.def_id) in ["survey_probe", "pathfinder"] and str(item.state) == "working":
		var frac := clampf(float(item.layers_done) / 7.0, 0.0, 1.0)
		draw_arc(pos, 16.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, Color("d7e6c8"), 1.5, true)


func _draw_wreck(wreck: Dictionary) -> void:
	var pos: Vector2 = wreck.pos
	var col := Color("5a4038") if not bool(wreck.stripped) else Color("3a3532")
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(10, 2), pos + Vector2(-4, 8), pos + Vector2(-12, -2), pos + Vector2(2, -8)
	]), col)
	draw_line(pos + Vector2(-8, -6), pos + Vector2(8, 6), Color("2a1814"), 1.2, true)


func _draw_velocity(ship: Dictionary) -> void:
	if ship.vel.length() < 8.0:
		return
	draw_line(ship.pos, ship.pos + ship.vel * 0.35, Color(0.90, 0.86, 0.75, 0.35), 1.0, true)
	var forward := Vector2.from_angle(ship.rot)
	draw_line(ship.pos + forward * 24.0, ship.pos + forward * 42.0, Color("e6d7bf"), 1.4, true)


func _draw_scale(center: Vector2, half: Vector2, zoom: float) -> void:
	var raw := 140.0 / zoom
	var mag := pow(10.0, floor(log(maxf(raw, 1.0)) / log(10.0)))
	var length := mag
	if raw / mag > 5.0:
		length = mag * 5.0
	elif raw / mag > 2.0:
		length = mag * 2.0
	var origin := center + Vector2(-half.x + 36.0 / zoom, half.y - 36.0 / zoom)
	draw_line(origin, origin + Vector2(length, 0), Color("cbb892"), 1.6, true)
	draw_line(origin, origin + Vector2(0, -6.0 / zoom), Color("cbb892"), 1.4, true)
	draw_line(origin + Vector2(length, 0), origin + Vector2(length, -6.0 / zoom), Color("cbb892"), 1.4, true)
	_text(origin + Vector2(0, -18.0 / zoom), "%d m" % int(length), 13, Color("cbb892"))


func _draw_names(sim, zoom: float) -> void:
	_text(sim.defs.system.star.radius * Vector2(0, -1) + Vector2(-40, -28), str(sim.defs.system.star.name), 16, Color("f0c27a"))
	for body in sim.planets:
		_text(body.pos + Vector2(body.radius * 0.2, -body.radius - 18.0), str(body.name), 16, Color("e6d7bf"))
	_text(sim.pocket_pos + Vector2(-70, -float(sim.defs.system.pocket.radius) - 16.0), "Hollow Latch", 15, Color("c5d2b4"))
	if zoom < 0.4:
		_text(sim.nest_pos + Vector2(-40, -float(sim.defs.system.zones.amber.radius) - 12.0), "The Slat — amber", 14, Color("c4923a"))
	var player_name := str(sim.defs.ships[sim.player.class_id].callsign)
	_text(sim.player.pos + Vector2(18, 18), player_name, 14, Color("e6d7bf"))
	if zoom > 0.22:
		for actor in sim.actors:
			if not bool(actor.alive):
				continue
			_text(actor.pos + Vector2(16, 16), str(actor.name), 12, Color("cbb892"))
		for item in sim.craft:
			if str(item.state) == "docked":
				continue
			_text(item.pos + Vector2(12, 12), "%s  %s" % [item.name, item.state], 12, Color("d7e6c8"))
		for wreck in sim.wrecks:
			var tag := "wreck rights" if not bool(wreck.stripped) else "stripped"
			_text(wreck.pos + Vector2(12, 14), "%s  %s" % [wreck.name, tag], 12, Color("a08070"))


func _draw_harvest_labels(sim, zoom: float) -> void:
	if not sim.defs.has("harvest"):
		return
	for mark in sim.belt_marks:
		var mat: Dictionary = sim.defs.harvest.materials.get(mark.material, {})
		var col := Color(str(mat.get("vein", "cbb892")))
		_text(mark.pos + Vector2(-46, -18), str(mark.name), 15, col)
	if zoom < 0.18:
		return
	for node in sim.nodes:
		var aimed := str(node.id) == str(sim.aim_id)
		var locked := bool(sim.gather.get("active", false)) and str(sim.gather.get("target", "")) == str(node.id)
		var derelict := str(node.kind) == "derelict"
		if not aimed and not locked and not (derelict and zoom > 0.28):
			continue
		var line := PlasmaHarvest.load_line(sim, node)
		_text(node.pos + Vector2(8, float(node.size) + 16.0), "%s  %s" % [node.name, line], 13, Color("e6d7bf"))


func _draw_beacon(sim) -> void:
	var mark: Dictionary = sim.beacon
	if mark.is_empty() or not mark.has("pos"):
		return
	var pos: Vector2 = mark.pos
	var diamond := PackedVector2Array([
		pos + Vector2(0, -16),
		pos + Vector2(12, 0),
		pos + Vector2(0, 16),
		pos + Vector2(-12, 0),
	])
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("f0c27a"), 1.6, true)
	_text(pos + Vector2(16, -8), str(mark.get("name", "Mark")), 14, Color("f0c27a"))
	if str(mark.get("line", "")) != "":
		_text(pos + Vector2(16, 10), str(mark.line), 12, Color("e0b080"))


func _text(pos: Vector2, text: String, size: int, color: Color) -> void:
	if font == null:
		return
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


class GlowLayer extends Node2D:
	func _ready() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _draw() -> void:
		if Game.sim == null:
			return
		BodyRender.draw_beam(self, Game.sim)
