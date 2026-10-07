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
var title_plate: TitlePlate
var slate_actions: GridContainer
var pinned_keel := ""
var _fit_warmup := 0
var slate_glass: Control
var slate_scroll: ScrollContainer
var select_glass: Control
var new_button: Button
var dedicated_button: Button
var _shown_keel := ""


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
	var slate_veil := ThemeKit.veil()
	slate_veil.bg_color = Color(0.012, 0.02, 0.028, 0.58)
	slate_veil.border_color = Color(0.78, 0.7, 0.48, 0.42)
	slate_panel.add_theme_stylebox_override("panel", slate_veil)
	slate_glass.add_child(slate_panel)
	slate_scroll = ScrollContainer.new()
	slate_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slate_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	slate_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slate_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slate_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	slate_scroll.offset_left = 16
	slate_scroll.offset_top = 14
	slate_scroll.offset_right = -16
	slate_scroll.offset_bottom = -16
	slate_glass.add_child(slate_scroll)
	root_box = VBoxContainer.new()
	root_box.custom_minimum_size = Vector2(280, 0)
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 8)
	slate_scroll.add_child(root_box)
	var sky := "HELION DOCK"
	if Game.defs.has("system"):
		sky = str(Game.defs.system.name).to_upper()
	title_plate = TitlePlate.new()
	title_plate.sky = sky
	title_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_plate)
	new_button = ThemeKit.button("New keel")
	new_button.pressed.connect(func(): _show_select("offline"))
	var host := ThemeKit.button("Host the dock")
	host.pressed.connect(func(): _show_select("host"))
	dedicated_button = ThemeKit.button("Dedicated host")
	dedicated_button.add_theme_color_override("font_color", Color("8aa0a6"))
	dedicated_button.pressed.connect(func():
		if OS.has_feature("web"):
			back_to_slate(ListenLink.JOIN_LINE)
			return
		set_note("Same sim. Headless: godot --headless --path . --script res://scripts/headless_host.gd")
		_show_select("host")
	)
	address_line = LineEdit.new()
	address_line.placeholder_text = "Dock address, 127.0.0.1:24565"
	address_line.text = "127.0.0.1:24565"
	address_line.custom_minimum_size = Vector2(480, 44)
	_style_field(address_line)
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
	root_box.add_child(new_button)
	root_box.add_child(continue_button)
	slate_actions.add_child(host)
	slate_actions.add_child(join)
	slate_actions.add_child(address_line)
	slate_actions.add_child(dedicated_button)
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
	prompt_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_box.add_child(prompt_line)
	yard_line = ThemeKit.label("Needle is in the yard.", 14, Color("9eecf5"))
	yard_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	var phone := screen.x < 900.0 or screen.y < 560.0 or screen.y > screen.x
	var landscape := screen.x > screen.y
	var portrait := screen.y > screen.x
	var margin := 8.0 if phone else 12.0
	var two := phone and landscape
	var tight := portrait and screen.x < 560.0
	if dedicated_button != null:
		# A headless-host note does not earn a seat on a short landscape slate.
		dedicated_button.visible = not two
	if root_box != null:
		root_box.add_theme_constant_override("separation", 4 if two or tight else 8)
	if slate_actions != null:
		# Two columns keep the quieter actions in a short stack. A narrow portrait stays one column.
		slate_actions.columns = 2 if two or screen.x >= 480.0 else 1
		slate_actions.add_theme_constant_override("v_separation", 4 if two or tight else 6)
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
			var callsign := card.find_child("Callsign", true, false) as Label
			if callsign != null:
				callsign.add_theme_font_size_override("font_size", 16 if phone else 22)
			var class_line := card.find_child("ClassLine", true, false) as Label
			if class_line != null:
				var role := str(class_line.get_meta("role", ""))
				var klass := str(class_line.get_meta("klass", class_line.text))
				class_line.text = role if two else "%s · %s" % [role, klass]
				class_line.add_theme_font_size_override("font_size", 11 if two else 13)
				class_line.clip_text = two
			for part in card.find_children("*", "Button", true, false):
				if part is Button:
					var take := part as Button
					take.add_theme_font_size_override("font_size", 12 if two else 14)
					take.clip_text = two
					if two:
						_tighten_button(take)
			for part_name in ["Previews", "Blurb", "Stats", "StatsLine", "Rack"]:
				var part := card.find_child(part_name, true, false)
				if part == null:
					continue
				if part_name == "Previews":
					part.visible = show_art
				elif part_name == "Stats":
					part.visible = show_detail
				elif part_name == "StatsLine":
					# One line on a tall phone. The two-line columns belong on a desk.
					part.visible = stacked
				else:
					part.visible = show_detail
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
	if address_line != null:
		var addr_w := 0.0
		if not two and slate_actions != null and slate_actions.columns == 1:
			addr_w = maxf(160.0, col_w - 68.0)
		address_line.custom_minimum_size = Vector2(addr_w, 40 if two else 44)
	if note != null:
		note.visible = note.text != ""
	if slate_glass != null:
		var slate_h := _title_block_height()
		if root_box != null:
			var measured := root_box.get_combined_minimum_size().y + 36.0
			if measured > 80.0:
				slate_h = maxf(slate_h, measured)
		var budget := screen.y * (0.56 if portrait else 0.74)
		slate_h = minf(slate_h, budget)
		slate_h = minf(slate_h, screen.y - margin * 2.0)
		if slate_scroll != null:
			slate_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		# Phone landscape keeps the stack on the left, beside the keel.
		# Everywhere else the stack sits on the bottom center, under the open sky.
		if two:
			var slate_y := margin
			if slate_h < screen.y - margin * 2.0 - 8.0:
				slate_y = margin + (screen.y - margin * 2.0 - slate_h) * 0.5
			slate_glass.position = Vector2(margin, slate_y)
			slate_glass.size = Vector2(col_w, slate_h)
		else:
			var stack_w := minf(460.0, screen.x - margin * 2.0)
			slate_glass.position = Vector2((screen.x - stack_w) * 0.5, screen.y - slate_h - margin)
			slate_glass.size = Vector2(stack_w, slate_h)
		if root_box != null:
			root_box.custom_minimum_size = Vector2(maxf(120.0, slate_glass.size.x - 48.0), 0)
	if title_plate != null and slate_glass != null:
		var plate_h := 112.0
		if two or tight:
			plate_h = 68.0
		var plate_w := minf(760.0, screen.x - margin * 2.0)
		var plate_x := (screen.x - plate_w) * 0.5
		var plate_y := margin + (20.0 if not two else 4.0)
		if two:
			plate_x = slate_glass.position.x + slate_glass.size.x + 8.0
			plate_w = maxf(96.0, screen.x - plate_x - margin)
			plate_y = margin
		var overlaps := plate_x < slate_glass.position.x + slate_glass.size.x and plate_x + plate_w > slate_glass.position.x
		if overlaps:
			var room := slate_glass.position.y - plate_y - 10.0
			if room < plate_h:
				plate_h = maxf(52.0, room)
		title_plate.position = Vector2(plate_x, plate_y)
		title_plate.size = Vector2(maxf(96.0, plate_w), maxf(48.0, plate_h))
		title_plate.queue_redraw()
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
	if title_plate != null:
		title_plate.show()
	if select_glass != null:
		select_glass.hide()
	root_box.show()
	select_box.show()
	var has := Game.has_save()
	continue_button.disabled = not has
	continue_button.text = "Continue log" if has else "No log on the slate"
	# A log on the slate is the way back in. With an empty slate, New keel is the way in.
	_paint_depart(new_button, not has)
	_paint_depart(continue_button, has)
	_shown_keel = ""


func _show_select(next: String) -> void:
	_release_focus()
	intent = next
	if slate_glass != null:
		slate_glass.hide()
	if title_plate != null:
		title_plate.hide()
	if select_glass != null:
		select_glass.show()
	root_box.hide()
	select_box.show()


func _title_block_height() -> float:
	var h := 36.0
	if root_box == null:
		return h
	var gap := float(root_box.get_theme_constant("separation"))
	var seen := 0
	for child in root_box.get_children():
		var control := child as Control
		if control == null or control.visible == false:
			continue
		var line := control.get_combined_minimum_size().y
		if child == slate_actions:
			line = _action_block_height()
		elif line < 12.0:
			line = 22.0
		h += line
		seen += 1
	if seen > 1:
		h += gap * float(seen - 1)
	return h


func _action_block_height() -> float:
	if slate_actions == null:
		return 44.0
	var count := 0
	var row_h := 44.0
	for child in slate_actions.get_children():
		var control := child as Control
		if control == null or control.visible == false:
			continue
		count += 1
		row_h = maxf(row_h, maxf(control.get_combined_minimum_size().y, 44.0))
	var cols := maxi(slate_actions.columns, 1)
	var rows := int(ceil(float(count) / float(cols)))
	var gap := float(slate_actions.get_theme_constant("v_separation"))
	return float(rows) * row_h + gap * float(maxi(rows - 1, 0))


func _process(_delta: float) -> void:
	if stage == null:
		return
	var on := visible and str(Game.mode) != "sector"
	if on and _fit_warmup < 10:
		_fit_warmup += 1
		_fit()
	if stage.has_method("set_live"):
		stage.set_live(on)
	if on == false:
		return
	var hero := select_glass != null and select_glass.visible
	var klass := "vesper"
	if hero:
		klass = _focused_keel()
	if stage.has_method("set_keel"):
		stage.set_keel(klass, hero)
	if yard_line != null and Game.defs.has("ships") and Game.defs.ships.has(klass):
		var hull: Dictionary = Game.defs.ships[klass]
		var fit := ""
		if klass == "vesper":
			fit = " Spine mast."
		elif klass == "anvil":
			fit = " Wide bay."
		elif klass == "kestrel":
			fit = " Wing guns."
		yard_line.text = "%s is in the yard.%s" % [str(hull.callsign), fit]
	if hero:
		_mark_focus(klass)
	else:
		_shown_keel = ""


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
		_fit()


func _card(class_id: String) -> PanelContainer:
	var hull: Dictionary = Game.defs.ships[class_id]
	var card := PanelContainer.new()
	card.set_meta("class_id", class_id)
	card.mouse_entered.connect(_pin_keel.bind(class_id))
	card.mouse_exited.connect(_unpin_keel.bind(class_id))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style(class_id, false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	var stripe := ColorRect.new()
	stripe.name = "Stripe"
	stripe.color = Color(str(hull.accent))
	stripe.custom_minimum_size = Vector2(0, 3)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stripe)
	var callsign := ThemeKit.label(str(hull.callsign), 22)
	callsign.name = "Callsign"
	callsign.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(callsign)
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = Color(str(hull.accent))
	rule.color.a = 0.7
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	var role := _role_word(str(hull.role))
	var class_line := ThemeKit.label("%s · %s" % [role, str(hull.class_name)], 13, Color("8a7344"))
	class_line.name = "ClassLine"
	class_line.set_meta("role", role)
	class_line.set_meta("klass", str(hull.class_name))
	class_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(class_line)
	var previews := HBoxContainer.new()
	previews.name = "Previews"
	previews.add_theme_constant_override("separation", 8)
	previews.add_child(_preview(class_id, [], "As launched"))
	var yard: Array = hull.yard
	if not yard.is_empty():
		previews.add_child(_preview(class_id, [str(yard[0])], _bolt_name(class_id)))
	box.add_child(previews)
	_share_plan_frame(previews)
	var blurb_text := str(hull.select_blurb)
	var stop := blurb_text.find(". ")
	if stop > 0:
		blurb_text = blurb_text.substr(0, stop + 1)
	var blurb := ThemeKit.label(blurb_text, 13, Color("d9d0c2"))
	blurb.name = "Blurb"
	blurb.custom_minimum_size = Vector2(180, 0)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.max_lines_visible = 2
	box.add_child(blurb)
	var stats := Fit.stats(Game.defs, {"class_id": class_id, "modules": []})
	var gun := int(hull.gun.damage)
	var sig := str(stats.signature_word).capitalize()
	box.add_child(_stat_row(float(stats.yaw_deg), int(stats.cargo_cap), gun, sig))
	var stats_line := ThemeKit.label(
		"%.0f°/s turn  ·  Hold %d  ·  Gun %d  ·  %s" % [stats.yaw_deg, stats.cargo_cap, gun, sig],
		13,
		Color("cbb892")
	)
	stats_line.name = "StatsLine"
	stats_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(stats_line)
	var craft_bits: Array = []
	for entry in hull.starting_craft:
		var count := int(entry.count)
		var word := _craft_word(str(entry.id))
		if count != 1:
			word += "s"
		craft_bits.append("%d %s" % [count, word])
	var rack := ThemeKit.label("Rack: " + " · ".join(craft_bits), 13, Color("9fd0c8"))
	rack.name = "Rack"
	rack.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(rack)
	var choose := ThemeKit.button("Take the %s" % hull.callsign)
	choose.name = "Take"
	choose.pressed.connect(_choose.bind(class_id))
	box.add_child(choose)
	return card


func _preview(class_id: String, modules: Array, caption: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview := KeelPlan.new()
	preview.class_id = class_id
	preview.modules = modules
	preview.custom_minimum_size = Vector2(120, 56)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(preview)
	var caption_line := ThemeKit.label(caption, 12, Color("8a7344"))
	caption_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(caption_line)
	return col


func _role_word(role: String) -> String:
	match role:
		"scout":
			return "Scout"
		"hauler":
			return "Hauler"
		"corvette":
			return "Corvette"
		_:
			return role.capitalize()


func _card_style(class_id: String, on: bool) -> StyleBoxFlat:
	var box := ThemeKit.glass(on)
	var accent := Color("8a7344")
	if Game.defs.has("ships") and Game.defs.ships.has(class_id):
		accent = Color(str(Game.defs.ships[class_id].accent))
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	if on:
		# A dark glass with a hint of the hull color. A translucent accent
		# let the ice show through the words.
		var tint := Color(0.025, 0.04, 0.05, 1.0).lerp(accent, 0.08)
		tint.a = 0.94
		box.bg_color = tint
		box.border_color = accent
		box.set_border_width_all(2)
		box.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
		box.shadow_size = 12
	else:
		box.border_color = Color(0.4, 0.55, 0.6, 0.28)
		box.bg_color = Color(0.018, 0.03, 0.04, 0.9)
		box.set_border_width_all(1)
		box.shadow_size = 6
	return box


func _mark_focus(klass: String) -> void:
	if keel_row == null or klass == _shown_keel:
		return
	_shown_keel = klass
	var screen := get_viewport().get_visible_rect().size
	var two := (screen.x < 900.0 or screen.y < 560.0 or screen.y > screen.x) and screen.x > screen.y
	for card in keel_row.get_children():
		var id := str(card.get_meta("class_id", ""))
		var on := id == klass
		var panel := card as PanelContainer
		if panel != null:
			panel.add_theme_stylebox_override("panel", _card_style(id, on))
		var stripe := card.find_child("Stripe", true, false) as ColorRect
		var accent := Color("8a7344")
		if Game.defs.ships.has(id):
			accent = Color(str(Game.defs.ships[id].accent))
		if stripe != null:
			stripe.color = accent
			stripe.color.a = 1.0 if on else 0.45
			stripe.custom_minimum_size = Vector2(0, 4 if on else 3)
		var callsign := card.find_child("Callsign", true, false) as Label
		if callsign != null:
			callsign.add_theme_color_override("font_color", Color("f7f1e4") if on else Color("e7f3f6"))
		var take := card.find_child("Take", true, false) as Button
		if take != null:
			ThemeKit.paint(take, on)
			if two:
				take.add_theme_font_size_override("font_size", 12)
				_tighten_button(take)


func _paint_depart(button: Button, primary: bool) -> void:
	if not primary:
		ThemeKit.paint(button, false)
		return
	# Gold for the way in. The dock actions stay on the cyan glass.
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.11, 0.05, 0.94)
	normal.border_color = Color(0.86, 0.72, 0.4, 0.95)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.17, 0.08, 0.96)
	hover.border_color = Color(0.95, 0.84, 0.55, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.28, 0.21, 0.1, 0.98)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", ThemeKit._quiet_box())
	button.add_theme_color_override("font_color", Color("f6edd8"))
	button.add_theme_color_override("font_hover_color", Color("fff8ea"))
	button.add_theme_font_size_override("font_size", 16)


func _bolt_name(class_id: String) -> String:
	if class_id == "vesper":
		return "Spine mast"
	if class_id == "anvil":
		return "Wide bay"
	if class_id == "kestrel":
		return "Wing guns"
	return "Bolted"


func _craft_word(craft_id: String) -> String:
	match craft_id:
		"survey_probe":
			return "probe"
		"harvest_drone":
			return "drone"
		"salvage_tender":
			return "tender"
		"livestock_lighter":
			return "lighter"
		"fighter":
			return "fighter"
		_:
			return craft_id


func _stat_row(turn: float, hold: int, gun: int, signature: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Stats"
	row.add_theme_constant_override("separation", 6)
	row.add_child(_stat_bit("%.0f°/s" % turn))
	row.add_child(_stat_bit("Hold %d" % hold))
	row.add_child(_stat_bit("Gun %d" % gun))
	row.add_child(_stat_bit(signature))
	return row


func _stat_bit(value: String) -> Label:
	var bit := ThemeKit.label(value, 13, Color("e8f2f4"))
	bit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bit.autowrap_mode = TextServer.AUTOWRAP_OFF
	return bit


func _share_plan_frame(previews: HBoxContainer) -> void:
	var plans: Array = []
	var union := Rect2()
	var started := false
	for col in previews.get_children():
		if col.get_child_count() < 1:
			continue
		var plan := col.get_child(0) as KeelPlan
		if plan == null:
			continue
		plans.append(plan)
		var bounds := plan.measured_bounds()
		if bounds.size == Vector2.ZERO:
			continue
		if started:
			union = union.merge(bounds)
		else:
			union = bounds
			started = true
	if started == false:
		return
	union = union.grow(3.0)
	for plan in plans:
		(plan as KeelPlan).frame = union


func _style_field(line: LineEdit) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.012, 0.025, 0.034, 0.94)
	box.border_color = Color(0.45, 0.68, 0.76, 0.5)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	var focus := box.duplicate() as StyleBoxFlat
	focus.border_color = Color(0.62, 0.92, 0.96, 0.92)
	line.add_theme_stylebox_override("normal", box)
	line.add_theme_stylebox_override("focus", focus)
	line.add_theme_color_override("font_color", Color("d7eef2"))
	line.add_theme_color_override("font_placeholder_color", Color("7a8e96"))
	line.add_theme_color_override("caret_color", Color("9eecf5"))
	line.add_theme_font_size_override("font_size", 14)


class Backdrop extends Control:
	var stars: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 48291
		for _i in 160:
			stars.append(Vector2(rng.randf(), rng.randf()))

	func _draw() -> void:
		for i in stars.size():
			var star: Vector2 = stars[i]
			var at := Vector2(star.x * size.x, star.y * size.y)
			var bright := 0.16 + float(i % 5) * 0.05
			var rad := 0.6 if i % 7 != 0 else 1.15
			draw_circle(at, rad, Color(0.78, 0.84, 0.9, bright))
		# Darken the edges and the floor under the action stack. The center-right stays clear for the keel.
		draw_rect(Rect2(0, 0, size.x, size.y * 0.16), Color(0.01, 0.014, 0.02, 0.28), true)
		draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), Color(0.012, 0.016, 0.022, 0.38), true)
		draw_rect(Rect2(0, 0, size.x * 0.06, size.y), Color(0.01, 0.014, 0.02, 0.22), true)


## Title in the open sky: a small dock line over the large name.
class TitlePlate extends Control:
	var sky := "HELION DOCK"
	var title := "DARK SECTOR"
	var tagline := "One keel. The dock is a place, not a menu."

	func _draw() -> void:
		if size.x < 8.0 or size.y < 8.0:
			return
		var font := ThemeDB.fallback_font
		if font == null:
			return
		var compact := size.y < 88.0 or size.x < 460.0
		var sky_size := 12 if compact else 15
		var title_size := 22 if compact else 46
		if size.x < 280.0:
			title_size = 18
		elif size.y < 64.0:
			title_size = 20
		var sky_gap := 2.4 if compact else 4.6
		var title_gap := 2.2 if compact else 7.0
		sky_gap = _fit_gap(font, sky, sky_size, sky_gap, size.x - 12.0)
		title_gap = _fit_gap(font, title, title_size, title_gap, size.x - 12.0)
		var sky_w := _tracked_width(font, sky, sky_size, sky_gap)
		var title_w := _tracked_width(font, title, title_size, title_gap)
		var y := 16.0 if not compact else 12.0
		_draw_tracked(font, sky, Vector2((size.x - sky_w) * 0.5, y), sky_size, sky_gap, Color("c4a46a"))
		y += 8.0
		_hairline((size.x - minf(168.0, sky_w)) * 0.5, y, minf(168.0, sky_w))
		y += 8.0 + float(title_size)
		_draw_tracked(font, title, Vector2((size.x - title_w) * 0.5, y), title_size, title_gap, Color("f4ecdf"))
		y += 10.0
		var rule_w := minf(size.x * 0.42, maxf(title_w * 0.46, 96.0))
		_hairline((size.x - rule_w) * 0.5, y, rule_w)
		if not compact and size.y > y + 22.0:
			var tag_size := 13
			var tag_w := font.get_string_size(tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x
			if tag_w > size.x - 16.0:
				return
			draw_string(font, Vector2((size.x - tag_w) * 0.5, y + 20.0), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, Color("b7ab96"))

	func _hairline(x: float, y: float, width: float) -> void:
		draw_line(Vector2(x, y), Vector2(x + width, y), Color(0.78, 0.66, 0.4, 0.85), 1.0)
		draw_line(Vector2(x + width * 0.38, y), Vector2(x + width * 0.62, y), Color(0.95, 0.88, 0.7, 0.95), 1.0)

	func _fit_gap(font: Font, text: String, font_size: int, gap: float, limit: float) -> float:
		var bare := _tracked_width(font, text, font_size, 0.0)
		if bare >= limit or text.length() < 2:
			return 0.0
		var room := (limit - bare) / float(text.length() - 1)
		return minf(gap, room)

	func _tracked_width(font: Font, text: String, font_size: int, gap: float) -> float:
		var width := 0.0
		for i in text.length():
			width += font.get_string_size(text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if i < text.length() - 1:
				width += gap
		return width

	func _draw_tracked(font: Font, text: String, at: Vector2, font_size: int, gap: float, color: Color) -> void:
		var x := at.x
		for i in text.length():
			var ch := text.substr(i, 1)
			draw_string(font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + gap


## Plan view of a keel, the same silhouette the yard bolts onto.
## A 140px spinning mesh read as texture. The plan reads as a ship.
class KeelPlan extends Control:
	var class_id := "vesper"
	var modules: Array = []
	# Shared with the other plan on the card, so the bolt is the only change.
	var frame := Rect2()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func measured_bounds() -> Rect2:
		if Game.defs.is_empty() or Game.defs.ships.has(class_id) == false:
			return Rect2()
		var shapes: Array = Silhouette.shapes_of(Game.defs, modules)
		var layers: Array = Silhouette.layers_of(Game.defs, modules)
		return _bounds(Silhouette.parts(class_id, shapes, layers))

	func _draw() -> void:
		if size.x < 8.0 or size.y < 8.0 or Game.defs.is_empty():
			return
		var hull: Dictionary = Game.defs.ships.get(class_id, {})
		if hull.is_empty():
			return
		var accent := Color(str(hull.get("accent", "#d7e6c8")))
		var body := Color(str(hull.get("color", "#1f6f73")))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.02, 0.028, 0.85))
		var tick := 7.0
		var edge := Color(accent.r, accent.g, accent.b, 0.9)
		draw_line(Vector2(1, 1), Vector2(tick, 1), edge, 1.2)
		draw_line(Vector2(1, 1), Vector2(1, tick), edge, 1.2)
		draw_line(Vector2(size.x - 1, 1), Vector2(size.x - tick, 1), edge, 1.2)
		draw_line(Vector2(size.x - 1, 1), Vector2(size.x - 1, tick), edge, 1.2)
		draw_line(Vector2(1, size.y - 1), Vector2(tick, size.y - 1), edge, 1.2)
		draw_line(Vector2(1, size.y - 1), Vector2(1, size.y - tick), edge, 1.2)
		draw_line(Vector2(size.x - 1, size.y - 1), Vector2(size.x - tick, size.y - 1), edge, 1.2)
		draw_line(Vector2(size.x - 1, size.y - 1), Vector2(size.x - 1, size.y - tick), edge, 1.2)
		var shapes: Array = Silhouette.shapes_of(Game.defs, modules)
		var layers: Array = Silhouette.layers_of(Game.defs, modules)
		var geom := Silhouette.parts(class_id, shapes, layers)
		var bounds := frame if frame.size.x > 1.0 else _bounds(geom)
		if bounds.size.x < 1.0 or bounds.size.y < 1.0:
			return
		# A wide hull (the Barn) stood on end so the beam uses the card width.
		# A long hull stays nose-right, so the mast reads as extra length.
		var margin := 6.0
		var rot := 0.0
		var span_x := bounds.size.x
		var span_y := bounds.size.y
		if bounds.size.y > bounds.size.x:
			rot = -PI * 0.5
			span_x = bounds.size.y
			span_y = bounds.size.x
		var fit_x := (size.x - margin * 2.0) / span_x
		var fit_y := (size.y - margin * 2.0) / span_y
		var plan_scale := minf(fit_x, fit_y)
		var mid := bounds.position + bounds.size * 0.5
		var origin := size * 0.5 - mid.rotated(rot) * plan_scale
		Silhouette.draw(self, origin, rot, class_id, shapes, plan_scale, body, accent, 1.0, false, layers)

	func _bounds(geom: Dictionary) -> Rect2:
		var lo := Vector2(1.0e9, 1.0e9)
		var hi := Vector2(-1.0e9, -1.0e9)
		var lists: Array = [geom.hull]
		lists.append_array(geom.extras)
		for poly in lists:
			for point in poly:
				lo.x = minf(lo.x, point.x)
				lo.y = minf(lo.y, point.y)
				hi.x = maxf(hi.x, point.x)
				hi.y = maxf(hi.y, point.y)
		for circle in geom.circles:
			var center := Vector2(float(circle.x), float(circle.y))
			var rad := float(circle.r)
			lo.x = minf(lo.x, center.x - rad)
			lo.y = minf(lo.y, center.y - rad)
			hi.x = maxf(hi.x, center.x + rad)
			hi.y = maxf(hi.y, center.y + rad)
		if hi.x < lo.x:
			return Rect2()
		return Rect2(lo, hi - lo)
