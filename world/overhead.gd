extends Node

## Looks down on a 3D sector from above, a little off vertical.

var sector: Node2D
var world_vp: SubViewport
var cam3: Camera3D
var board: MeshInstance3D
var stage: Node3D
var env: Environment
var _ease := 1.0
var _saw_mode := false
var _was_sector := false


func _ready() -> void:
	process_priority = 20
	world_vp = SubViewport.new()
	world_vp.name = "WorldView"
	world_vp.disable_3d = true
	world_vp.transparent_bg = false
	world_vp.handle_input_locally = false
	world_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	world_vp.size = Vector2i(1280, 720)
	add_child(world_vp)
	sector = preload("res://world/sector_view.gd").new()
	sector.name = "Sector"
	world_vp.add_child(sector)
	var rig := Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	cam3 = Camera3D.new()
	cam3.name = "Eye"
	cam3.current = true
	cam3.fov = 50.0
	cam3.near = 2.0
	cam3.far = 80000.0
	rig.add_child(cam3)
	stage = preload("res://world/stage3d.gd").new()
	stage.name = "Stage"
	stage.process_priority = 5
	rig.add_child(stage)
	var world := WorldEnvironment.new()
	world.name = "Sky"
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07080c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.58, 0.7)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.52
	env.glow_strength = 0.85
	env.glow_bloom = 0.14
	env.glow_hdr_threshold = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color("07080c")
	# Band density used to reach optical depth ~4 inside the far clip, so a
	# chart-height camera faded the whole sector to the clear color.
	env.fog_density = 0.000012
	env.fog_aerial_perspective = 0.22
	world.environment = env
	rig.add_child(world)
	board = MeshInstance3D.new()
	board.name = "Board"
	board.visible = false
	rig.add_child(board)
	var scale_layer := CanvasLayer.new()
	scale_layer.layer = 4
	var readout := ScaleReadout.new()
	readout.name = "Scale"
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.set_anchors_preset(Control.PRESET_FULL_RECT)
	scale_layer.add_child(readout)
	add_child(scale_layer)
	RenderingServer.set_default_clear_color(Color("07080c"))
	_fit()
	var host := get_viewport()
	if host != null and host.size_changed.is_connected(_fit) == false:
		host.size_changed.connect(_fit)


func _process(delta: float) -> void:
	if cam3 == null or cam3.current == false:
		return
	var sector_on := Game.mode == "sector"
	if _saw_mode == false:
		_saw_mode = true
		_was_sector = sector_on
		_ease = 1.0
	elif sector_on and _was_sector == false:
		_ease = 0.0
		_was_sector = true
	else:
		_was_sector = sector_on
	if _ease < 1.0:
		_ease = minf(1.0, _ease + delta / 1.45)
	_aim()


func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	world_vp.size = Vector2i(maxi(int(screen.x), 2), maxi(int(screen.y), 2))
	_aim()


func _aim() -> void:
	if cam3 == null or sector == null or Game.sim == null or Game.mode != "sector":
		return
	var zoom := maxf(Game.zoom, 0.12)
	var chase: Vector2 = sector._chase_pos()
	var layer := int(Game.sim.layer)
	if layer == ScaleFrame.CHART:
		# A light bias keeps the well on the wide chart. The keel stays the
		# thing you steer, not a speck pulled off the pad of the phone.
		var well := _chart_well(Game.sim)
		chase = chase.lerp(well, 0.1)
	var gate: Variant = WorldCoord.gate()
	if gate != null:
		chase = gate.render_of_world(chase)
	var height := 920.0 / zoom
	var far := 80000.0
	var density := 0.000012
	if layer == ScaleFrame.CHART:
		height = 7800.0 / zoom
		far = 80000.0
		density = 0.0000025
	elif layer == ScaleFrame.APPROACH:
		height = 14000.0 / zoom
		far = 120000.0
		density = 0.000004
	elif layer == ScaleFrame.SITE:
		height = 220.0 / zoom
		far = 6000.0
		density = 0.00004
	elif layer == ScaleFrame.BAND:
		# Berth keeps the cruise angle (back = height * 0.62, fov 50) and looks
		# between the keel and the planet, so the pad reads and Aegis sits beside
		# it. The cruise lead is tuned for the high camera and hides that pair.
		var berth := 220.0 / zoom
		var player: Dictionary = Game.sim.player
		var ship: Vector2 = player.pos
		var pad := Vector2(float(player.get("dock_x", ship.x)), float(player.get("dock_y", ship.y)))
		var away: float = ship.distance_to(pad)
		var moored := bool(player.get("moored", false))
		var world_focus: Vector2 = Game.sim.view_focus()
		var framed: Vector2 = world_focus
		var body: Variant = Game.sim.planet(str(Game.sim.body_id))
		if body != null:
			var row: Dictionary = body
			var center: Vector2 = row.pos
			var toward: Vector2 = center - world_focus
			if toward.length() > 80.0:
				var screen := get_viewport().get_visible_rect().size
				var aspect := screen.x / maxf(screen.y, 1.0)
				var half_world := berth * 1.176 * tan(deg_to_rad(25.0)) * aspect
				var lead := clampf(half_world * 0.34, 0.0, toward.length() * 0.28)
				framed = world_focus + toward.normalized() * lead
		if gate != null:
			framed = gate.render_of_world(framed)
		if moored:
			height = berth
			chase = framed
		elif away < 200.0:
			var blend := clampf(away / 200.0, 0.0, 1.0)
			height = lerpf(berth, height, blend)
			chase = framed.lerp(chase, blend)
	if env != null:
		env.fog_density = density
	var back := height * 0.62
	var target := Vector3(chase.x, 0.0, -chase.y)
	cam3.fov = 50.0
	# The yard opens on a wide Helion limb. The first moments at the pad
	# pull back along the same berth angle, then settle to the working helm.
	if layer == ScaleFrame.BAND and bool(Game.sim.player.get("moored", false)) and _ease < 0.999:
		var settle := _ease * _ease * (3.0 - 2.0 * _ease)
		var wide := lerpf(1.58, 1.0, settle)
		height *= wide
		back = height * 0.62
		cam3.fov = lerpf(44.0, 50.0, settle)
	cam3.far = far
	cam3.position = target + Vector3(0.0, height, -back)
	cam3.look_at(target, Vector3(0.0, 0.0, 1.0))


func _chart_well(sim) -> Vector2:
	var best := Vector2.ZERO
	var best_d := 1.0e12
	var found := false
	for body in sim.planets:
		var row: Dictionary = body
		var rel: Vector2 = row.chart_km - sim.local_origin
		var dist: float = rel.distance_to(sim.player.pos)
		if dist < best_d:
			best = rel
			best_d = dist
			found = true
	if found == false:
		return sim.view_focus()
	return ScaleFrame.chart_view(sim, best)


func set_live(on: bool) -> void:
	if cam3 != null:
		cam3.current = on
	if stage != null:
		stage.visible = on
	if world_vp != null:
		world_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


class ScaleReadout extends Control:
	func _process(_delta: float) -> void:
		visible = Game.mode == "sector" and Game.sim != null
		queue_redraw()

	func _draw() -> void:
		if Game.sim == null or Game.mode != "sector":
			return
		var helm := get_parent().get_parent()
		var cam: Camera3D = helm.get("cam3")
		var stage = helm.get("stage")
		var font := ThemeDB.fallback_font
		if cam != null and stage != null and font != null:
			var ranked: Array = []
			for item in stage.tags:
				var at: Vector3 = item.p
				if cam.is_position_behind(at):
					continue
				var dist := cam.global_position.distance_to(at)
				var reach := 2600.0
				if str(item.t) == "Helion Dock" or str(item.t) == "Ice ring":
					reach = 24000.0
				elif Game.sim != null:
					var layer := int(Game.sim.layer)
					if layer == ScaleFrame.CHART or layer == ScaleFrame.APPROACH:
						reach = 48000.0
				if dist > reach:
					continue
				ranked.append({"item": item, "at": at, "dist": dist})
			ranked.sort_custom(Callable(self, "_nearer_tag"))
			var drawn: Array = []
			for row in ranked:
				var tag: Dictionary = row.item
				var sp: Vector2 = cam.unproject_position(row.at)
				if sp.x < -30.0 or sp.y < -10.0 or sp.x > size.x + 30.0 or sp.y > size.y - 88.0:
					continue
				var text := str(tag.t)
				var font_size := int(tag.s)
				var box := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var w := maxf(box.x, 24.0)
				var h := maxf(box.y, float(font_size))
				var kept := false
				for _nudge in 5:
					var hit := false
					var mine := Rect2(sp, Vector2(w, h))
					for other in drawn:
						var taken: Rect2 = other
						if mine.intersects(taken.grow(4.0)):
							hit = true
							break
					if not hit:
						kept = true
						break
					sp.y += h + 2.0
				if not kept:
					continue
				drawn.append(Rect2(sp, Vector2(w, h)))
				var col: Color = tag.c
				draw_string(font, sp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		var zoom := maxf(Game.zoom, 0.05)
		var raw := 140.0 / zoom
		var mag := pow(10.0, floor(log(maxf(raw, 1.0)) / log(10.0)))
		var length := mag
		if raw / mag > 5.0:
			length = mag * 5.0
		elif raw / mag > 2.0:
			length = mag * 2.0
		var px := length * zoom
		if cam != null and sector_chase() != null:
			var chase: Vector2 = sector_chase()
			var a := cam.unproject_position(Vector3(chase.x, 0.0, -chase.y))
			var b := cam.unproject_position(Vector3(chase.x + length, 0.0, -chase.y))
			if cam.is_position_behind(Vector3(chase.x, 0.0, -chase.y)) == false:
				px = a.distance_to(b)
		var origin := Vector2(28.0, size.y - 36.0)
		draw_line(origin, origin + Vector2(px, 0), Color("cbb892"), 2.0, true)
		draw_line(origin, origin + Vector2(0, -7), Color("cbb892"), 2.0, true)
		draw_line(origin + Vector2(px, 0), origin + Vector2(px, -7), Color("cbb892"), 2.0, true)
		if font != null:
			draw_string(font, origin + Vector2(0, -18), "%d m" % int(length), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("cbb892"))
		_draw_dock_guide(cam, font)
		_draw_ring_guide(cam, font)

	func _draw_dock_guide(cam: Camera3D, font: Font) -> void:
		var sim = Game.sim
		if cam == null or font == null or sim == null or sim.player.is_empty():
			return
		if bool(sim.player.get("moored", false)):
			return
		if str(sim.defs.system.id) != "HC-V1-R1-S1":
			return
		var at := Vector3.ZERO
		var caption := "Helion Dock"
		var layer := int(sim.layer)
		if layer == ScaleFrame.BAND:
			var gap: float = sim.player.pos.distance_to(sim.beacon_pos)
			caption = "Helion Dock  %d m" % int(gap)
			at = _guide_at(sim.beacon_pos, 80.0)
		elif layer == ScaleFrame.CHART:
			var km: float = (sim.local_origin + sim.player.pos).distance_to(sim.dock_buoy_km())
			caption = "Helion Dock  %.0f km" % km
			at = _guide_at(sim.dock_buoy_km() - sim.local_origin, 120.0)
		elif layer == ScaleFrame.APPROACH:
			caption = "Helion Dock"
			at = Vector3(0.0, 80.0, 0.0)
		else:
			return
		var sp := cam.unproject_position(at)
		var behind := cam.is_position_behind(at)
		var margin := 36.0
		var edge := Rect2(Vector2(margin, margin), size - Vector2(margin * 2.0, margin * 2.0 + 80.0))
		var center := size * 0.5
		var on_screen := behind == false and edge.has_point(sp)
		if on_screen:
			draw_rect(Rect2(sp + Vector2(-8, -8), Vector2(16, 16)), Color(0.45, 0.9, 0.95, 0.9), false, 2.0)
			draw_string(font, sp + Vector2(14, 4), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9eecf5"))
			return
		var aim := sp - center
		if behind:
			aim = -aim
		if aim.length() < 1.0:
			aim = Vector2.RIGHT
		aim = aim.normalized()
		var hit := center
		var limit := edge.size * 0.5
		var scale := 1.0e6
		if absf(aim.x) > 0.001:
			scale = minf(scale, limit.x / absf(aim.x))
		if absf(aim.y) > 0.001:
			scale = minf(scale, limit.y / absf(aim.y))
		hit = center + aim * scale
		var side := Vector2(-aim.y, aim.x)
		draw_colored_polygon(PackedVector2Array([hit + aim * 14.0, hit - aim * 8.0 + side * 8.0, hit - aim * 8.0 - side * 8.0]), Color("9eecf5"))
		draw_string(font, hit + side * 12.0 - Vector2(0, 8), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("9eecf5"))

	func _draw_ring_guide(cam: Camera3D, font: Font) -> void:
		var sim = Game.sim
		if cam == null or font == null or sim == null or sim.player.is_empty():
			return
		if int(sim.layer) != ScaleFrame.BAND:
			return
		var beam: Vector2 = DockBoard.cue_aim(sim)
		if beam.length() < 8.0:
			return
		var caption := DockBoard.slip_line(sim)
		if caption == "":
			return
		# The fly cue leaves the keel along keel→target. A far inward drop
		# sits behind the berth camera; unprojecting it and flipping the
		# edge arrow points outward, and the meters climb.
		var dir := beam.normalized()
		var keel_at := _guide_at(sim.player.pos, 10.0)
		var step_at := _guide_at(sim.player.pos + dir * 64.0, 12.0)
		var far_at := _guide_at(sim.player.pos + beam, 16.0)
		var keel_sp := cam.unproject_position(keel_at)
		var step_sp := cam.unproject_position(step_at)
		var far_sp := cam.unproject_position(far_at)
		var step_behind := cam.is_position_behind(keel_at) or cam.is_position_behind(step_at)
		var far_behind := cam.is_position_behind(far_at)
		var margin := 28.0
		var edge := Rect2(Vector2(margin, margin), size - Vector2(margin * 2.0, margin * 2.0 + 96.0))
		var center := size * 0.5
		var pulse := 0.72 + 0.28 * absf(sin(Time.get_ticks_msec() * 0.008))
		var ink := Color(1.0, 0.78, 0.28, pulse)
		var marked := false
		if step_behind == false:
			var fly := step_sp - keel_sp
			if fly.length() > 6.0:
				fly = fly.normalized()
				var tip := keel_sp + fly * 56.0
				var wing := Vector2(-fly.y, fly.x)
				draw_line(keel_sp + fly * 18.0, tip, ink, 5.0, true)
				draw_colored_polygon(PackedVector2Array([tip + fly * 16.0, tip - fly * 8.0 + wing * 11.0, tip - fly * 8.0 - wing * 11.0]), ink)
				if edge.has_point(tip):
					draw_string(font, tip + wing * 14.0 - Vector2(0, 8), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
					marked = true
		if far_behind == false and edge.has_point(far_sp):
			draw_rect(Rect2(far_sp + Vector2(-11, -11), Vector2(22, 22)), ink, false, 3.0)
			draw_rect(Rect2(far_sp + Vector2(-4, -4), Vector2(8, 8)), ink, true)
			if marked == false:
				draw_string(font, far_sp + Vector2(16, 6), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
			return
		if marked:
			return
		var aim := _screen_aim(cam, beam)
		if aim.length() < 0.2:
			aim = Vector2.UP
		aim = aim.normalized()
		var limit := edge.size * 0.5
		var scale := 1.0e6
		if absf(aim.x) > 0.001:
			scale = minf(scale, limit.x / absf(aim.x))
		if absf(aim.y) > 0.001:
			scale = minf(scale, limit.y / absf(aim.y))
		var hit := center + aim * scale
		var side := Vector2(-aim.y, aim.x)
		draw_colored_polygon(PackedVector2Array([hit + aim * 18.0, hit - aim * 10.0 + side * 10.0, hit - aim * 10.0 - side * 10.0]), ink)
		draw_string(font, hit + side * 14.0 - Vector2(0, 10), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)


	func _screen_aim(cam: Camera3D, world_delta: Vector2) -> Vector2:
		var dir := Vector3(world_delta.x, 0.0, -world_delta.y)
		if dir.length() < 0.001:
			return Vector2.UP
		dir = dir.normalized()
		var axes := cam.global_transform.basis
		var screen := Vector2(dir.dot(axes.x), -dir.dot(axes.y))
		if screen.length() < 0.001:
			return Vector2.UP
		return screen.normalized()


	func _guide_at(world: Vector2, height: float) -> Vector3:
		var shown: Vector2 = DockBoard.marker_xy(Game.sim, world)
		return Vector3(shown.x, height, -shown.y)


	func _nearer_tag(a: Dictionary, b: Dictionary) -> bool:
		return float(a.dist) < float(b.dist)


	func sector_chase():
		var helm := get_parent().get_parent()
		var view = helm.get("sector")
		if view != null and view.has_method("_chase_pos") and Game.sim != null:
			return view._chase_pos()
		return null
