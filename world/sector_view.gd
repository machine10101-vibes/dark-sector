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
		var link = Game.link
		if link != null and str(link.role) == "client":
			link.take_client(Game.sim)
			link.send_cmd(str(Game.sim.player.get("player_id", "")), _cmd())
		else:
			if link != null and str(link.role) == "host":
				link.take_host(Game.sim)
			Game.sim.tick(delta, _cmd())
			if link != null and str(link.role) == "host":
				link.broadcast(Game.sim)
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
	var cmd := {
		"thrust": 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0,
		"retro": 1.0 if (Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0,
		"rot": rot,
		"strafe": strafe,
		"fire": Input.is_key_pressed(KEY_SPACE),
	}
	var verbs: Dictionary = Game.take_verbs()
	for key in verbs.keys():
		cmd[key] = verbs[key]
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
	for mate in sim.captains:
		if bool(mate.get("alive", false)):
			_draw_ship(sim, mate)
			_draw_velocity(mate)
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
		var tint := Color(str(rock.get("tint", "#3a342c")))
		draw_colored_polygon(verts, tint)
		if verts.size() > 1:
			var outline := verts.duplicate()
			outline.append(verts[0])
			draw_polyline(outline, Color("6a5c4a"), 1.0, true)


func _draw_meteors(sim) -> void:
	for rock in sim.meteors:
		var pos: Vector2 = rock.pos
		var size := float(rock.get("size", 4.0))
		draw_circle(pos, size, Color("c46a3a"))
		draw_line(pos, pos - Vector2.from_angle(float(sim.defs.system.get("stream", {}).get("vector", 0.0))) * 18.0, Color("e0a070"), 1.2, true)


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
	air.a = 0.22
	draw_circle(pos, radius + 18.0, air)
	draw_circle(pos, radius, base.darkened(0.42))
	draw_circle(pos + lit * radius * 0.22, radius * 0.9, base)
	draw_circle(pos + lit * radius * 0.4, radius * 0.28, base.lightened(0.22))
	var spin := float(body.get("spin", 0.1))
	for i in 4:
		var a0: float = float(sim.time) * spin + float(i) * 1.35
		draw_arc(pos, radius * (0.38 + float(i) * 0.13), a0, a0 + 1.35, 18, Color(colors[1]), 5.0, true)
	var night := Color(0.02, 0.03, 0.05, 0.55)
	draw_circle(pos - lit * radius * 0.34, radius * 0.86, night)
	if bool(body.ring):
		var ice := Color("d5e4ee") if str(body.get("ring_kind", "")) == "ice" else Color(colors[2])
		draw_arc(pos, radius + 36.0, 0.0, TAU, 72, ice, 2.4, true)
		draw_arc(pos, radius + 50.0, 0.0, TAU, 72, Color("9eb4c4"), 1.3, true)
	if bool(body.moon):
		var moon: Vector2 = pos + Vector2.from_angle(sim.time * 0.35 + 0.6) * (radius + 42.0)
		var moon_col := Color(colors[1])
		draw_circle(moon, 9.0, moon_col.darkened(0.35))
		draw_circle(moon + lit * 2.4, 6.2, moon_col)
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
		draw_arc(pos, radius, 0.0, TAU, 48, buoy, 1.8, true)
		draw_arc(pos, radius * 0.55, 0.0, TAU, 32, Color("f0e2b0"), 1.2, true)


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
	draw_circle(origin, 22.0, dome_col)
	draw_arc(origin, 22.0, 0.0, TAU, 24, Color("243020"), 1.4, true)
	if not ruptured and not frozen:
		for i in 5:
			var lamp: Vector2 = origin + Vector2.from_angle(float(i) * TAU / 5.0 + sim.time) * 16.0
			draw_circle(lamp, 2.2, Color("f4e2a1"))
	var plot := origin + Vector2(70, 18)
	draw_rect(Rect2(plot - Vector2(16, 10), Vector2(32, 20)), Color("6f8a48"))
	var pen := origin + Vector2(-62, 36)
	draw_rect(Rect2(pen - Vector2(14, 12), Vector2(28, 24)), Color("8a7048"))
	var crate := origin + Vector2(18, -64)
	draw_rect(Rect2(crate - Vector2(8, 8), Vector2(16, 16)), Color("c4b49a"))
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
	draw_string(font, pos + Vector2(62, -22), str(mark.get("label", "mark")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e7b15a"))


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
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
