extends Node2D

var cam: Camera2D
var font: Font
var snapped := false
var helm_yaw := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	cam = Camera2D.new()
	cam.enabled = true
	add_child(cam)
	var bridge := preload("res://world/origin_bridge.gd").new()
	bridge.name = "OriginBridge"
	add_child(bridge)
	snap()


func snap() -> void:
	snapped = false
	if Game.sim != null and cam != null:
		_frame_dock()
		cam.zoom = Vector2.ONE * Game.zoom
		cam.position = _chase_pos()
		cam.rotation = _chase_rot()
		snapped = true
	var bridge := get_node_or_null("OriginBridge")
	if bridge != null and bridge.has_method("bind_sector"):
		bridge.bind_sector()


func _frame_dock() -> void:
	if absf(Game.zoom - 0.58) > 0.03:
		return
	var screen := get_viewport_rect().size
	if screen.x >= 900.0 and screen.y <= screen.x:
		return
	var home := str(Game.sim.defs.system.get("pdo", {}).get("home", ""))
	var dock = Game.sim.planet(home)
	if dock == null:
		return
	var gap: float = Game.sim.player.pos.distance_to(dock.pos) - float(dock.radius)
	var want: float = gap + float(dock.radius) * 0.7
	var z := screen.x / (2.0 * maxf(want, 240.0))
	Game.zoom = clampf(minf(z, 0.58), 0.2, 0.58)


func _process(delta: float) -> void:
	if Game.mode != "sector" or Game.sim == null or cam == null:
		return
	if not Game.paused and Game.sim.player != null:
		var link = Game.link
		if link != null and str(link.role) == "client":
			link.take_client(Game.sim)
			link.send_cmd(str(Game.sim.player.get("player_id", "")), _cmd(delta))
		else:
			if link != null and str(link.role) == "host":
				link.take_host(Game.sim)
			Game.sim.tick(delta, _cmd(delta))
			if link != null and str(link.role) == "host":
				link.broadcast(Game.sim)
	var target: Vector2 = _chase_pos()
	var heading := _chase_rot()
	if not snapped:
		cam.position = target
		cam.rotation = heading
		snapped = true
	else:
		var blend := clampf(delta * 5.0, 0.0, 1.0)
		cam.position = cam.position.lerp(target, blend)
		cam.rotation = lerp_angle(cam.rotation, heading, blend)
	cam.zoom = Vector2.ONE * Game.zoom
	queue_redraw()


func _chase_pos() -> Vector2:
	var ship: Dictionary = Game.sim.player
	var focus: Vector2 = Game.sim.view_focus()
	var ahead := Vector2.from_angle(float(ship.rot))
	var zoom := maxf(Game.zoom, 0.12)
	var speed := float(ship.vel.length())
	var lead := clampf(72.0 + speed * 0.2, 90.0, 340.0) / zoom
	var layer := int(Game.sim.layer)
	if layer == ScaleFrame.CHART:
		lead = clampf(160.0 + speed * 0.12, 160.0, 480.0) / zoom
	elif layer == ScaleFrame.APPROACH:
		lead = clampf(200.0 + speed * 0.1, 200.0, 560.0) / zoom
	return focus + ahead * lead


func _chase_rot() -> float:
	return 0.0


func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != "sector" or Game.map_open:
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


func _cmd(delta: float) -> Dictionary:
	if not Game.sim.player.alive:
		helm_yaw = 0.0
		return {}
	# A corp field, the chat line, or the sector chart owns the keys.
	# A stick that is still deflected must not keep thrusting while that lasts.
	if Game.text_entry or Game.map_open:
		helm_yaw = move_toward(helm_yaw, 0.0, 24.0 * delta)
		Game.cast_pulse = 0.0
		var quiet := {
			"thrust": 0.0,
			"retro": 0.0,
			"rot": 0.0,
			"strafe": 0.0,
			"fire": false,
		}
		var typed: Dictionary = Game.take_verbs()
		for key in typed.keys():
			quiet[key] = typed[key]
		return quiet
	var stick: Dictionary = Game.flight
	var rot := 0.0
	# Screen-right on the overhead camera is world -X, so positive sim yaw
	# (clockwise) swings the nose to screen-left. Negate live helm input
	# here. sim.tick still adds rot as given; headless tests pass rot directly.
	if Game.flight_down(KEY_A) or Game.flight_down(KEY_LEFT):
		rot += 1.0
	if Game.flight_down(KEY_D) or Game.flight_down(KEY_RIGHT):
		rot -= 1.0
	if rot == 0.0:
		rot = -float(stick.get("rot", 0.0))
	helm_yaw = move_toward(helm_yaw, rot, 24.0 * delta)
	rot = helm_yaw
	var strafe := 0.0
	# orthogonal() is clockwise, so negative strafe is left of the nose.
	# Q and Port stay on that side. E and Stbd stay on the right.
	if Game.flight_down(KEY_Q):
		strafe -= 1.0
	if Game.flight_down(KEY_E):
		strafe += 1.0
	if strafe == 0.0:
		strafe = float(stick.get("strafe", 0.0))
	var pulsed := Game.cast_pulse > 0.0
	if pulsed:
		Game.cast_pulse = maxf(0.0, Game.cast_pulse - delta)
	var thrust := 1.0 if (Game.flight_down(KEY_W) or Game.flight_down(KEY_UP) or pulsed) else float(stick.get("thrust", 0.0))
	var retro := 1.0 if (Game.flight_down(KEY_S) or Game.flight_down(KEY_DOWN)) else float(stick.get("retro", 0.0))
	var cmd := {
		"thrust": thrust,
		"retro": retro,
		"rot": rot,
		"strafe": strafe,
		"fire": Game.flight_down(KEY_SPACE) or bool(stick.get("fire", false)),
	}
	var verbs: Dictionary = Game.take_verbs()
	for key in verbs.keys():
		cmd[key] = verbs[key]
	return cmd


func _draw() -> void:
	# The helm renders the sector as meshes. This view only ticks the sim and takes input.
	return
	if Game.sim == null or cam == null:
		return
	var sim = Game.sim
	var z: float = maxf(Game.zoom, 0.05)
	var half: Vector2 = get_viewport_rect().size * 0.5 / z
	var center: Vector2 = cam.position
	var cover := half.length()
	var view := Rect2(center - Vector2(cover, cover), Vector2(cover, cover) * 2.0)
	draw_rect(view.grow(8.0), Color("07080c"), true)
	_draw_nebula()
	_draw_grid(view, z)
	for star in sim.stars:
		var pos: Vector2 = star.pos
		if view.grow(20).has_point(pos):
			var temp := float(star.a)
			var tint := Color(0.72, 0.8, 0.95, temp) if temp < 0.4 else Color(0.95, 0.9, 0.78, temp)
			if temp > 0.7:
				tint = Color(1.0, 0.82, 0.62, temp)
			draw_circle(pos, float(star.r) * 2.8, Color(tint.r, tint.g, tint.b, temp * 0.16))
			draw_circle(pos, float(star.r), tint)
			if temp > 0.72:
				var spark := Color(tint.r, tint.g, tint.b, 0.4)
				var arm := float(star.r) * 3.4
				draw_line(pos + Vector2(-arm, 0.0), pos + Vector2(arm, 0.0), spark, 0.7, true)
				draw_line(pos + Vector2(0.0, -arm), pos + Vector2(0.0, arm), spark, 0.7, true)
	_draw_zones(sim)
	_draw_belt(sim)
	_draw_meteors(sim)
	_draw_trash(sim)
	_draw_star(sim)
	for body in sim.planets:
		_draw_planet(sim, body)
	_draw_pocket(sim)
	_draw_beacon(sim)
	_draw_gates(sim)
	_draw_homestead(sim)
	_draw_mark(sim)
	for wreck in sim.wrecks:
		_draw_wreck(wreck)
	for shot in sim.projectiles:
		var tail: Vector2 = shot.pos - shot.vel.normalized() * 14.0
		var col := Color("e7b15a") if str(shot.team) == "captain" else Color("d27a6a")
		var shot_faction: Dictionary = sim.defs.factions.get(str(shot.team), {})
		if str(shot_faction.get("kind", "")) == "pdo":
			col = Color("c9d7c4")
		var bloom := col
		bloom.a = 0.28
		var haze := col
		haze.a = 0.1
		draw_circle(shot.pos, 11.0, haze)
		draw_circle(shot.pos, 4.2, bloom)
		draw_line(tail, shot.pos, Color(col.r, col.g, col.b, 0.45), 3.4, true)
		draw_line(tail, shot.pos, col.lightened(0.35), 1.3, true)
		draw_circle(shot.pos, 1.5, Color("fff6e4"))
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
	for mate in sim.captains:
		if bool(mate.get("alive", false)):
			_draw_ship(sim, mate)
			_draw_velocity(mate)
	if bool(sim.player.alive):
		_draw_ship(sim, sim.player)
		_draw_velocity(sim.player)
	_draw_scale(z)
	_draw_names(sim, z)


func _draw_nebula() -> void:
	draw_circle(Vector2(-2400, -1600), 1800.0, Color(0.08, 0.12, 0.18, 0.26))
	draw_circle(Vector2(-1700, -980), 720.0, Color(0.14, 0.18, 0.26, 0.1))
	draw_circle(Vector2(2800, 500), 1600.0, Color(0.16, 0.09, 0.06, 0.15))
	draw_circle(Vector2(2200, 980), 560.0, Color(0.26, 0.12, 0.07, 0.07))
	draw_circle(Vector2(-500, 3000), 1300.0, Color(0.06, 0.11, 0.12, 0.13))
	draw_circle(Vector2(1100, -2400), 800.0, Color(0.15, 0.12, 0.07, 0.09))
	draw_line(Vector2(-2000, -200), Vector2(1800, 1100), Color(0.12, 0.09, 0.07, 0.07), 26.0)
	draw_line(Vector2(-800, 1200), Vector2(600, -1600), Color(0.06, 0.09, 0.13, 0.09), 16.0)
	for puff in 8:
		var n := absi(hash("dust" + str(puff)))
		var at := Vector2(float(n % 5200) - 2600.0, float((n / 17) % 4800) - 2100.0)
		draw_circle(at, 160.0 + float(n % 240), Color(0.22, 0.16, 0.12, 0.03))


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
		draw_circle(green_body.pos, green_r, Color(0.43, 0.66, 0.48, 0.045))
		draw_circle(green_body.pos, green_r * 0.62, Color(0.55, 0.78, 0.58, 0.04))
		draw_arc(green_body.pos, green_r, 0.0, TAU, 96, Color("8aa896"), 1.6, true)
	var amber_r := float(sim.defs.system.zones.amber.radius)
	if amber_r > 1.0:
		draw_circle(sim.nest_pos, amber_r, Color(0.77, 0.57, 0.23, 0.04))
		draw_circle(sim.nest_pos, amber_r * 0.55, Color(0.9, 0.7, 0.32, 0.035))
		draw_arc(sim.nest_pos, amber_r, 0.0, TAU, 80, Color("c4923a"), 1.6, true)
	for disc in Law.discs(sim):
		var row: Dictionary = disc
		var kind := str(row.get("kind", "dark"))
		var col := Law.color_of(kind)
		col.a = 0.08
		var pos: Vector2 = row.pos
		var outer := float(row.get("radius", 0.0))
		var inner := float(row.get("inner", 0.0))
		if inner > 1.0:
			draw_arc(pos, (inner + outer) * 0.5, 0.0, TAU, 96, Law.color_of(kind), maxf(2.0, outer - inner), true)
		else:
			draw_circle(pos, outer, col)
			draw_arc(pos, outer, 0.0, TAU, 80, Law.color_of(kind), 1.8, true)


func _draw_belt(sim) -> void:
	for rock in sim.asteroids:
		var verts: PackedVector2Array = rock.verts
		if verts.size() < 3:
			continue
		var tint := Color(str(rock.get("tint", "#3a342c")))
		var center := Vector2.ZERO
		for point in verts:
			center += point
		center /= float(verts.size())
		var lit := _light_at(center)
		var colors := PackedColorArray()
		var span := 0.0
		for point in verts:
			var n: Vector2 = point - center
			var face := 0.5
			if n.length_squared() > 1.0:
				face = clampf(n.normalized().dot(lit) * 0.5 + 0.5, 0.15, 1.0)
			var shade := tint.darkened(0.45).lerp(tint.lightened(0.18), face)
			colors.append(shade)
			span = maxf(span, n.length())
		if span > 6.0:
			var cast := PackedVector2Array()
			for point in verts:
				cast.append(point - lit * span * 0.16)
			draw_colored_polygon(cast, Color(0, 0, 0, 0.16))
		draw_polygon(verts, colors)
		var outline := verts.duplicate()
		outline.append(verts[0])
		draw_polyline(outline, tint.lightened(0.12), 1.0, true)
		if span > 6.0:
			var ridge := Vector2(-lit.y, lit.x)
			draw_circle(center - lit * span * 0.28, span * 0.22, tint.darkened(0.4))
			draw_circle(center + ridge * span * 0.22, span * 0.1, tint.darkened(0.32))
			draw_line(center - ridge * span * 0.45, center + ridge * span * 0.3, tint.darkened(0.22), 1.2, true)
			draw_arc(center - lit * span * 0.05, span * 0.28, 0.4, 2.4, 8, tint.darkened(0.15), 1.1, true)
			draw_circle(center + lit * span * 0.35, span * 0.12, tint.lightened(0.22))
			draw_circle(center + lit * span * 0.42, span * 0.045, Color(1, 0.96, 0.9, 0.35))


func _draw_meteors(sim) -> void:
	var vector := float(sim.defs.system.get("stream", {}).get("vector", 0.0))
	var back := -Vector2.from_angle(vector)
	for rock in sim.meteors:
		var pos: Vector2 = rock.pos
		var size := float(rock.get("size", 4.0)) * 3.4
		var tail := pos + back * (22.0 + size * 2.4)
		var side := Vector2(-back.y, back.x)
		draw_line(pos, tail, Color(0.78, 0.42, 0.22, 0.28), size * 0.85, true)
		draw_line(pos, pos + back * 12.0, Color("e7b15a"), 1.3, true)
		draw_circle(pos, size * 2.4, Color(0.85, 0.4, 0.16, 0.1))
		var chunk := PackedVector2Array([
			pos + side * size * 0.7 - back * size * 0.2,
			pos + side * size * 0.2 + back * size * 0.85,
			pos - side * size * 0.65 + back * size * 0.15,
			pos - side * size * 0.25 - back * size * 0.8,
		])
		draw_colored_polygon(chunk, Color("6a301c"))
		draw_colored_polygon(Silhouette._inset_world(chunk, size * 0.35, -back * size * 0.2), Color("c46a3a"))
		draw_circle(pos - back * size * 0.45, size * 0.22, Color("fff0d2"))


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
		var lit := _light_at(pos)
		draw_colored_polygon(world, Color("3e3a34"))
		draw_colored_polygon(Silhouette._inset_world(world, 1.6 * scale, lit * (1.4 * scale)), Color("8a8174"))
		var rust := world.duplicate()
		rust.append(rust[0])
		draw_polyline(rust, Color("6a4034"), 1.3, true)
		var pit := Silhouette._centroid(world)
		draw_circle(pit - lit * (1.8 * scale), 1.5 * scale, Color("241c16"))
		draw_circle(pit + lit * (2.2 * scale), 0.8 * scale, Color(0.85, 0.78, 0.64, 0.45))
		draw_line(xf * (Vector2(-6, 1) * scale), xf * (Vector2(-16, 6) * scale), Color("5a4034"), 1.5, true)
		draw_line(xf * (Vector2(4, -2) * scale), xf * (Vector2(2, 3) * scale), Color("2a221c"), 1.2, true)
		draw_line(xf * (Vector2(-2, 2.2) * scale), xf * (Vector2(8, 2.2) * scale), Color("c4a15a"), 1.3, true)
		draw_line(xf * (Vector2(6, -1) * scale), xf * (Vector2(14, 3) * scale), Color("8a8174"), 1.1, true)
		Silhouette._rim(self, world, lit, Color("d7cbb4"), 1.0)


func _draw_star(sim) -> void:
	var radius := float(sim.star_radius)
	var core := Color(str(sim.defs.system.star.color))
	var glow := core
	glow.a = 0.04
	var mid := core
	mid.a = 0.09
	var limb := core
	limb.a = 0.18
	draw_circle(Vector2.ZERO, radius * 3.5, glow)
	draw_circle(Vector2.ZERO, radius * 2.1, mid)
	draw_circle(Vector2.ZERO, radius * 1.25, limb)
	draw_circle(Vector2.ZERO, radius, core.darkened(0.24))
	draw_circle(Vector2.ZERO, radius * 0.84, core.darkened(0.08))
	draw_circle(Vector2.ZERO, radius * 0.56, core.lightened(0.06))
	draw_circle(Vector2.ZERO, radius * 0.28, core.lightened(0.2))
	draw_circle(Vector2.ZERO, radius * 0.11, Color("fffaf2"))
	for grain in 18:
		var n := absi(hash("helion-grain" + str(grain)))
		var ang := float(n % 628) / 100.0
		var dist := radius * (0.1 + float((n / 9) % 72) / 100.0)
		var spot := Vector2.from_angle(ang) * dist
		var fleck := core.lightened(0.14) if grain % 3 != 0 else core.darkened(0.22)
		fleck.a = 0.28 + float(grain % 4) * 0.08
		draw_circle(spot, radius * (0.03 + float(grain % 3) * 0.012), fleck)
	for ray in 4:
		var spike_dir := Vector2.from_angle(float(ray) * TAU / 4.0 + 0.2)
		var spike := core
		spike.a = 0.13
		draw_line(-spike_dir * radius * 2.15, spike_dir * radius * 2.15, spike, maxf(1.0, radius * 0.018), true)
	draw_arc(Vector2.ZERO, radius * 0.97, 0.0, TAU, 96, core.darkened(0.45), maxf(2.0, radius * 0.07), true)
	for tongue in 5:
		var a0 := float(tongue) * 1.25 + 0.35
		var prom := core.lightened(0.04)
		prom.a = 0.2
		draw_arc(Vector2.ZERO, radius * (1.06 + float(tongue % 2) * 0.05), a0, a0 + 0.5, 8, prom, maxf(1.3, radius * 0.02), true)


func _shade_sphere(center: Vector2, radius: float, base: Color, lit: Vector2) -> void:
	draw_circle(center, radius, base.darkened(0.7))
	var shifts: Array[float] = [0.08, 0.18, 0.3, 0.42, 0.52]
	var radii: Array[float] = [0.9, 0.72, 0.54, 0.36, 0.18]
	var lift: Array[float] = [0.2, 0.38, 0.56, 0.74, 0.92]
	for i in shifts.size():
		var tone := base.darkened(0.52 * (1.0 - lift[i])).lerp(base.lightened(0.12), lift[i])
		draw_circle(center + lit * radius * shifts[i], radius * radii[i], tone)


func _roll(key: String, salt: int) -> float:
	var n := absi(hash(key + ":" + str(salt)))
	return float(n % 1000) / 1000.0


func _light_at(pos: Vector2) -> Vector2:
	if pos.length_squared() < 6400.0:
		return Vector2(0, -1)
	return -pos.normalized()


func _draw_planet(sim, body: Dictionary) -> void:
	var pos: Vector2 = body.pos
	var radius := float(body.radius)
	var colors: Array = body.colors
	var base := Color(colors[0])
	var lit := _light_at(pos)
	var air := Color(colors[2])
	var land := Color(colors[1])
	var haze := air
	haze.a = 0.08
	air.a = 0.15
	draw_circle(pos, radius + maxf(48.0, radius * 0.11), haze)
	draw_circle(pos, radius + maxf(18.0, radius * 0.04), air)
	_shade_sphere(pos, radius, base, lit)
	var spin := float(body.get("spin", 0.1))
	var band_w := maxf(1.6, radius * 0.007)
	var body_id := str(body.get("id", "body"))
	for i in 5:
		var a0: float = float(sim.time) * spin + float(i) * 1.2
		var band := land
		band.a = 0.5
		draw_arc(pos, radius * (0.26 + float(i) * 0.12), a0, a0 + 1.4, 18, band, band_w, true)
	for patch in 6:
		var ang := _roll(body_id, patch) * TAU
		var dist := radius * (0.12 + _roll(body_id, patch + 30) * 0.45)
		var spot := pos + Vector2.from_angle(ang) * dist
		var face := clampf((spot - pos).normalized().dot(lit) * 0.5 + 0.5, 0.15, 1.0)
		var tone := land.darkened(0.4).lerp(land.lightened(0.06), face)
		draw_circle(spot, radius * (0.035 + _roll(body_id, patch + 60) * 0.045), tone)
	draw_circle(pos - lit * radius * 0.18, radius * 0.58, Color(0.008, 0.012, 0.02, 0.4))
	var legal := str(body.get("legal", ""))
	if legal.contains("capital") or legal.contains("pdo") or bool(body.get("junk", false)):
		for lamp in 16:
			var lamp_ang := _roll(body_id, 90 + lamp) * TAU
			var lamp_dist := radius * (0.16 + _roll(body_id, 140 + lamp) * 0.5)
			var lamp_spot := pos + Vector2.from_angle(lamp_ang) * lamp_dist
			var night := clampf(-(lamp_spot - pos).normalized().dot(lit), 0.0, 1.0)
			if night < 0.2:
				continue
			draw_circle(lamp_spot, maxf(1.3, radius * 0.014), Color(1.0, 0.84, 0.5, 0.12 + night * 0.5))
	var pole := Vector2(-lit.y, lit.x)
	draw_circle(pos + pole * radius * 0.58, radius * 0.07, Color(0.92, 0.95, 0.97, 0.22))
	var cloud := Color(1, 1, 1, 0.11)
	for wisp in 4:
		var w0 := float(sim.time) * spin * 0.4 + float(wisp) * 1.55
		draw_arc(pos + lit * radius * 0.08, radius * (0.34 + float(wisp) * 0.11), w0, w0 + 0.9, 10, cloud, maxf(1.6, radius * 0.005), true)
	var limb_col := base.lightened(0.55)
	limb_col.a = 0.55
	var limb_a := lit.angle()
	draw_arc(pos, radius * 0.985, limb_a - 1.2, limb_a + 1.2, 26, limb_col, maxf(2.4, radius * 0.05), true)
	var air_limb := air
	air_limb.a = 0.32
	draw_arc(pos, radius * 1.025, limb_a - 0.85, limb_a + 0.85, 16, air_limb, maxf(2.0, radius * 0.028), true)
	draw_circle(pos + lit * radius * 0.56, maxf(1.5, radius * 0.04), Color(1, 1, 1, 0.5))
	draw_circle(pos + lit * radius * 0.4, maxf(2.2, radius * 0.08), Color(1, 1, 1, 0.12))
	if bool(body.ring):
		var ice := Color("d5e4ee") if str(body.get("ring_kind", "")) == "ice" else Color(colors[2])
		var band := maxf(36.0, radius * 0.085)
		var ring_w := maxf(2.4, radius * 0.012)
		draw_arc(pos, radius + band * 0.72, 0.0, TAU, 72, ice.darkened(0.35), ring_w * 0.45, true)
		for seg in 28:
			var a0 := float(seg) * TAU / 28.0
			var facing := clampf(Vector2.from_angle(a0 + 0.13).dot(lit) * 0.5 + 0.5, 0.12, 1.0)
			var ring_col := ice.darkened(0.5).lerp(ice.lightened(0.2), facing)
			ring_col.a = 0.45 + facing * 0.5
			draw_arc(pos, radius + band, a0, a0 + 0.18, 4, ring_col, ring_w + facing, true)
			draw_arc(pos, radius + band * 1.38, a0 + 0.04, a0 + 0.14, 3, ring_col.darkened(0.18), ring_w * 0.4, true)
			if seg % 4 == 0:
				var chunk := pos + Vector2.from_angle(a0 + 0.08) * (radius + band)
				draw_circle(chunk, maxf(1.6, radius * 0.012), ring_col.lightened(0.15))
		draw_arc(pos, radius + band * 1.16, 0.0, TAU, 64, Color(0.02, 0.025, 0.03, 0.55), ring_w, true)
		draw_arc(pos, radius + band * 1.5, 0.0, TAU, 72, Color("9eb4c4"), ring_w * 0.35, true)
	if bool(body.moon):
		var moon_r := maxf(22.0, radius * 0.1)
		var moon: Vector2 = pos + Vector2.from_angle(sim.time * 0.35 + 0.6) * (radius + moon_r * 3.1)
		var moon_col := Color(colors[1])
		draw_circle(moon, moon_r, moon_col.darkened(0.5))
		draw_circle(moon + lit * moon_r * 0.28, moon_r * 0.72, moon_col.darkened(0.08))
		draw_circle(moon + lit * moon_r * 0.42, moon_r * 0.24, moon_col.lightened(0.2))
		draw_circle(moon - lit * moon_r * 0.22, moon_r * 0.2, moon_col.darkened(0.55))
		draw_circle(moon + Vector2(moon_r * 0.16, -moon_r * 0.22), moon_r * 0.12, moon_col.darkened(0.4))
	if bool(body.junk):
		for k in 6:
			var ang := float(k) * 1.05 + float(body.angle)
			var junk: Vector2 = pos + Vector2.from_angle(ang) * (radius + radius * 0.08 + float(k) * radius * 0.02)
			var tangent := Vector2.from_angle(ang + PI * 0.5)
			draw_line(junk - tangent * radius * 0.04, junk + tangent * radius * 0.04, Color(colors[1]), maxf(2.0, radius * 0.01), true)


func _draw_pocket(sim) -> void:
	var radius := float(sim.defs.system.pocket.radius)
	draw_circle(sim.pocket_pos, radius, Color(0.45, 0.58, 0.42, 0.08))
	draw_arc(sim.pocket_pos, radius, 0.0, TAU, 64, Color("9aaf8c"), 1.4, true)
	for i in 8:
		var p: Vector2 = sim.pocket_pos + Vector2.from_angle(float(i) * TAU / 8.0) * radius
		draw_line(p + Vector2(0, -10), p + Vector2(0, 10), Color("cbb892"), 2.0, true)
	draw_line(sim.pocket_pos + Vector2(-14, 0), sim.pocket_pos + Vector2(14, 0), Color("cbb892"), 1.2, true)
	draw_line(sim.pocket_pos + Vector2(0, -14), sim.pocket_pos + Vector2(0, 14), Color("cbb892"), 1.2, true)
	for tick in 12:
		var tick_a := float(tick) * TAU / 12.0
		var inner_p: Vector2 = sim.pocket_pos + Vector2.from_angle(tick_a) * radius * 0.7
		var outer_p: Vector2 = sim.pocket_pos + Vector2.from_angle(tick_a) * radius * 0.82
		draw_line(inner_p, outer_p, Color("9aaf8c"), 1.3, true)


func _draw_gates(sim) -> void:
	for gate in sim.gates:
		var row: Dictionary = gate
		var pos: Vector2 = row.pos
		var radius := float(row.radius)
		var tone := str(row.get("color", "green"))
		var buoy := Color("7d9a86")
		if tone == "amber":
			buoy = Color("c4a15a")
		elif tone == "red":
			buoy = Color("a85a4a")
		var wash := buoy
		wash.a = 0.08
		var halo := buoy
		halo.a = 0.035
		draw_circle(pos, radius * 1.22, halo)
		draw_circle(pos, radius, wash)
		draw_circle(pos, radius * 0.35, Color(buoy.r, buoy.g, buoy.b, 0.12))
		draw_arc(pos, radius, 0.0, TAU, 48, buoy.darkened(0.35), 3.2, true)
		draw_arc(pos, radius, 0.0, TAU, 48, buoy, 1.5, true)
		draw_arc(pos, radius * 0.72, 0.0, TAU, 36, buoy.lightened(0.15), 1.0, true)
		draw_arc(pos, radius * 0.55, 0.0, TAU, 32, Color("f0e2b0"), 1.2, true)
		for spoke in 4:
			var arm := Vector2.from_angle(float(spoke) * TAU / 4.0 + 0.4)
			draw_line(pos + arm * radius * 0.2, pos + arm * radius * 0.7, buoy.darkened(0.2), 1.2, true)
		for cardinal in 4:
			var buoy_pos := pos + Vector2.from_angle(float(cardinal) * TAU / 4.0) * radius
			draw_line(buoy_pos, buoy_pos + Vector2(0, 7), buoy.darkened(0.4), 1.4, true)
			draw_circle(buoy_pos, 4.2, Color(buoy.r, buoy.g, buoy.b, 0.18))
			draw_circle(buoy_pos, 3.2, buoy.darkened(0.3))
			draw_circle(buoy_pos + Vector2(-0.8, -0.8), 1.3, buoy.lightened(0.4))
		draw_circle(pos, 5.0, Color(1.0, 0.94, 0.8, 0.16))
		draw_circle(pos, 2.6, Color("fff6e0"))


func _draw_homestead(sim) -> void:
	if not bool(sim.claim.get("owned", false)):
		return
	if str(sim.claim.get("system_id", "")) != str(sim.defs.system.id):
		return
	var origin := Vector2(float(sim.claim.get("x", 0.0)), float(sim.claim.get("y", 0.0)))
	var frozen := bool(sim.claim.get("frozen", false))
	var ruptured := bool(sim.claim.get("ruptured", false))
	var border := Color("9fbf78") if not frozen else Color("6a6458")
	draw_arc(origin, 150.0, 0.0, TAU, 64, border, 2.2, true)
	var dome_col := Color("d7e6c8")
	if ruptured or frozen:
		dome_col = Color("5c4038")
	var dome_lit := _light_at(origin)
	draw_circle(origin, 26.0, Color(0, 0, 0, 0.18))
	draw_circle(origin, 22.0, dome_col.darkened(0.35))
	draw_circle(origin + dome_lit * 5.0, 16.0, dome_col.darkened(0.08))
	draw_circle(origin + dome_lit * 9.0, 8.0, dome_col.lightened(0.16))
	draw_circle(origin + dome_lit * 11.0, 3.2, Color(1, 1, 1, 0.4))
	var glass_a := dome_lit.angle()
	draw_arc(origin + dome_lit * 3.0, 8.0, glass_a - 0.7, glass_a + 0.7, 8, Color(1, 1, 1, 0.45), 1.3, true)
	for rib in 4:
		var rib_a := float(rib) * TAU / 4.0
		draw_arc(origin, 16.0, rib_a, rib_a + 0.9, 6, Color(0.2, 0.28, 0.18, 0.55), 1.2, true)
	draw_arc(origin, 22.0, 0.0, TAU, 28, Color("243020"), 1.6, true)
	if not ruptured and not frozen:
		for i in 5:
			var lamp: Vector2 = origin + Vector2.from_angle(float(i) * TAU / 5.0 + sim.time) * 16.0
			draw_circle(lamp, 2.2, Color("f4e2a1"))
	var plot := origin + Vector2(70, 18)
	draw_rect(Rect2(plot - Vector2(16, 10) + Vector2(2, 3), Vector2(32, 20)), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(plot - Vector2(16, 10), Vector2(32, 20)), Color("2c3820"))
	draw_rect(Rect2(plot - Vector2(14, 8), Vector2(28, 16)), Color("6f8a48"))
	for furrow in 4:
		var fy := -6.0 + float(furrow) * 4.0
		draw_line(plot + Vector2(-12, fy + 1.2), plot + Vector2(12, fy + 1.2), Color(0.15, 0.2, 0.08, 0.45), 1.4, true)
		draw_line(plot + Vector2(-12, fy), plot + Vector2(12, fy), Color("8eae62"), 1.1, true)
	for speck in 4:
		draw_circle(plot + Vector2(-8.0 + float(speck) * 5.0, 0.5), 0.9, Color("2e3c1c"))
	draw_line(plot + Vector2(-14, -8), plot + Vector2(-14, 8), Color("cbb892"), 1.1, true)
	draw_line(plot + Vector2(14, -8), plot + Vector2(14, 8), Color("cbb892"), 1.1, true)
	draw_line(origin + Vector2(16, 6), plot + Vector2(-16, 0), Color("6a5a40"), 2.0, true)
	var pen := origin + Vector2(-62, 36)
	draw_rect(Rect2(pen - Vector2(14, 12), Vector2(28, 24)), Color("5c4630"))
	draw_rect(Rect2(pen - Vector2(12, 10), Vector2(24, 20)), Color("8a7048"))
	draw_line(pen + Vector2(-12, -5), pen + Vector2(12, -5), Color("3a2a1c"), 1.5, true)
	for post in 3:
		draw_circle(pen + Vector2(-10.0 + float(post) * 10.0, -10.0), 1.5, Color("2c2016"))
	var crate := origin + Vector2(18, -64)
	draw_rect(Rect2(crate - Vector2(9, 9), Vector2(18, 18)), Color("7a6a56"))
	draw_rect(Rect2(crate - Vector2(7, 8), Vector2(14, 14)), Color("c4b49a"))
	draw_line(crate + Vector2(-7, 0), crate + Vector2(7, 0), Color("6a5340"), 1.3, true)
	var beacon := origin + Vector2(0, 108)
	draw_circle(beacon, 5.0, Color("e7b15a") if not frozen else Color("5a5348"))
	if bool(sim.claim.get("flare", false)):
		var pulse := 0.35 + 0.4 * absf(sin(sim.time * 6.0))
		var flare := Color("e25a2a")
		flare.a = 0.16 + pulse * 0.2
		draw_circle(origin, 210.0, flare)
		draw_arc(origin, 210.0, 0.0, TAU, 48, Color("ffb080"), 3.0, true)
		_text(origin + Vector2(-46, -188), "CORE CRACK", 16, Color("ffb080"))
	if bool(sim.claim.get("turret", false)):
		var gun: Vector2 = origin + Vector2(48, 78)
		draw_circle(gun, 4.0, Color("d7e6c8"))
		draw_line(gun, gun + Vector2(0, -14), Color("e6d7bf"), 1.6, true)
	if sim.claim.has("miner"):
		var miner := Vector2(float(sim.claim.miner.x), float(sim.claim.miner.y))
		draw_colored_polygon(PackedVector2Array([
			miner + Vector2(10, 0), miner + Vector2(-8, 6), miner + Vector2(-8, -6)
		]), Color("c4512c"))


func _draw_mark(sim) -> void:
	var mark: Dictionary = sim.nav_mark
	if mark.is_empty():
		return
	if str(mark.get("system_id", "")) != str(sim.defs.system.id):
		return
	var pos := Vector2(float(mark.get("x", 0.0)), float(mark.get("y", 0.0)))
	draw_arc(pos, 54.0, 0.0, TAU, 40, Color("e7b15a"), 1.6, true)
	draw_line(sim.player.pos, pos, Color(0.91, 0.7, 0.35, 0.45), 1.2, true)
	_text(pos + Vector2(62, -22), str(mark.get("label", "mark")), 13, Color("e7b15a"))


func _draw_beacon(sim) -> void:
	var pos: Vector2 = sim.beacon_pos
	draw_arc(pos, 36.0, 0.0, TAU, 28, Color("8aa896"), 1.6, true)
	draw_circle(pos + Vector2(2, 3), 8.0, Color(0, 0, 0, 0.22))
	draw_circle(pos, 9.0, Color(0.45, 0.58, 0.48, 0.12))
	draw_circle(pos, 7.2, Color("3d4a40"))
	draw_circle(pos + Vector2(-1.4, -1.6), 5.2, Color("8aa896"))
	draw_circle(pos + Vector2(-2.2, -2.4), 2.2, Color("e7f2ea"))
	draw_arc(pos, 7.2, 0.4, 2.2, 10, Color("243028"), 1.4, true)
	draw_circle(pos, 6.0, Color(1.0, 0.95, 0.8, 0.08))
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
		layers,
		_light_at(ship.pos)
	)
	var bar := float(Fit.stats(sim.defs, ship).hit_radius)
	var frac := hp_ratio
	var origin: Vector2 = ship.pos + Vector2(-bar, -bar - 14.0)
	draw_rect(Rect2(origin, Vector2(bar * 2.0, 3.0)), Color(0, 0, 0, 0.55))
	var fill := Color("d7e6c8") if frac > 0.35 else Color("c4512c")
	draw_rect(Rect2(origin, Vector2(bar * 2.0 * frac, 3.0)), fill)
	if str(ship.agent_id) == "agent:captain" and sim.hangar_down():
		draw_circle(ship.pos + Vector2(0, -bar - 22.0), 3.5, Color("d27a6a"))


func _craft_hull(kind: String, pos: Vector2, dir: Vector2, side: Vector2) -> PackedVector2Array:
	match kind:
		"survey_probe":
			return PackedVector2Array([
				pos + dir * 12.0,
				pos + dir * 2.0 + side * 1.7,
				pos - dir * 8.0 + side * 1.2,
				pos - dir * 8.0 - side * 1.2,
				pos + dir * 2.0 - side * 1.7,
			])
		"harvest_drone":
			return PackedVector2Array([
				pos + dir * 5.5 + side * 4.6,
				pos + dir * 5.5 - side * 4.6,
				pos - dir * 5.0 - side * 4.0,
				pos - dir * 5.0 + side * 4.0,
			])
		"salvage_tender":
			return PackedVector2Array([
				pos + dir * 8.0 + side * 3.0,
				pos + dir * 3.0 + side * 5.2,
				pos - dir * 7.5 + side * 4.4,
				pos - dir * 7.5 - side * 4.4,
				pos + dir * 3.0 - side * 5.2,
				pos + dir * 8.0 - side * 3.0,
			])
		"away_shuttle":
			return PackedVector2Array([
				pos + dir * 9.0,
				pos + dir * 1.5 + side * 4.0,
				pos - dir * 6.5 + side * 3.2,
				pos - dir * 6.5 - side * 3.2,
				pos + dir * 1.5 - side * 4.0,
			])
		_:
			return PackedVector2Array([
				pos + dir * 11.0,
				pos + dir * 1.0 + side * 2.0,
				pos - dir * 3.5 + side * 6.0,
				pos - dir * 1.2,
				pos - dir * 3.5 - side * 6.0,
				pos + dir * 1.0 - side * 2.0,
			])


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
	var kind := str(item.def_id)
	var hull_pts := _craft_hull(kind, pos, dir, side)
	var lit := _light_at(pos)
	var far := PackedVector2Array()
	var near := PackedVector2Array()
	for point in hull_pts:
		far.append(point - lit * 5.0)
		near.append(point - lit * 2.0)
	draw_colored_polygon(far, Color(0, 0, 0, 0.14))
	draw_colored_polygon(near, Color(0, 0, 0, 0.34))
	draw_colored_polygon(hull_pts, col.darkened(0.46))
	draw_colored_polygon(Silhouette._inset_world(hull_pts, 1.2, lit * 0.8), col.darkened(0.1))
	draw_colored_polygon(Silhouette._inset_world(hull_pts, 2.4, lit * 1.8), col.lightened(0.16))
	Silhouette._rim(self, hull_pts, lit, col.lightened(0.35), 1.0)
	if kind == "survey_probe":
		var dish := pos - dir * 6.2
		draw_circle(dish, 3.2, col.darkened(0.4))
		draw_arc(dish, 3.2, dir.angle() - 1.15, dir.angle() + 1.15, 8, Color(0.75, 0.92, 0.9, 0.75), 1.1, true)
		draw_circle(dish + lit * 1.1, 0.7, Color(1, 1, 1, 0.35))
	elif kind == "harvest_drone":
		draw_line(pos + side * 7.2, pos - side * 7.2, col.darkened(0.25), 1.5, true)
		draw_circle(pos + side * 7.2, 1.4, col.lightened(0.12))
		draw_circle(pos - side * 7.2, 1.4, col.lightened(0.12))
	elif kind == "salvage_tender":
		draw_line(pos - dir * 2.0 + side * 3.2, pos - dir * 2.0 - side * 3.2, col.darkened(0.45), 1.6, true)
		draw_colored_polygon(PackedVector2Array([
			pos - dir * 0.4 + side * 1.6,
			pos - dir * 0.4 - side * 1.6,
			pos - dir * 3.4 - side * 1.6,
			pos - dir * 3.4 + side * 1.6,
		]), Color(0.12, 0.1, 0.08))
	elif kind == "away_shuttle":
		draw_circle(pos + dir * 1.5, 2.2, Color(0.12, 0.16, 0.18, 0.85))
		draw_line(pos + dir * 2.4 + lit * 0.4, pos + dir * 0.4, Color(0.9, 0.95, 0.96, 0.45), 1.0, true)
	else:
		draw_line(pos - dir * 1.5 + side * 4.5, pos - dir * 1.5 - side * 4.5, col.darkened(0.35), 1.2, true)
	draw_circle(pos + dir * 3.2, 1.35, Color(0.12, 0.16, 0.18))
	draw_circle(pos + dir * 3.5 + lit * 0.5, 0.45, Color(1, 1, 1, 0.45))
	draw_line(pos - dir * 2.0, pos + dir * 5.0, col.lightened(0.28), 1.0, true)
	draw_circle(pos - dir * 4.0, 1.1, Color("e7b15a"))
	if str(item.state) == "lost":
		draw_line(pos + Vector2(-6, -6), pos + Vector2(6, 6), Color("c4512c"), 1.4, true)
	if str(item.def_id) == "survey_probe" and str(item.state) == "working":
		var frac := clampf(float(item.layers_done) / 7.0, 0.0, 1.0)
		draw_arc(pos, 16.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, Color("d7e6c8"), 1.5, true)


func _draw_wreck(wreck: Dictionary) -> void:
	var pos: Vector2 = wreck.pos
	var col := Color("5a4038") if not bool(wreck.stripped) else Color("3a3532")
	var pts := PackedVector2Array([
		pos + Vector2(10, 2), pos + Vector2(-4, 8), pos + Vector2(-12, -2), pos + Vector2(2, -8)
	])
	var lit := _light_at(pos)
	var wreck_cast := PackedVector2Array()
	for point in pts:
		wreck_cast.append(point - lit * 4.0)
	draw_colored_polygon(wreck_cast, Color(0, 0, 0, 0.22))
	draw_colored_polygon(pts, col.darkened(0.48))
	draw_colored_polygon(Silhouette._inset_world(pts, 1.4, lit * 0.8), col.darkened(0.12))
	draw_colored_polygon(Silhouette._inset_world(pts, 2.8, lit * 2.0), col.lightened(0.1))
	draw_line(pos + Vector2(-8, -6), pos + Vector2(8, 6), Color("1a0c0a"), 1.4, true)
	draw_line(pos + Vector2(-2, 6), pos + Vector2(6, -4), Color("2a1814"), 1.0, true)
	draw_line(pos + Vector2(-5, 1), pos + Vector2(3, -2), Color("8a3a22"), 1.7, true)
	draw_circle(pos + Vector2(-2, 1), 2.1, Color(0.55, 0.22, 0.08, 0.55))
	draw_circle(pos + Vector2(-2, 1), 0.8, Color(1.0, 0.72, 0.35, 0.45))
	draw_line(pos + Vector2(-14, 5), pos + Vector2(-9, 2), Color("4a4038"), 1.2, true)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(16, 6), pos + Vector2(11, 3), pos + Vector2(15, 1)
	]), col.lightened(0.05))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(13, -3), pos + Vector2(6, 0), pos + Vector2(10, 4)
	]), col.lightened(0.08))
	draw_line(pos + Vector2(8, -6), pos + Vector2(14, -2), Color("3a3532"), 1.2, true)
	draw_circle(pos + lit * 3.0, 1.5, Color(0.85, 0.7, 0.5, 0.35))


func _draw_velocity(ship: Dictionary) -> void:
	if ship.vel.length() < 8.0:
		return
	draw_line(ship.pos, ship.pos + ship.vel * 0.35, Color(0.90, 0.86, 0.75, 0.35), 1.0, true)
	var forward := Vector2.from_angle(ship.rot)
	draw_line(ship.pos + forward * 24.0, ship.pos + forward * 42.0, Color("e6d7bf"), 1.4, true)


func _draw_scale(zoom: float) -> void:
	var raw := 140.0 / zoom
	var mag := pow(10.0, floor(log(maxf(raw, 1.0)) / log(10.0)))
	var length := mag
	if raw / mag > 5.0:
		length = mag * 5.0
	elif raw / mag > 2.0:
		length = mag * 2.0
	var screen := get_viewport_rect().size
	var px := length * zoom
	var origin := Vector2(28.0, screen.y - 36.0)
	var xf := cam.get_canvas_transform().affine_inverse()
	draw_set_transform_matrix(xf)
	draw_line(origin, origin + Vector2(px, 0), Color("cbb892"), 2.0, true)
	draw_line(origin, origin + Vector2(0, -7), Color("cbb892"), 2.0, true)
	draw_line(origin + Vector2(px, 0), origin + Vector2(px, -7), Color("cbb892"), 2.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_text(xf * (origin + Vector2(0, -18)), "%d m" % int(length), 13, Color("cbb892"))


func _draw_names(sim, zoom: float) -> void:
	_text(Vector2(0, -float(sim.star_radius) - 28.0), str(sim.defs.system.star.name), 16, Color("f0c27a"))
	for body in sim.planets:
		_text(body.pos + Vector2(body.radius * 0.2, -body.radius - 18.0), str(body.name), 16, Color("e6d7bf"))
	var pocket_name := str(sim.defs.system.pocket.name)
	if not bool(sim.defs.system.pocket.get("plantable", false)):
		pocket_name = "%s — closed" % pocket_name
	_text(sim.pocket_pos + Vector2(-70, -float(sim.defs.system.pocket.radius) - 16.0), pocket_name, 15, Color("c5d2b4"))
	if zoom < 0.4 and float(sim.defs.system.zones.amber.radius) > 1.0:
		_text(sim.nest_pos + Vector2(-40, -float(sim.defs.system.zones.amber.radius) - 12.0), "The Slat — amber", 14, Color("c4923a"))
	var pad_name := "Dock beacon"
	if int(sim.defs.system.pdo.get("count", 0)) <= 0:
		pad_name = "Repair pad"
	_text(sim.beacon_pos + Vector2(-46, -22), pad_name, 13, Color("8aa896"))
	for gate in sim.gates:
		var row: Dictionary = gate
		_text(row.pos + Vector2(-50, -float(row.radius) - 14.0), str(row.name), 13, Color("e6d7a8"))
	if bool(sim.claim.get("owned", false)) and str(sim.claim.get("system_id", "")) == str(sim.defs.system.id):
		var origin := Vector2(float(sim.claim.get("x", 0.0)), float(sim.claim.get("y", 0.0)))
		_text(origin + Vector2(-36, -168), "Claim", 14, Color("d5e2b8"))
	var mix := str(sim.defs.system.get("belt", {}).get("composition", ""))
	if mix != "" and sim.asteroids.size() > 0:
		var sample: Vector2 = sim.asteroids[0].pos
		_text(sample + Vector2(-40, -24), mix, 13, Color("b7a48a"))
	if zoom < 0.55 and sim.trash.size() > 0:
		var pile: Vector2 = sim.trash[0].pos
		_text(pile + Vector2(-30, -28), str(sim.defs.system.trash.name), 14, Color("c2b49a"))
	for place in sim.nodes:
		if str(place.kind) == "planet":
			continue
		_text(place.pos + Vector2(12, -16), str(place.name), 13, Color("c5d4de"))
	var player_name := str(sim.defs.ships[sim.player.class_id].callsign)
	var player_tag := Law.scan_tag(sim, sim.player)
	if player_tag != "":
		player_name = "%s  %s" % [player_name, player_tag]
	_text(sim.player.pos + Vector2(18, 18), player_name, 14, Color("e6d7bf"))
	for mate in sim.captains:
		if not bool(mate.get("alive", false)):
			continue
		var mate_name := str(sim.defs.ships[mate.class_id].callsign)
		var mate_tag := Law.scan_tag(sim, mate)
		if mate_tag != "":
			mate_name = "%s  %s" % [mate_name, mate_tag]
		_text(mate.pos + Vector2(18, 18), mate_name, 14, Color("e6d7bf"))
	for disc in Law.discs(sim):
		var row: Dictionary = disc
		if float(row.get("radius", 0.0)) < 2.0:
			continue
		var label_at: Vector2 = row.pos + Vector2(-70, -float(row.radius) - 16.0)
		_text(label_at, str(row.get("label", "")), 13, Law.color_of(str(row.get("kind", "dark"))))
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
	var upright := 0.0
	if cam != null:
		upright = cam.rotation
	draw_set_transform(pos, upright, Vector2.ONE)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
