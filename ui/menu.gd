extends CanvasLayer

signal start_game(class_id: String)
signal host_game(class_id: String)
signal join_game(class_id: String, address: String)
signal continue_game
signal quit_game

var root_box: VBoxContainer
var select_box: Control
var continue_button: Button
var address_line: LineEdit
var note: Label
var intent := "offline"
var keel_row: GridContainer
var keel_scroll: ScrollContainer


var backdrop: Control
var root: Control
var stage: SubViewportContainer
var yard_line: Label
var prompt_line: Label
var title_label: Label
var sky_label: Label
var tagline: Label
var slate_actions: GridContainer
var pinned_keel := ""
var slate_glass: Control
var slate_scroll: ScrollContainer
var select_glass: Control


func _ready() -> void:
	layer = 30
	stage = preload("res://ui/menu_stage.gd").new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	backdrop = Backdrop.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ThemeKit.build()
	add_child(root)
	slate_glass = Control.new()
	slate_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slate_glass.clip_contents = true
	root.add_child(slate_glass)
	var slate_panel := Panel.new()
	slate_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slate_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	slate_panel.add_theme_stylebox_override("panel", ThemeKit.veil())
	slate_glass.add_child(slate_panel)
	slate_scroll = ScrollContainer.new()
	slate_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slate_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	slate_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slate_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slate_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	slate_glass.add_child(slate_scroll)
	root_box = VBoxContainer.new()
	root_box.custom_minimum_size = Vector2(280, 0)
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 8)
	slate_scroll.add_child(root_box)
	title_label = ThemeKit.label("DARK SECTOR", 42, Color("e6d7bf"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	root_box.add_child(title_label)
	var sky := "HELION DOCK"
	if Game.defs.has("system"):
		sky = str(Game.defs.system.name).to_upper()
	sky_label = ThemeKit.label(sky, 16, Color("8a7344"))
	sky_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	root_box.add_child(sky_label)
	tagline = ThemeKit.label("One keel. The dock is a place, not a menu.", 14, Color("b7ab96"))
	tagline.autowrap_mode = TextServer.AUTOWRAP_OFF
	root_box.add_child(tagline)
	var new_game := ThemeKit.button("New keel")
	new_game.pressed.connect(func(): _show_select("offline"))
	var host := ThemeKit.button("Host the dock")
	host.pressed.connect(func(): _show_select("host"))
	var dedicated := ThemeKit.button("Dedicated host")
	dedicated.pressed.connect(func():
		if OS.has_feature("web"):
			back_to_slate(ListenLink.JOIN_LINE)
			return
		set_note("Same sim. Headless: godot --headless --path . --script res://scripts/headless_host.gd")
		_show_select("host")
	)
	address_line = LineEdit.new()
	address_line.placeholder_text = "IP or code, 127.0.0.1:24565"
	address_line.text = "127.0.0.1:24565"
	address_line.custom_minimum_size = Vector2(480, 32)
	var join := ThemeKit.button("Join a dock")
	join.pressed.connect(func(): _show_select("join"))
	continue_button = ThemeKit.button("Continue log")
	continue_button.pressed.connect(func(): continue_game.emit())
	var quit := ThemeKit.button("Leave")
	quit.pressed.connect(func(): quit_game.emit())
	slate_actions = GridContainer.new()
	slate_actions.columns = 1
	slate_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slate_actions.add_theme_constant_override("h_separation", 8)
	slate_actions.add_theme_constant_override("v_separation", 6)
	slate_actions.add_child(new_game)
	slate_actions.add_child(host)
	slate_actions.add_child(dedicated)
	slate_actions.add_child(address_line)
	slate_actions.add_child(join)
	slate_actions.add_child(continue_button)
	if not OS.has_feature("web"):
		slate_actions.add_child(quit)
	root_box.add_child(slate_actions)
	note = ThemeKit.label("", 13, Color("c4512c"))
	note.visible = false
	root_box.add_child(note)
	select_glass = Control.new()
	select_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_glass.clip_contents = true
	select_glass.visible = false
	root.add_child(select_glass)
	var select_panel := Panel.new()
	select_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	select_panel.add_theme_stylebox_override("panel", ThemeKit.veil())
	select_glass.add_child(select_panel)
	select_box = VBoxContainer.new()
	select_box.add_theme_constant_override("separation", 8)
	select_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	select_box.offset_left = 8
	select_box.offset_top = 8
	select_box.offset_right = -8
	select_box.offset_bottom = -8
	select_glass.add_child(select_box)
	prompt_line = ThemeKit.label("Choose the keel. The other two stay in someone else's yard.", 16, Color("cbb892"))
	select_box.add_child(prompt_line)
	yard_line = ThemeKit.label("Needle is in the yard.", 14, Color("9eecf5"))
	select_box.add_child(yard_line)
	keel_scroll = ScrollContainer.new()
	keel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	keel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	select_box.add_child(keel_scroll)
	keel_row = GridContainer.new()
	keel_row.columns = 3
	keel_row.add_theme_constant_override("h_separation", 12)
	keel_row.add_theme_constant_override("v_separation", 12)
	keel_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keel_scroll.add_child(keel_row)
	for class_id in ["vesper", "anvil", "kestrel"]:
		keel_row.add_child(_card(class_id))
	var back := ThemeKit.button("Back")
	back.pressed.connect(func(): _show_root())
	select_box.add_child(back)
	_show_root()
	get_viewport().size_changed.connect(_fit)
	call_deferred("_fit")


func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	if screen.x < 64.0:
		screen = Vector2(1280, 720)
	backdrop.position = Vector2.ZERO
	backdrop.size = screen
	if stage != null and stage.has_method("fit"):
		stage.fit(screen)
	root.position = Vector2.ZERO
	root.size = screen
	var phone := screen.x < 900.0 or screen.y < 560.0
	var landscape := screen.x > screen.y
	var margin := 8.0 if phone else 12.0
	var two := phone and landscape
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 26 if two else 42)
	if sky_label != null:
		sky_label.add_theme_font_size_override("font_size", 13 if two else 16)
	if tagline != null:
		tagline.visible = not two
	if root_box != null:
		root_box.add_theme_constant_override("separation", 4 if two else 8)
	if slate_actions != null:
		slate_actions.columns = 2 if two else 1
		slate_actions.add_theme_constant_override("v_separation", 4 if two else 6)
		for action in slate_actions.get_children():
			if action is Button:
				action.add_theme_font_size_override("font_size", 13 if two else 14)
	if prompt_line != null:
		prompt_line.text = "Choose the keel." if phone else "Choose the keel. The other two stay in someone else's yard."
		prompt_line.add_theme_font_size_override("font_size", 14 if phone else 16)
		prompt_line.autowrap_mode = TextServer.AUTOWRAP_OFF
		prompt_line.clip_text = phone
	if yard_line != null:
		yard_line.add_theme_font_size_override("font_size", 13 if phone else 14)
		yard_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	if select_box != null:
		select_box.add_theme_constant_override("separation", 4 if phone else 8)
		var inset := 6.0 if phone else 8.0
		select_box.offset_left = inset
		select_box.offset_top = inset
		select_box.offset_right = -inset
		select_box.offset_bottom = -inset
	var col_w := minf(440.0, screen.x - margin * 2.0)
	var col_h := screen.y - margin * 2.0
	var select_pos := Vector2(margin, screen.y * 0.56)
	var select_size := Vector2(screen.x - margin * 2.0, screen.y * 0.44 - margin)
	if two:
		col_w = minf(360.0, screen.x * 0.44)
		select_pos = Vector2(margin + col_w + 6.0, margin)
		select_size = Vector2(screen.x - select_pos.x - margin, screen.y - margin * 2.0)
	if keel_row != null:
		var stacked := phone and not two
		keel_row.columns = 1 if stacked else 3
		keel_row.add_theme_constant_override("h_separation", 6 if phone else 12)
		keel_row.add_theme_constant_override("v_separation", 6 if phone else 12)
		var show_detail := not phone
		var show_art := not phone and screen.y >= 640.0
		var card_w := 220.0
		if two:
			card_w = maxf(96.0, (select_size.x - 36.0) / 3.0)
		elif phone:
			card_w = maxf(120.0, screen.x - margin * 2.0 - 36.0)
		for card in keel_row.get_children():
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if phone else Control.SIZE_EXPAND_FILL
			card.custom_minimum_size = Vector2(card_w, 0)
			var box := card.get_child(0) as VBoxContainer
			if box != null and box.get_child_count() > 0 and box.get_child(0) is Label:
				(box.get_child(0) as Label).add_theme_font_size_override("font_size", 16 if phone else 22)
			if box != null and box.get_child_count() > 1 and box.get_child(1) is Label:
				var class_line := box.get_child(1) as Label
				class_line.add_theme_font_size_override("font_size", 11 if two else 13)
				class_line.clip_text = two
			for part in card.find_children("*", "Button", true, false):
				if part is Button:
					var take := part as Button
					take.add_theme_font_size_override("font_size", 12 if two else 14)
					take.clip_text = two
					if two:
						_tighten_button(take)
			for part_name in ["Previews", "Blurb", "Stats", "Rack"]:
				var part := card.find_child(part_name, true, false)
				if part == null:
					continue
				part.visible = show_art if part_name == "Previews" else show_detail
		if phone and not two:
			var sample: Control = keel_row.get_child(0)
			var one := sample.get_combined_minimum_size().y
			var rows := float(keel_row.get_child_count())
			var cards_h := one * rows + 8.0 * maxf(rows - 1.0, 0.0)
			var band := cards_h + 132.0
			band = minf(band, screen.y * 0.62)
			select_pos = Vector2(margin, screen.y - band - margin)
			select_size = Vector2(screen.x - margin * 2.0, band)
		elif not two:
			var desk: Control = keel_row.get_child(0)
			var desk_h := desk.get_combined_minimum_size().y
			var band := clampf(desk_h + 128.0, 280.0, screen.y * 0.62)
			select_pos = Vector2(margin, screen.y - band - margin)
			select_size = Vector2(screen.x - margin * 2.0, band)
	if keel_scroll != null:
		if two and keel_row != null and keel_row.get_child_count() > 0:
			keel_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			keel_scroll.custom_minimum_size = Vector2(0, keel_row.get_combined_minimum_size().y)
		else:
			keel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			keel_scroll.custom_minimum_size = Vector2(0, 0)
	if slate_glass != null:
		slate_glass.position = Vector2(margin, margin)
		slate_glass.size = Vector2(col_w, col_h)
	if root_box != null:
		root_box.custom_minimum_size = Vector2(maxf(120.0, col_w - 28.0), 0)
	if address_line != null:
		var addr_w := 0.0 if two else maxf(160.0, col_w - 36.0)
		address_line.custom_minimum_size = Vector2(addr_w, 44)
	if select_glass != null:
		select_glass.position = select_pos
		select_glass.size = select_size
	if select_box != null:
		var box_inset := 6.0 if phone else 8.0
		select_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		select_box.position = Vector2(box_inset, box_inset)
		select_box.size = Vector2(
			maxf(40.0, select_size.x - box_inset * 2.0),
			maxf(40.0, select_size.y - box_inset * 2.0)
		)
	if note != null:
		note.visible = note.text != ""
	backdrop.queue_redraw()


func show_root() -> void:
	_show_root()
	show()


func back_to_slate(text: String) -> void:
	print(text)
	_release_focus()
	_show_root()
	set_note(text)
	show()


func _release_focus() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.gui_release_focus()


func _show_root() -> void:
	_release_focus()
	if slate_glass != null:
		slate_glass.show()
	if select_glass != null:
		select_glass.hide()
	root_box.show()
	select_box.show()
	var has := Game.has_save()
	continue_button.disabled = not has
	continue_button.text = "Continue log" if has else "No log on the slate"


func _show_select(next: String) -> void:
	_release_focus()
	intent = next
	if slate_glass != null:
		slate_glass.hide()
	if select_glass != null:
		select_glass.show()
	root_box.hide()
	select_box.show()


func _process(_delta: float) -> void:
	if stage == null:
		return
	var on := visible and str(Game.mode) != "sector"
	if stage.has_method("set_live"):
		stage.set_live(on)
	if on == false:
		return
	var hero := select_box != null and select_box.visible
	var klass := "vesper"
	if hero:
		klass = _focused_keel()
	if stage.has_method("set_keel"):
		stage.set_keel(klass, hero)
	if yard_line != null and Game.defs.has("ships") and Game.defs.ships.has(klass):
		var hull: Dictionary = Game.defs.ships[klass]
		yard_line.text = "%s is in the yard." % str(hull.callsign)


func _focused_keel() -> String:
	if pinned_keel != "":
		return pinned_keel
	if keel_row == null:
		return "vesper"
	var screen := get_viewport().get_visible_rect().size
	if screen.x >= 860.0:
		return "vesper"
	var best := "vesper"
	var best_y := 1.0e12
	var top := select_box.global_position.y
	for card in keel_row.get_children():
		var id := str(card.get_meta("class_id", "vesper"))
		var y: float = card.global_position.y
		if y + card.size.y < top:
			continue
		if y < best_y:
			best_y = y
			best = id
	return best


func _pin_keel(class_id: String) -> void:
	pinned_keel = class_id


func _unpin_keel(class_id: String) -> void:
	if pinned_keel == class_id:
		pinned_keel = ""


func _tighten_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state)
		if style == null:
			continue
		var copy := style.duplicate() as StyleBoxFlat
		if copy == null:
			continue
		copy.content_margin_left = 6
		copy.content_margin_right = 6
		copy.content_margin_top = 4
		copy.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, copy)


func _choose(class_id: String) -> void:
	if intent == "host":
		host_game.emit(class_id)
	elif intent == "join":
		join_game.emit(class_id, address_line.text)
	else:
		start_game.emit(class_id)


func set_note(text: String) -> void:
	if note != null:
		note.text = text
		note.visible = text != ""


func _card(class_id: String) -> PanelContainer:
	var hull: Dictionary = Game.defs.ships[class_id]
	var card := PanelContainer.new()
	card.set_meta("class_id", class_id)
	card.mouse_entered.connect(_pin_keel.bind(class_id))
	card.mouse_exited.connect(_unpin_keel.bind(class_id))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var callsign := ThemeKit.label(str(hull.callsign), 22)
	callsign.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(callsign)
	var class_line := ThemeKit.label(str(hull.class_name), 13, Color("8a7344"))
	class_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(class_line)
	var previews := HBoxContainer.new()
	previews.name = "Previews"
	previews.add_theme_constant_override("separation", 4)
	previews.add_child(_preview(class_id, [], "As launched"))
	var yard: Array = hull.yard
	if not yard.is_empty():
		previews.add_child(_preview(class_id, [str(yard[0])], "Bolted"))
	box.add_child(previews)
	var blurb := ThemeKit.label(str(hull.select_blurb), 13, Color("d9d0c2"))
	blurb.name = "Blurb"
	blurb.custom_minimum_size = Vector2(220, 0)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(blurb)
	var stats := Fit.stats(Game.defs, {"class_id": class_id, "modules": []})
	var stats_line := ThemeKit.label(
		"Yaw %.0f°/s. Mass %.0f. Hold %d. Signature %s." % [stats.yaw_deg, stats.mass, stats.cargo_cap, stats.signature_word],
		13,
		Color("cbb892")
	)
	stats_line.name = "Stats"
	stats_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(stats_line)
	var craft_bits: Array = []
	for entry in hull.starting_craft:
		craft_bits.append("%d %s" % [int(entry.count), str(Game.defs.craft[entry.id].name)])
	var rack := ThemeKit.label("Rack: " + ", ".join(craft_bits), 13, Color("9fd0c8"))
	rack.name = "Rack"
	rack.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(rack)
	var choose := ThemeKit.button("Take the %s" % hull.callsign)
	choose.pressed.connect(_choose.bind(class_id))
	box.add_child(choose)
	return card


func _preview(class_id: String, modules: Array, caption: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	var preview := KeelPreview.new()
	preview.class_id = class_id
	preview.modules = modules
	preview.custom_minimum_size = Vector2(140, 110)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(preview)
	var caption_line := ThemeKit.label(caption, 12, Color("8a7344"))
	caption_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(caption_line)
	return col


class Backdrop extends Control:
	var stars: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 48291
		for _i in 160:
			stars.append(Vector2(rng.randf(), rng.randf()))

	func _draw() -> void:
		if size.x >= 860.0:
			draw_rect(Rect2(0, 0, minf(520.0, size.x * 0.42), size.y), Color(0.015, 0.02, 0.03, 0.28), true)
		elif size.y > size.x:
			draw_rect(Rect2(0, 0, size.x, minf(280.0, size.y * 0.34)), Color(0.015, 0.02, 0.03, 0.22), true)
		else:
			draw_rect(Rect2(0, 0, minf(340.0, size.x * 0.48), size.y), Color(0.015, 0.02, 0.03, 0.26), true)


class KeelPreview extends Control:
	var class_id := "vesper"
	var modules: Array = []

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		if Game.defs.is_empty() or size.x < 4.0:
			return
		var hull: Dictionary = Game.defs.ships[class_id]
		var shapes: Array = Silhouette.shapes_of(Game.defs, modules)
		var layers: Array = Silhouette.layers_of(Game.defs, modules)
		Silhouette.draw(
			self,
			size * 0.5 + Vector2(0, 8),
			-PI * 0.5,
			class_id,
			shapes,
			1.05,
			Color(str(hull.color)),
			Color(str(hull.accent)),
			1.0,
			false,
			layers
		)
