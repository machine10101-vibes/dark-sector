extends Node

## Looks down on a 3D sector from above, a little off vertical.

var sector: Node2D
var world_vp: SubViewport
var cam3: Camera3D
var board: MeshInstance3D
var stage: Node3D
var env: Environment


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


func _process(_delta: float) -> void:
	if cam3 == null or cam3.current == false:
		return
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
	var gate: Variant = WorldCoord.gate()
	if gate != null:
		chase = gate.render_of_world(chase)
	var height := 920.0 / zoom
	var far := 80000.0
	var density := 0.000012
	var layer := int(Game.sim.layer)
	if layer == ScaleFrame.CHART:
		height = 52000.0 / zoom
		far = 420000.0
		density = 0.0000025
	elif layer == ScaleFrame.APPROACH:
		height = 160.0 / zoom
		far = 120000.0
		density = 0.000004
	elif layer == ScaleFrame.SITE:
		height = 220.0 / zoom
		far = 6000.0
		density = 0.00004
	elif layer == ScaleFrame.BAND:
		# Berth height keeps the same angle (back = height * 0.62, fov 50).
		# At the pad the cruise height leaves the Needle a speck on the disc.
		var berth := 168.0 / zoom
		var player: Dictionary = Game.sim.player
		var ship: Vector2 = player.pos
		var pad := Vector2(float(player.get("dock_x", ship.x)), float(player.get("dock_y", ship.y)))
		var away: float = ship.distance_to(pad)
		var moored := bool(player.get("moored", false))
		if moored or away < 40.0:
			height = berth
		elif away < 900.0:
			height = lerpf(berth, height, clampf(away / 900.0, 0.0, 1.0))
	if env != null:
		env.fog_density = density
	var back := height * 0.62
	var target := Vector3(chase.x, 0.0, -chase.y)
	cam3.fov = 50.0
	cam3.far = far
	cam3.position = target + Vector3(0.0, height, -back)
	cam3.look_at(target, Vector3(0.0, 0.0, 1.0))


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
				if dist > 2600.0:
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

	func _nearer_tag(a: Dictionary, b: Dictionary) -> bool:
		return float(a.dist) < float(b.dist)


	func sector_chase():
		var helm := get_parent().get_parent()
		var view = helm.get("sector")
		if view != null and view.has_method("_chase_pos") and Game.sim != null:
			return view._chase_pos()
		return null
