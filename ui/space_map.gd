extends Control

## The whole Haven chart as a massive 3D reach. Drag turns the eye. A tap
## names a system. The chart does not move the ship.

const Atlas = preload("res://ui/chart_atlas.gd")
const Stage = preload("res://ui/space_map_stage.gd")

var atlas: Dictionary = {}
var by_id: Dictionary = {}
var view_center := Vector2.ZERO
var view_span := 5.0
var cam_yaw := 0.55
var cam_pitch := 0.62
var selected := ""
var drag_on := false
var drag_origin := Vector2.ZERO
var drag_yaw := 0.0
var drag_pitch := 0.0
var drag_moved := false
var was_open := false
var board: SubViewportContainer
var vp: SubViewport
var cam: Camera3D
var stage: Node3D
var live := false
var focus3 := Vector3.ZERO
var reach := 2400.0
var card: PanelContainer
var card_title: Label
var card_body: Label
var close_button: Button
var zoom_in: Button
var zoom_out: Button
var fit_button: Button
var title: Label
var hint: Label


func _ready() -> void:
	name = "SpaceMap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 40
	set_anchors_preset(Control.PRESET_FULL_RECT)
	board = SubViewportContainer.new()
	board.name = "MapBoard"
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.stretch = true
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	vp = SubViewport.new()
	vp.name = "MapView"
	vp.own_world_3d = true
	vp.world_3d = World3D.new()
	vp.transparent_bg = false
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.size = Vector2i(1280, 720)
	board.add_child(vp)
	cam = Camera3D.new()
	cam.name = "MapEye"
	cam.current = false
	cam.fov = 48.0
	cam.near = 4.0
	cam.far = 48000.0
	vp.add_child(cam)
	stage = Stage.new()
	stage.name = "MapStage"
	vp.add_child(stage)
	title = ThemeKit.label("SPACE MAP", 18, Color("f0c27a"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	hint = ThemeKit.label("The whole reach in 3D. Drag to turn. Wheel to zoom. Tap a world. F10, Esc, or Close.", 12, Color("8aa8b0"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	close_button = ThemeKit.button("Close", true)
	close_button.custom_minimum_size = Vector2(92, 44)
	close_button.pressed.connect(func() -> void:
		Game.set_map_open(false)
	)
	add_child(close_button)
	zoom_in = ThemeKit.button("+")
	zoom_in.custom_minimum_size = Vector2(44, 40)
	zoom_in.pressed.connect(func() -> void: _zoom_map(0.82))
	add_child(zoom_in)
	zoom_out = ThemeKit.button("–")
	zoom_out.custom_minimum_size = Vector2(44, 40)
	zoom_out.pressed.connect(func() -> void: _zoom_map(1.22))
	add_child(zoom_out)
	fit_button = ThemeKit.button("Fit")
	fit_button.custom_minimum_size = Vector2(72, 40)
	fit_button.pressed.connect(_fit_all)
	add_child(fit_button)
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", ThemeKit.glass(true))
	add_child(card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	card_title = ThemeKit.label("", 18, Color("f2fbff"))
	card_body = ThemeKit.label("", 14, Color("c5d6dc"))
	box.add_child(card_title)
	box.add_child(card_body)


func _process(delta: float) -> void:
	var open := Game.map_open and Game.mode == "sector" and Game.sim != null
	if open != was_open:
		visible = open
		mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
		if cam != null:
			cam.current = open
		if vp != null:
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if open else SubViewport.UPDATE_DISABLED
		if open:
			_ensure_atlas()
			_bind_eye()
			if not live and stage != null and stage.has_method("rebuild"):
				if stage.get_parent() == null:
					vp.add_child(stage)
				stage.rebuild(atlas)
				stage.mark_visited(_visited_book(), _here())
			_fit_all()
			selected = _here()
			_fill_card()
			_layout()
			_aim_cam()
		was_open = open
	if not open:
		return
	if vp != null:
		var want := Vector2i(maxi(int(size.x), 2), maxi(int(size.y), 2))
		if vp.size != want:
			vp.size = want
	if not live and stage != null and stage.has_method("tick"):
		stage.tick(delta, _here(), selected, view_span)
	_aim_cam()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if close_button == null or size.x < 32.0:
		return
	if board != null:
		board.position = Vector2.ZERO
		board.size = size
	title.position = Vector2(16, 12)
	title.size = Vector2(minf(280.0, size.x - 140.0), 26)
	hint.position = Vector2(16, 40)
	hint.size = Vector2(minf(520.0, size.x - 130.0), 36)
	close_button.position = Vector2(size.x - 108.0, 12)
	close_button.size = Vector2(92, 44)
	zoom_in.position = Vector2(size.x - 108.0, 64)
	zoom_in.size = Vector2(44, 40)
	zoom_out.position = Vector2(size.x - 58.0, 64)
	zoom_out.size = Vector2(44, 40)
	fit_button.position = Vector2(size.x - 108.0, 112)
	fit_button.size = Vector2(92, 40)
	var card_w := 320.0 if size.x >= 720.0 else size.x - 24.0
	var card_h := 210.0 if size.y >= 560.0 else 150.0
	card.position = Vector2(12, size.y - card_h - 12)
	card.size = Vector2(card_w, card_h)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_map(0.85)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_map(1.18)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				drag_on = true
				drag_moved = false
				drag_origin = button.position
				drag_yaw = cam_yaw
				drag_pitch = cam_pitch
			else:
				if drag_on and not drag_moved:
					var hit := _pick(button.position)
					if hit != "":
						selected = hit
						_fill_card()
				drag_on = false
			accept_event()
	elif event is InputEventMouseMotion and drag_on:
		var motion := event as InputEventMouseMotion
		if motion.position.distance_to(drag_origin) > 6.0:
			drag_moved = true
		var delta: Vector2 = motion.position - drag_origin
		cam_yaw = wrapf(drag_yaw - delta.x * 0.0075, -PI, PI)
		cam_pitch = clampf(drag_pitch + delta.y * 0.0055, 0.18, 1.32)
		accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			drag_on = true
			drag_moved = false
			drag_origin = touch.position
			drag_yaw = cam_yaw
			drag_pitch = cam_pitch
		else:
			if drag_on and not drag_moved:
				var hit := _pick(touch.position)
				if hit != "":
					selected = hit
					_fill_card()
			drag_on = false
		accept_event()
	elif event is InputEventScreenDrag and drag_on:
		var drag := event as InputEventScreenDrag
		if drag.position.distance_to(drag_origin) > 8.0:
			drag_moved = true
		var delta: Vector2 = drag.position - drag_origin
		cam_yaw = wrapf(drag_yaw - delta.x * 0.0075, -PI, PI)
		cam_pitch = clampf(drag_pitch + delta.y * 0.0055, 0.18, 1.32)
		accept_event()


func _ensure_atlas() -> void:
	var defs: Dictionary = Game.defs
	if Game.sim != null:
		defs = Game.sim.defs
	atlas = Atlas.build(defs)
	by_id = {}
	var systems: Array = atlas.get("systems", [])
	for raw in systems:
		var row: Dictionary = raw
		by_id[str(row.get("id", ""))] = row


func _fit_all() -> void:
	cam_yaw = 0.72
	cam_pitch = 0.4
	if live:
		_frame_sector()
		view_span = 4.0
		_aim_cam()
		return
	var bounds: Rect2 = atlas.get("bounds", Rect2(-1, -1, 2, 2))
	view_center = bounds.position + bounds.size * 0.5
	var aspect := size.x / maxf(size.y, 1.0)
	var half_h := bounds.size.y * 0.5 + 0.55
	var half_w := bounds.size.x * 0.5 + 0.55
	view_span = maxf(half_h, half_w / maxf(aspect, 0.25)) * 0.78
	view_span = clampf(view_span, 0.4, 14.0)
	_aim_cam()


func _zoom_map(factor: float) -> void:
	view_span = clampf(view_span * factor, 0.35, 14.0)
	_aim_cam()


func _helm() -> Node:
	var walk: Node = self
	while walk != null:
		var found := walk.get_node_or_null("Helm")
		if found != null:
			return found
		walk = walk.get_parent()
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("Helm")


func _bind_eye() -> void:
	live = false
	var helm := _helm()
	if helm == null or cam == null or vp == null:
		return
	var eye = helm.get("cam3")
	if not (eye is Camera3D):
		return
	vp.own_world_3d = false
	vp.world_3d = (eye as Camera3D).get_world_3d()
	if stage != null and stage.get_parent() == vp:
		vp.remove_child(stage)
	live = true


func _frame_sector() -> void:
	var helm := _helm()
	if helm == null or Game.sim == null:
		live = false
		return
	var live_stage = helm.get("stage")
	if live_stage == null or not live_stage.has_method("chart"):
		live = false
		return
	var pts: Array = []
	pts.append(live_stage.chart(Game.sim.player.pos, 2.0))
	pts.append(live_stage.chart(Vector2.ZERO, 4.0))
	for body in Game.sim.planets:
		var row: Dictionary = body
		pts.append(live_stage.chart(row.pos, 2.0))
	for gate in Game.sim.gates:
		var gate_row: Dictionary = gate
		pts.append(live_stage.chart(gate_row.pos, 2.0))
	if Game.sim.beacon_pos != Vector2.ZERO:
		pts.append(live_stage.chart(Game.sim.beacon_pos, 2.0))
	if Game.sim.pocket_pos != Vector2.ZERO:
		pts.append(live_stage.chart(Game.sim.pocket_pos, 2.0))
	var lo: Vector3 = pts[0]
	var hi: Vector3 = pts[0]
	for raw in pts:
		var at: Vector3 = raw
		lo.x = minf(lo.x, at.x)
		lo.y = minf(lo.y, at.y)
		lo.z = minf(lo.z, at.z)
		hi.x = maxf(hi.x, at.x)
		hi.y = maxf(hi.y, at.y)
		hi.z = maxf(hi.z, at.z)
	focus3 = (lo + hi) * 0.5
	var span := (hi - lo).length() * 0.5
	reach = clampf(span * 1.08, 720.0, 3200.0)
	cam.far = maxf(reach * 8.0, 80000.0)
	cam.fov = 50.0


func _aim_cam() -> void:
	if cam == null:
		return
	var focus := focus3
	var dist := reach * (view_span / 4.0)
	if not live:
		if stage == null:
			return
		focus = stage.world_of(view_center)
		dist = view_span * Stage.UNIT * 1.55
	var eye := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * dist
	cam.position = focus + eye
	if eye.length() > 0.01:
		cam.look_at(focus, Vector3.UP)


func _here() -> String:
	if Game.sim == null:
		return ""
	return str(Game.sim.defs.system.get("id", ""))


func _visited(system_id: String) -> bool:
	if Game.sim == null:
		return false
	return Game.sim.visited.has(system_id)


func _visited_book() -> Dictionary:
	var book: Dictionary = {}
	if Game.sim == null:
		return book
	for key in Game.sim.visited:
		book[str(key)] = true
	return book


func _pick(screen_at: Vector2) -> String:
	if cam == null:
		return ""
	if live:
		return _pick_sector(screen_at)
	var best := ""
	var best_d := 28.0
	var systems: Array = atlas.get("systems", [])
	for raw in systems:
		var row: Dictionary = raw
		var world: Vector3 = stage.world_of(Vector2(row.get("pos", Vector2.ZERO)))
		if cam.is_position_behind(world):
			continue
		var at := cam.unproject_position(world)
		var dist := at.distance_to(screen_at)
		if dist < best_d:
			best_d = dist
			best = str(row.get("id", ""))
	return best


func _pick_sector(screen_at: Vector2) -> String:
	var helm := _helm()
	if helm == null or Game.sim == null:
		return _here()
	var live_stage = helm.get("stage")
	if live_stage == null or not live_stage.has_method("chart"):
		return _here()
	var best := _here()
	var best_d := 36.0
	for body in Game.sim.planets:
		var row: Dictionary = body
		var world: Vector3 = live_stage.chart(row.pos, 2.0)
		if cam.is_position_behind(world):
			continue
		var at := cam.unproject_position(world)
		var dist := at.distance_to(screen_at)
		if dist < best_d:
			best_d = dist
			best = str(row.get("id", ""))
	for gate in Game.sim.gates:
		var row: Dictionary = gate
		var world: Vector3 = live_stage.chart(row.pos, 2.0)
		if cam.is_position_behind(world):
			continue
		var at := cam.unproject_position(world)
		var dist := at.distance_to(screen_at)
		if dist < best_d:
			best_d = dist
			best = str(row.get("id", ""))
	if Game.sim.beacon_pos != Vector2.ZERO:
		var world: Vector3 = live_stage.chart(Game.sim.beacon_pos, 2.0)
		if not cam.is_position_behind(world):
			var at := cam.unproject_position(world)
			if at.distance_to(screen_at) < best_d:
				best = "beacon"
	return best


func _fill_local_card() -> void:
	if Game.sim == null:
		card_title.text = "The reach"
		card_body.text = "The whole sky of this system."
		return
	if selected == "beacon":
		card_title.text = "Helion Dock"
		card_body.text = "The pad. This is the local reach, rendered in full."
		return
	var body = Game.sim.planet(selected)
	if body != null:
		card_title.text = str(body.get("name", selected))
		card_body.text = "A world in this sky. Drag to turn. Wheel to zoom."
		return
	for gate in Game.sim.gates:
		var row: Dictionary = gate
		if str(row.get("id", "")) == selected:
			card_title.text = str(row.get("name", "Lane"))
			card_body.text = "A lane ring. Fly into it, then take the lane."
			return
	card_title.text = str(Game.sim.defs.system.get("name", "The reach"))
	card_body.text = "The whole sky of this system. Drag to turn. Wheel to zoom."


func _fill_card() -> void:
	if live and Game.sim != null and not by_id.has(selected):
		_fill_local_card()
		return
	var row: Dictionary = by_id.get(selected, {})
	if row.is_empty():
		card_title.text = "The reach"
		card_body.text = "The whole sky of this system. Drag to turn. Wheel to zoom. Tap a world. The chart does not move the ship."
		return
	card_title.text = str(row.get("name", ""))
	var lines := str(row.get("region_name", ""))
	if str(row.get("id", "")) == _here():
		lines += "\nYou are here."
	elif _visited(str(row.get("id", ""))):
		lines += "\nLogged."
	else:
		lines += "\nNot yet logged."
	var hops: Array = Atlas.links(atlas, str(row.get("id", "")))
	if hops.is_empty():
		lines += "\nNo charted lane."
	else:
		lines += "\nLanes"
		for hop in hops:
			var hop_row: Dictionary = hop
			var other: Dictionary = by_id.get(str(hop_row.get("id", "")), {})
			var hop_name := str(other.get("name", hop_row.get("id", "")))
			var traffic := str(hop_row.get("traffic", ""))
			var rule := str(hop_row.get("color", ""))
			if traffic != "":
				lines += "\n%s · %s · %s" % [hop_name, rule, traffic]
			else:
				lines += "\n%s · %s" % [hop_name, rule]
	card_body.text = lines
