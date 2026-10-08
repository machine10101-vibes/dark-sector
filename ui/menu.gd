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
	new_button = ThemeKit.button("New ship")
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
	prompt_line = ThemeKit.label("Choose the ship. The others stay in someone else's yard.", 16, Color("cbb892"))
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
	for class_id in ["vesper", "anvil", "kestrel", "lumen", "casque", "alidade"]:
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
		prompt_line.text = "Choose the ship." if phone else "Choose the ship. The others stay in someone else's yard."
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
		var cards := keel_row.get_child_count()
		if two:
			keel_row.columns = 3
		elif stacked and cards > 3 and screen.x < 720.0:
			keel_row.columns = 2
		elif stacked:
			keel_row.columns = 1
		else:
			keel_row.columns = 3
		var grid_rows := int(ceil(float(maxi(cards, 1)) / float(maxi(keel_row.columns, 1))))
		var compact := grid_rows > 1 and not phone
		keel_row.add_theme_constant_override("h_separation", 6 if phone else 12)
		keel_row.add_theme_constant_override("v_separation", 6 if phone else 12)
		var show_detail := not phone
		var show_art := not phone and screen.y >= 640.0
		var card_w := 220.0
		if two:
			card_w = maxf(96.0, (select_size.x - 36.0) / 3.0)
		elif phone:
			var cols_w := float(maxi(keel_row.columns, 1))
			card_w = maxf(96.0, (screen.x - margin * 2.0 - 36.0) / cols_w)
		for card in keel_row.get_children():
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if phone or compact else Control.SIZE_EXPAND_FILL
			card.custom_minimum_size = Vector2(card_w, 0)
			var callsign := card.find_child("Callsign", true, false) as Label
			if callsign != null:
				callsign.add_theme_font_size_override("font_size", 16 if phone else (18 if compact else 22))
			var class_line := card.find_child("ClassLine", true, false) as Label
			if class_line != null:
				var role := str(class_line.get_meta("role", ""))
				var klass := str(class_line.get_meta("klass", class_line.text))
				var short_class := two or (phone and keel_row.columns > 1)
				class_line.text = role if short_class else "%s · %s" % [role, klass]
				class_line.add_theme_font_size_override("font_size", 11 if two else 13)
				class_line.clip_text = short_class
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
					if show_art:
						for art in part.find_children("*", "SubViewportContainer", true, false):
							art.custom_minimum_size = Vector2(220, 96) if compact else Vector2(280, 140)
				elif part_name == "Stats":
					part.visible = show_detail and not compact
				elif part_name == "StatsLine":
					# One line on a tall single column. Two columns stay on the callsign.
					part.visible = stacked and keel_row.columns == 1
				elif part_name == "Blurb":
					part.visible = show_detail and not compact
					var blurb := part as Label
					if blurb != null:
						blurb.max_lines_visible = 2
				elif part_name == "Rack":
					part.visible = show_detail and not compact
				else:
					part.visible = show_detail
		if phone and not two:
			var sample: Control = keel_row.get_child(0)
			var one := sample.get_combined_minimum_size().y
			var cols: int = maxi(keel_row.columns, 1)
			var row_count: int = int(ceil(float(keel_row.get_child_count()) / float(cols)))
			var gap := float(keel_row.get_theme_constant("v_separation"))
			var cards_h: float = one * float(row_count) + gap * float(maxi(row_count - 1, 0))
			var band: float = cards_h + 132.0
			band = minf(band, screen.y * 0.72)
			select_pos = Vector2(margin, screen.y - band - margin)
			select_size = Vector2(screen.x - margin * 2.0, band)
		elif not two:
			var stack_h := keel_row.get_combined_minimum_size().y
			var cap := 0.84 if grid_rows > 1 else 0.62
			var band := clampf(stack_h + 128.0, 280.0, screen.y * cap)
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
	# A log on the slate is the way back in. With an empty slate, New ship is the way in.
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
		fit = _yard_fit(klass)
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
	var previews := VBoxContainer.new()
	previews.name = "Previews"
	previews.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The card shows the hull the yard actually turns: mast, bay, or wing guns.
	previews.add_child(_preview(class_id, _signature_modules(class_id), _bolt_name(class_id)))
	box.add_child(previews)
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
	var preview := ShipPortrait.new()
	preview.class_id = class_id
	preview.modules = modules
	preview.custom_minimum_size = Vector2(220, 96)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
		"pathfinder":
			return "Pathfinder"
		"boarder":
			return "Boarder"
		"ranger":
			return "Ranger"
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


func _signature_modules(class_id: String) -> Array:
	match class_id:
		"vesper":
			return ["sensor_mast"]
		"anvil":
			return ["cargo_blister"]
		"kestrel":
			return ["gun_sponson"]
		"lumen":
			return ["sensor_mast", "laser_bank"]
		"casque":
			return ["missile_rack"]
		"alidade":
			return ["gun_sponson"]
		_:
			return []


func _yard_fit(class_id: String) -> String:
	match class_id:
		"vesper":
			return " Spine mast."
		"anvil":
			return " Wide bay."
		"kestrel":
			return " Wing guns."
		"lumen":
			return " Lamp crown."
		"casque":
			return " Ram prow."
		"alidade":
			return " Wing eye."
		_:
			return ""


func _bolt_name(class_id: String) -> String:
	var line := _yard_fit(class_id).strip_edges()
	if line.ends_with("."):
		line = line.substr(0, line.length() - 1)
	if line == "":
		return "Bolted"
	return line


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
	var tagline := "One ship. The dock is a place, not a menu."

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


## The same machined hull the yard and the flight view use, turned in a small glass.
class ShipPortrait extends SubViewportContainer:
	var class_id := "vesper"
	var modules: Array = []
	var _built := false
	var _stage: Node3D
	var _pivot: Node3D
	var _holder: Node3D
	var _extent := Vector3(40, 16, 16)
	var _phase := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Stretch keeps the plate's minimum on the card, not on the viewport pixels.
		stretch = true
		resized.connect(_frame_camera)
		_phase = float(class_id.hash() % 628) * 0.01
		var vp := SubViewport.new()
		vp.name = "PortraitView"
		vp.own_world_3d = true
		vp.world_3d = World3D.new()
		vp.transparent_bg = false
		vp.handle_input_locally = false
		vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		vp.size = Vector2i(220, 140)
		add_child(vp)
		var env := WorldEnvironment.new()
		var world := Environment.new()
		world.background_mode = Environment.BG_COLOR
		world.background_color = Color(0.012, 0.018, 0.026)
		world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.ambient_light_color = Color(0.55, 0.62, 0.72)
		world.ambient_light_energy = 0.42
		world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		world.glow_enabled = true
		world.glow_intensity = 0.42
		world.glow_strength = 0.7
		world.glow_bloom = 0.12
		world.glow_hdr_threshold = 0.86
		env.environment = world
		vp.add_child(env)
		var cam := Camera3D.new()
		cam.name = "PortraitEye"
		cam.current = true
		cam.fov = 28.0
		cam.near = 0.2
		cam.far = 4000.0
		vp.add_child(cam)
		_stage = preload("res://world/stage3d.gd").new()
		_stage.name = "PortraitStage"
		_stage.set("portrait_mode", true)
		vp.add_child(_stage)
		_stage.set_process(false)

	func _process(_delta: float) -> void:
		if not is_visible_in_tree():
			return
		if not _built:
			_build_hull()
			return
		if _pivot != null:
			# Hold a three-quarter view. A full spin hides a long hull down its own nose.
			_pivot.rotation.y = 0.15 + sin(Time.get_ticks_msec() * 0.00045 + _phase) * 0.12
		if _stage != null and _holder != null and _stage.has_method("_pulse_lamps"):
			_stage.call("_pulse_lamps", _holder)

	func _build_hull() -> void:
		if _built or _stage == null or Game.defs.is_empty() or Game.defs.ships.has(class_id) == false:
			return
		_built = true
		_pivot = Node3D.new()
		_pivot.name = "Turn"
		_stage.add_child(_pivot)
		_holder = Node3D.new()
		_holder.name = "Hull"
		_pivot.add_child(_holder)
		var shapes: Array = Silhouette.shapes_of(Game.defs, modules)
		var layers: Array = Silhouette.layers_of(Game.defs, modules)
		var sockets: Array = _stage.call("_weapon_sockets", modules)
		_stage.call("_fill_ship", _holder, class_id, shapes, layers, sockets)
		var hull: Dictionary = Game.defs.ships[class_id]
		var body := Color(str(hull.get("color", "#1f6f73")))
		var accent := Color(str(hull.get("accent", "#d7e6c8")))
		for child in _holder.get_children():
			var part := str(child.name)
			if not bool(_stage.call("_hull_part", part)):
				continue
			var tone := body
			if part == "Deck":
				tone = body.lightened(0.16)
			elif part.begins_with("Trim"):
				tone = accent
			_stage.call("_paint_hull", child, tone, accent)
		var bounds := _local_bounds(_holder)
		_extent = bounds.size
		_holder.position = -bounds.get_center()
		_frame_camera()

	func _frame_camera() -> void:
		var cam := get_node_or_null("PortraitView/PortraitEye") as Camera3D
		var vp := get_node_or_null("PortraitView") as SubViewport
		if cam == null or vp == null or not _built:
			return
		var frame := size
		if frame.x < 8.0 or frame.y < 8.0:
			frame = Vector2(vp.size)
		var aspect := maxf(frame.x / maxf(frame.y, 1.0), 0.4)
		var v_fov := deg_to_rad(cam.fov)
		var h_fov := 2.0 * atan(tan(v_fov * 0.5) * aspect)
		var half_w := maxf(_extent.x, _extent.z) * 0.55
		var half_h := maxf(_extent.y, 8.0) * 0.55
		var dist := maxf(half_w / maxf(tan(h_fov * 0.5), 0.05), half_h / maxf(tan(v_fov * 0.5), 0.05))
		dist *= 1.06
		var eye := Vector3(-0.42, 0.36, 0.95).normalized() * dist
		cam.position = eye
		cam.look_at(Vector3.ZERO, Vector3.UP)

	func _local_bounds(holder: Node3D) -> AABB:
		var acc := AABB()
		var any := false
		var into := holder.global_transform.affine_inverse()
		for node in holder.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh == null:
				continue
			var box: AABB = into * mesh_node.global_transform * mesh_node.get_aabb()
			if any:
				acc = acc.merge(box)
			else:
				acc = box
				any = true
		if not any:
			return AABB(Vector3(-20, -8, -8), Vector3(40, 16, 16))
		return acc
