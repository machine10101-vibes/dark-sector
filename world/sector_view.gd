extends Node2D

var cam: Camera2D
var font: Font
var snapped := false


func _ready() -> void:
	font = ThemeDB.fallback_font
	cam = Camera2D.new()
	cam.enabled = true
	add_child(cam)
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


func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != "sector":
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(-1.0)
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
	return {
		"thrust": 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0,
		"retro": 1.0 if (Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0,
		"rot": rot,
		"strafe": strafe,
		"fire": Input.is_key_pressed(KEY_SPACE),
	}


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
	_draw_trash(sim)
	_draw_star(sim)
	for body in sim.planets:
		_draw_planet(sim, body)
	_draw_pocket(sim)
	_draw_beacon(sim)
	for wreck in sim.wrecks:
		_draw_wreck(wreck)
	for shot in sim.projectiles:
		var tail: Vector2 = shot.pos - shot.vel.normalized() * 14.0
		var col := Color("e7b15a") if str(shot.team) == "captain" else Color("d27a6a")
		var shot_faction: Dictionary = sim.defs.factions.get(str(shot.team), {})
		if str(shot_faction.get("kind", "")) == "pdo":
			col = Color("c9d7c4")
		draw_line(tail, shot.pos, col, 2.0, true)
	var parked := 0
	for item in sim.craft:
		if str(item.state) == "docked":
			var side := Vector2.from_angle(float(sim.player.rot) + PI * 0.5)
			var back := Vector2.from_angle(float(sim.player.rot) + PI)
			var spot: Vector2 = sim.player.pos + back * (34.0 + float(parked) * 16.0) + side * (18.0 if parked % 2 == 0 else -18.0)
			var ghost: Dictionary = item.duplicate(true)
			ghost.pos = spot
			ghost.rot = sim.player.rot
			_draw_craft(sim, ghost)
			parked += 1
		else:
			_draw_craft(sim, item)
	for actor in sim.actors:
		if bool(actor.alive):
			_draw_ship(sim, actor)
	if bool(sim.player.alive):
		_draw_ship(sim, sim.player)
		_draw_velocity(sim.player)
	_draw_scale(center, half, z)
	_draw_names(sim, z)


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
	var green_body = sim.planet(str(sim.defs.system.zones.green.anchor))
	var green_r := float(sim.defs.system.zones.green.radius)
	if green_body != null and green_r > 1.0:
		draw_circle(green_body.pos, green_r, Color(0.43, 0.66, 0.48, 0.07))
		draw_arc(green_body.pos, green_r, 0.0, TAU, 96, Color("8aa896"), 1.6, true)
	var amber_r := float(sim.defs.system.zones.amber.radius)
	if amber_r > 1.0:
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


func _draw_trash(sim) -> void:
	for hull in sim.trash:
		var pos: Vector2 = hull.pos
		var rot := float(hull.rot)
		var scale := float(hull.scale)
		var xf := Transform2D(rot, pos)
		var pts := PackedVector2Array()
		match int(hull.kind):
			0:
				pts = PackedVector2Array([Vector2(18, 0), Vector2(-10, 4), Vector2(-14, 0), Vector2(-10, -4)])
			1:
				pts = PackedVector2Array([Vector2(12, 0), Vector2(8, 9), Vector2(-12, 8), Vector2(-14, -7), Vector2(6, -9)])
			_:
				pts = PackedVector2Array([Vector2(8, 6), Vector2(-16, 3), Vector2(-6, -2), Vector2(10, -7)])
		var world := PackedVector2Array()
		for point in pts:
			world.append(xf * (point * scale))
		draw_colored_polygon(world, Color("6e675c"))
		world.append(world[0])
		draw_polyline(world, Color("c2b49a"), 1.1, true)


func _draw_star(sim) -> void:
	var radius := float(sim.defs.system.star.radius)
	var core := Color(str(sim.defs.system.star.color))
	var glow := core
	glow.a = 0.08
	var mid := core
	mid.a = 0.18
	draw_circle(Vector2.ZERO, radius * 2.1, glow)
	draw_circle(Vector2.ZERO, radius * 1.35, mid)
	draw_circle(Vector2.ZERO, radius, core)
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
		var ice := Color("d5e4ee") if str(body.get("ring_kind", "")) == "ice" else Color(colors[2])
		draw_arc(pos, radius + 36.0, 0.0, TAU, 72, ice, 2.4, true)
		draw_arc(pos, radius + 50.0, 0.0, TAU, 72, Color("9eb4c4"), 1.3, true)
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


func _draw_beacon(sim) -> void:
	var pos: Vector2 = sim.beacon_pos
	draw_arc(pos, 36.0, 0.0, TAU, 28, Color("8aa896"), 1.6, true)
	draw_circle(pos, 4.0, Color("d7e6c8"))
	draw_line(pos + Vector2(-14, 0), pos + Vector2(14, 0), Color("cbb892"), 1.2, true)
	draw_line(pos + Vector2(0, -14), pos + Vector2(0, 14), Color("cbb892"), 1.2, true)


func _draw_ship(sim, ship: Dictionary) -> void:
	var hull: Dictionary = sim.defs.ships[ship.class_id]
	var shapes: Array = Silhouette.shapes_of(sim.defs, ship.modules)
	var layers: Array = Silhouette.layers_of(sim.defs, ship.modules)
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
		bool(ship.thrusting),
		layers
	)
	var bar := float(Fit.stats(sim.defs, ship).hit_radius)
	var frac := hp_ratio
	var origin: Vector2 = ship.pos + Vector2(-bar, -bar - 14.0)
	draw_rect(Rect2(origin, Vector2(bar * 2.0, 3.0)), Color(0, 0, 0, 0.55))
	var fill := Color("d7e6c8") if frac > 0.35 else Color("c4512c")
	draw_rect(Rect2(origin, Vector2(bar * 2.0 * frac, 3.0)), fill)
	if str(ship.agent_id) == "agent:captain" and sim.hangar_down():
		draw_circle(ship.pos + Vector2(0, -bar - 22.0), 3.5, Color("d27a6a"))


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
	var dir := Vector2.from_angle(float(item.rot))
	var side := dir.orthogonal()
	var nose := pos + dir * 10.0
	var left := pos - dir * 6.0 + side * 4.0
	var right := pos - dir * 6.0 - side * 4.0
	draw_colored_polygon(PackedVector2Array([nose, left, right]), col)
	if str(item.state) == "lost":
		draw_line(pos + Vector2(-6, -6), pos + Vector2(6, 6), Color("c4512c"), 1.4, true)
	if str(item.def_id) == "survey_probe" and str(item.state) == "working":
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
	var pocket_name := str(sim.defs.system.pocket.name)
	if not bool(sim.defs.system.pocket.get("plantable", false)):
		pocket_name = "%s — closed" % pocket_name
	_text(sim.pocket_pos + Vector2(-70, -float(sim.defs.system.pocket.radius) - 16.0), pocket_name, 15, Color("c5d2b4"))
	if zoom < 0.4 and float(sim.defs.system.zones.amber.radius) > 1.0:
		_text(sim.nest_pos + Vector2(-40, -float(sim.defs.system.zones.amber.radius) - 12.0), "The Slat — amber", 14, Color("c4923a"))
	_text(sim.beacon_pos + Vector2(-46, -22), "Dock beacon", 13, Color("8aa896"))
	if zoom < 0.55 and sim.trash.size() > 0:
		var pile: Vector2 = sim.trash[0].pos
		_text(pile + Vector2(-30, -28), str(sim.defs.system.trash.name), 14, Color("c2b49a"))
	for place in sim.nodes:
		if str(place.kind) == "planet":
			continue
		_text(place.pos + Vector2(12, -16), str(place.name), 13, Color("c5d4de"))
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


func _text(pos: Vector2, text: String, size: int, color: Color) -> void:
	if font == null:
		return
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
