extends CanvasLayer

var root: Control
var helm_name: Label
var helm_flight: Label
var helm_zone: Label
var haul_cue: Label
var helm_cargo: Label
var helm_craft: Label
var banner: Label
var log_label: Label
var panel: PanelContainer
var panel_scroll: ScrollContainer
var panel_title: Label
var panel_body: Label
var hangar_box: VBoxContainer
var bay_box: VBoxContainer
var dossier_box: VBoxContainer
var pause_box: PanelContainer
var dead_box: PanelContainer
var panel_kind := ""
var hangar_rows: Dictionary = {}
var hangar_node := "aegis_prime"
var hangar_target: Label
var hangar_sig := ""
var bay_preview: Control
var bay_detail: Label
var bay_buttons: Dictionary = {}
var ship_list: VBoxContainer
var ship_list_scroll: ScrollContainer
var ship_query := ""
var ship_family := ""
var ship_filters: Dictionary = {}
var dossier_timer := 0.0
var hold_button: Button
var chat_line: LineEdit
var chat_open := false
var helm_box: VBoxContainer
var status_card: Control
var stats_grid: GridContainer
var stat_hull: Label
var stat_speed: Label
var stat_heat: Label
var stat_purse: Label
var hint_label: Label
var cast_button: Button
var board_button: Button
var dock_button: Button
var quest_button: Button
var probe_button: Button
var board_box: VBoxContainer
var market_box: VBoxContainer
var board_sig := ""
var market_sig := ""
var tag_edit: LineEdit
var market_purse: Label
var market_hold: Label
var show_tag := false
var action_scroll: ScrollContainer
var action_row: HBoxContainer
var primary_bar: PanelContainer
var primary_row: HBoxContainer
var log_card: PanelContainer
var pad: Control
var minimap: Control
var space_map: Control
var stick_button: Button
var touch_on := false
var touch_chosen := false
var compact := false
var panel_inner: VBoxContainer
var overlay: Control


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ThemeKit.build()
	add_child(root)
	touch_on = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	overlay = preload("res://ui/helm_overlay.gd").new()
	overlay.name = "HelmOverlay"
	overlay.hud = self
	root.add_child(overlay)
	_build_helm()
	_build_panel()
	_build_actions()
	_build_pause()
	_build_dead()
	pad = preload("res://ui/flight_pad.gd").new()
	pad.visible = touch_on
	root.add_child(pad)
	minimap = preload("res://ui/minimap.gd").new()
	root.add_child(minimap)
	space_map = preload("res://ui/space_map.gd").new()
	root.add_child(space_map)
	hint_label = ThemeKit.label("", 12, Color("8aa8b0"))
	hint_label.visible = false
	root.add_child(hint_label)
	cast_button = ThemeKit.button("Cast off", true)
	cast_button.visible = false
	cast_button.custom_minimum_size = Vector2(124, 48)
	cast_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cast_button.pressed.connect(func() -> void:
		if Game.sim == null:
			return
		Game.request_cast_off()
	)
	root.add_child(cast_button)
	dock_button = ThemeKit.button("Dock", true)
	dock_button.visible = false
	dock_button.custom_minimum_size = Vector2(124, 48)
	dock_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dock_button.pressed.connect(func() -> void:
		if Game.sim == null:
			return
		Game.request_dock()
	)
	root.add_child(dock_button)
	board_button = ThemeKit.button("Board", true)
	board_button.visible = false
	board_button.custom_minimum_size = Vector2(112, 48)
	board_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_button.pressed.connect(func() -> void:
		_toggle("board")
	)
	root.add_child(board_button)
	_mount_primary()
	stick_button = ThemeKit.button("Stick")
	stick_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stick_button.custom_minimum_size = Vector2(88, 44)
	stick_button.pressed.connect(_toggle_stick)
	root.add_child(stick_button)
	chat_line = LineEdit.new()
	chat_line.placeholder_text = "Local channel"
	chat_line.visible = false
	chat_line.position = Vector2(16, 656)
	chat_line.size = Vector2(520, 28)
	chat_line.text_submitted.connect(_submit_chat)
	root.add_child(chat_line)
	hold_button = ThemeKit.button("Hold")
	hold_button.pressed.connect(_toggle_pause)
	root.add_child(hold_button)
	get_viewport().size_changed.connect(_fit)
	call_deferred("_fit")


func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	if screen.x < 64.0:
		screen = Vector2(1280, 720)
	compact = screen.x < 900.0 or screen.y < 560.0
	if not touch_chosen and (compact or DisplayServer.is_touchscreen_available()):
		touch_on = true
	root.position = Vector2.ZERO
	root.size = screen
	if stats_grid != null:
		stats_grid.columns = 2 if compact else 4
	if panel_inner != null:
		var inner_w := minf(420.0, screen.x - 48.0)
		if screen.y < 520.0 and screen.x > screen.y:
			inner_w = 0.0
		panel_inner.custom_minimum_size = Vector2(inner_w, 0)
	var card_w := minf(440.0, screen.x - 24.0)
	var card_h := minf(360.0, screen.y - 24.0)
	if pause_box != null:
		pause_box.position = Vector2((screen.x - card_w) * 0.5, maxf(8.0, (screen.y - card_h) * 0.5))
		pause_box.size = Vector2(card_w, card_h)
	if dead_box != null:
		dead_box.position = Vector2((screen.x - card_w) * 0.5, maxf(8.0, (screen.y - card_h) * 0.5))
		dead_box.size = Vector2(card_w, card_h)
	if hold_button != null:
		hold_button.position = Vector2(screen.x - 100.0, 12)
		hold_button.size = Vector2(84, 40)
	if stick_button != null:
		if compact:
			stick_button.position = Vector2(screen.x - 100.0, 58)
		else:
			stick_button.position = Vector2(screen.x - 192.0, 12)
		stick_button.size = Vector2(84, 40)
		stick_button.text = "Keys" if touch_on else "Stick"
	if cast_button != null:
		var moored := false
		if Game.sim != null and Game.mode == "sector":
			moored = bool(Game.sim.player.get("moored", false))
		cast_button.visible = moored
	_place_board_button(compact)
	_layout_chrome(screen)
	if pad != null:
		pad.visible = touch_on
		if touch_on and pad.has_method("place"):
			pad.place(screen, 8.0, screen.y < 520.0)
		elif not touch_on:
			Game.clear_flight()


func _layout_chrome(screen: Vector2) -> void:
	var margin := 10.0
	var short := screen.y < 520.0
	compact = screen.x < 900.0 or screen.y < 560.0
	if stats_grid != null:
		stats_grid.columns = 2 if compact else 4
	if helm_name != null:
		helm_name.visible = not short
	if helm_flight != null:
		helm_flight.visible = screen.y >= 430.0 or show_tag
		helm_flight.clip_text = true
		if show_tag and screen.y < 430.0:
			helm_flight.add_theme_font_size_override("font_size", 14)
		else:
			helm_flight.add_theme_font_size_override("font_size", 18)
	if helm_zone != null:
		helm_zone.visible = not short
	if helm_cargo != null:
		helm_cargo.visible = not compact
	if helm_craft != null:
		helm_craft.visible = not compact
	if haul_cue != null:
		haul_cue.add_theme_font_size_override("font_size", 15 if short else 20)
	var corner := 84.0
	if hold_button != null:
		hold_button.position = Vector2(screen.x - corner - 8.0, 8.0)
		hold_button.size = Vector2(corner, 40.0)
	if stick_button != null:
		stick_button.position = Vector2(screen.x - corner - 8.0, 52.0)
		stick_button.size = Vector2(corner, 40.0)
	var helm_w := screen.x - margin - corner - 16.0
	if not compact:
		helm_w = minf(520.0, screen.x - 220.0)
		if panel != null and panel.visible:
			helm_w = minf(helm_w, screen.x - 500.0)
	helm_w = clampf(helm_w, 148.0, screen.x - margin * 2.0)
	if short and screen.x > screen.y and panel != null and panel.visible:
		helm_w = minf(helm_w, 300.0)
	var left := margin
	var right := screen.x - margin
	if touch_on and not compact:
		left = 176.0
		right = screen.x - 210.0
	var land_panel := short and screen.x > screen.y and panel != null and panel.visible
	if land_panel:
		_size_primary(true)
		var need := 360.0
		if primary_row != null:
			need = primary_row.get_combined_minimum_size().x + 36.0
		var room := screen.x - left - 220.0
		need = clampf(need, 280.0, maxf(280.0, room))
		right = left + need
	var bar_room := right - left
	_size_primary(bar_room < 520.0)
	var primary_h := 72.0
	if primary_bar != null:
		primary_h = maxf(primary_bar.get_combined_minimum_size().y, 60.0)
	var secondary_h := 48.0
	var pad_top := screen.y - 8.0
	if touch_on and pad != null and pad.has_method("band_top"):
		pad_top = pad.band_top(screen, short)
	var gap := 8.0
	var secondary_y := pad_top - secondary_h - gap
	var primary_y := secondary_y - primary_h - gap
	primary_y = maxf(primary_y, 72.0 if short else 96.0)
	secondary_y = primary_y + primary_h + gap
	if secondary_y + secondary_h > pad_top - 4.0:
		secondary_y = pad_top - secondary_h - 4.0
		primary_y = secondary_y - primary_h - gap
	if primary_bar != null:
		var primary_w := right - left
		if not compact and not touch_on:
			var hug := primary_row.get_combined_minimum_size().x + 28.0 if primary_row != null else primary_w
			primary_w = minf(primary_w, maxf(hug, 180.0))
		primary_bar.position = Vector2(left, primary_y)
		primary_bar.size = Vector2(maxf(primary_w, 120.0), primary_h)
	if action_scroll != null:
		action_scroll.position = Vector2(left, secondary_y)
		action_scroll.size = Vector2(maxf(right - left, 120.0), secondary_h)
	var status_top := 8.0
	var room_bottom := primary_y - 8.0
	if stat_hull != null:
		stat_hull.get_parent().visible = not short
	if stat_heat != null:
		stat_heat.get_parent().visible = not short
	if helm_box != null:
		helm_box.add_theme_constant_override("separation", 2 if short else 4)
	if status_card != null:
		status_card.position = Vector2(margin, status_top)
		var want := 72.0
		if helm_box != null:
			want = helm_box.get_combined_minimum_size().y + 16.0
		var cap := maxf(72.0, room_bottom - status_top - 8.0)
		status_card.size = Vector2(helm_w, minf(want, cap))
		status_card.clip_contents = true
	var status_bottom := status_top + 80.0
	if status_card != null:
		status_bottom = status_card.position.y + status_card.size.y
	if banner != null:
		var banner_y := status_bottom + 4.0
		banner.position = Vector2(margin, banner_y)
		banner.size = Vector2(helm_w, 28.0 if short else 32.0)
		banner.visible = banner.text != "" and banner_y + banner.size.y < room_bottom - 36.0
	if log_card != null:
		var log_y := status_bottom + 6.0
		if banner != null and banner.visible:
			log_y = banner.position.y + banner.size.y + 4.0
		var log_cap := 44.0 if short else (64.0 if compact else 72.0)
		var log_room := room_bottom - 30.0 - log_y
		var log_h := minf(log_cap, log_room)
		log_card.position = Vector2(margin, log_y)
		log_card.size = Vector2(helm_w if compact or short else minf(620.0, screen.x - margin * 2.0), maxf(log_h, 0.0))
		if log_label != null and log_label.text == "":
			log_card.visible = false
		elif log_h < 28.0:
			log_card.visible = false
		else:
			log_card.visible = true
	if chat_line != null:
		chat_line.position = Vector2(margin, maxf(8.0, primary_y - 36.0))
		chat_line.size = Vector2(minf(420.0, helm_w), 32)
	if hint_label != null:
		hint_label.visible = false
	_place_minimap(screen, primary_y, short)
	_place_panel(screen, primary_y, short, pad_top)


func _process(_delta: float) -> void:
	if Game.mode != "sector" or Game.sim == null:
		if Game.map_open:
			Game.map_open = false
		return
	if Game.map_open and pad != null and pad.has_method("release"):
		pad.release()
	if not Game.sim.player.alive and Game.map_open:
		Game.map_open = false
	if banner != null:
		var text := ""
		if Game.sim.banner != "" and Game.sim.banner_t < 9.0:
			text = Game.sim.banner
		banner.text = text
		banner.visible = text != ""
	_refresh_helm()
	if not Game.sim.player.alive:
		dead_box.show()
		pause_box.hide()
		Game.paused = true
	elif dead_box.visible and Game.sim.player.alive:
		dead_box.hide()
	if panel_kind == "hangar":
		_refresh_hangar()
	elif panel_kind == "dossier":
		dossier_timer -= _delta
		if dossier_timer <= 0.0:
			dossier_timer = 0.35
			_fill_dossier()
	elif panel_kind == "heat":
		panel_body.text = _heat_text()
	elif panel_kind == "quest":
		panel_body.text = _quest_text()
	elif panel_kind == "claim":
		panel_body.text = _claim_text()
	elif panel_kind == "board":
		_fill_board()
	elif panel_kind == "market":
		_fill_market()
	elif panel_kind == "bay":
		_refresh_bay_text()


func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != "sector" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = (event as InputEventKey).keycode
	if chat_open:
		if key == KEY_ESCAPE:
			_close_chat()
			get_viewport().set_input_as_handled()
		return
	if tag_edit != null and is_instance_valid(tag_edit) and tag_edit.has_focus():
		if key == KEY_ESCAPE:
			tag_edit.release_focus()
			Game.text_entry = false
			get_viewport().set_input_as_handled()
		return
	if key == KEY_ESCAPE:
		if Game.map_open:
			Game.set_map_open(false)
		elif panel_kind != "":
			_close_panel()
		elif Game.sim != null and Game.sim.player.alive:
			_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if Game.paused:
		return
	match key:
		KEY_B:
			_toggle("bay")
		KEY_H:
			_toggle("hangar")
		KEY_I:
			_toggle("dossier")
		KEY_F:
			_toggle("heat")
		KEY_J:
			_toggle("quest")
		KEY_BRACKETLEFT:
			_toggle("board")
		KEY_Y:
			_say_result(QuestBoard.mark(Game.sim))
		KEY_O:
			_say_result(QuestBoard.accept(Game.sim))
		KEY_K:
			_toggle("claim")
		KEY_1, KEY_KP_1:
			_launch("survey_probe")
		KEY_2, KEY_KP_2:
			_launch("harvest_drone")
		KEY_3, KEY_KP_3:
			_launch(_boat_id())
		KEY_R:
			_repair()
		KEY_L:
			_say_result(Game.sim.try_lane())
		KEY_C:
			_say_result(Homestead.try_plant(Game.sim))
		KEY_M:
			_say_result(Homestead.try_make_core(Game.sim))
		KEY_G:
			_say_result(Homestead.tend(Game.sim))
		KEY_N:
			_say_result(Homestead.feed(Game.sim))
		KEY_U:
			_say_result(Homestead.haul(Game.sim))
		KEY_P:
			_say_result(Homestead.fit_pen(Game.sim))
		KEY_T:
			_say_result(Homestead.toggle_turret(Game.sim))
		KEY_V:
			Game.tap("crack", true)
		KEY_X:
			Game.tap("hail", true)
		KEY_Z:
			Game.tap("flag", true)
		KEY_ENTER, KEY_KP_ENTER:
			_toggle_chat()
		KEY_F5:
			_save()
		KEY_F9:
			_load()
		_:
			return
	get_viewport().set_input_as_handled()


func _build_helm() -> void:
	status_card = Control.new()
	status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_card.clip_contents = true
	root.add_child(status_card)
	var status_panel := Panel.new()
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	status_panel.add_theme_stylebox_override("panel", ThemeKit.glass(true))
	status_card.add_child(status_panel)
	helm_box = VBoxContainer.new()
	helm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	helm_box.add_theme_constant_override("separation", 4)
	helm_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	helm_box.offset_left = 12
	helm_box.offset_top = 8
	helm_box.offset_right = -12
	helm_box.offset_bottom = -8
	status_card.add_child(helm_box)
	var box := helm_box
	helm_name = ThemeKit.label("DARK SECTOR", 12, Color("7ed0dc"))
	helm_flight = ThemeKit.label("", 18, Color("f2fbff"))
	helm_zone = ThemeKit.label("", 13, Color("9fd4c8"))
	helm_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	helm_flight.autowrap_mode = TextServer.AUTOWRAP_OFF
	helm_zone.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats_grid = GridContainer.new()
	stats_grid.columns = 4
	stats_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_grid.add_theme_constant_override("h_separation", 8)
	stats_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(helm_name)
	box.add_child(helm_flight)
	box.add_child(stats_grid)
	stat_hull = _chip("HULL", false)
	stat_speed = _chip("0 m/s", true)
	stat_heat = _chip("HEAT", false)
	stat_purse = _chip("PURSE 0", true)
	box.add_child(helm_zone)
	haul_cue = ThemeKit.label("", 18, Color("ffd27a"))
	haul_cue.autowrap_mode = TextServer.AUTOWRAP_OFF
	haul_cue.clip_text = true
	box.add_child(haul_cue)
	helm_cargo = ThemeKit.label("", 13, Color("b7c9c4"))
	helm_craft = ThemeKit.label("", 13, Color("8eb8c0"))
	helm_cargo.autowrap_mode = TextServer.AUTOWRAP_OFF
	helm_craft.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(helm_cargo)
	box.add_child(helm_craft)
	banner = ThemeKit.label("", 16, Color("f0c36a"))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	log_card = PanelContainer.new()
	log_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_card.add_theme_stylebox_override("panel", ThemeKit.glass(false))
	root.add_child(log_card)
	log_label = ThemeKit.label("", 13, Color("d5e4e8"))
	log_label.clip_text = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_card.add_child(log_label)


func _chip(text: String, strong: bool) -> Label:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", ThemeKit.chip_box(strong))
	var lab := ThemeKit.label(text, 16 if strong else 13, Color("f4fcff") if strong else Color("c5d6dc"))
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(lab)
	stats_grid.add_child(chip)
	return lab


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.visible = false
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(420, 400)
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	panel_title = ThemeKit.label("", 20, Color("e6d7bf"))
	panel_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel_title.clip_text = true
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(panel_title)
	var close := ThemeKit.button("Close")
	close.custom_minimum_size = Vector2(88, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(_close_panel)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.focus_mode = Control.FOCUS_NONE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.clip_contents = true
	box.add_child(scroll)
	panel_scroll = scroll
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.custom_minimum_size = Vector2(280, 0)
	scroll.add_child(inner)
	panel_inner = inner
	panel_body = ThemeKit.label("", 14)
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(panel_body)
	bay_box = VBoxContainer.new()
	bay_box.visible = false
	inner.add_child(bay_box)
	hangar_box = VBoxContainer.new()
	hangar_box.visible = false
	inner.add_child(hangar_box)
	dossier_box = VBoxContainer.new()
	dossier_box.visible = false
	inner.add_child(dossier_box)
	board_box = VBoxContainer.new()
	board_box.visible = false
	board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(board_box)
	market_box = VBoxContainer.new()
	market_box.visible = false
	market_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(market_box)


func _build_pause() -> void:
	pause_box = _center_card("Paused")
	pause_box.visible = false
	var resume := ThemeKit.button("Resume the helm")
	resume.pressed.connect(_toggle_pause)
	var save := ThemeKit.button("Write the log")
	save.pressed.connect(_save)
	var load := ThemeKit.button("Read the log")
	load.pressed.connect(_load)
	var menu := ThemeKit.button("Leave the dock")
	menu.pressed.connect(_menu)
	var box := pause_box.get_child(0)
	box.add_child(resume)
	box.add_child(save)
	box.add_child(load)
	box.add_child(menu)


func _build_dead() -> void:
	dead_box = _center_card("The keel is a wreck")
	dead_box.visible = false
	var note := ThemeKit.label("The wreck keeps your name and some of the hold. The layout stays. You wake at the dock.", 14)
	note.custom_minimum_size = Vector2(360, 0)
	var load := ThemeKit.button("Read the log")
	load.pressed.connect(_load)
	var menu := ThemeKit.button("Leave the dock")
	menu.pressed.connect(_menu)
	var box := dead_box.get_child(0)
	box.add_child(note)
	box.add_child(load)
	box.add_child(menu)


func _size_primary(is_compact: bool) -> void:
	var wide := Control.SIZE_EXPAND_FILL if is_compact else Control.SIZE_SHRINK_CENTER
	var slot := 0.0 if is_compact else 108.0
	if cast_button != null:
		cast_button.text = "Cast" if is_compact else "Cast off"
		cast_button.add_theme_font_size_override("font_size", 14 if is_compact else 16)
	for node in [cast_button, dock_button, board_button, quest_button, probe_button]:
		if node == null:
			continue
		var button := node as Button
		var span := 120.0 if (button == cast_button or button == dock_button) and not is_compact else slot
		button.size_flags_horizontal = wide
		button.custom_minimum_size = Vector2(span, 44)
		if is_compact:
			button.add_theme_font_size_override("font_size", 14)


func _mount_primary() -> void:
	primary_bar = PanelContainer.new()
	primary_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	primary_bar.add_theme_stylebox_override("panel", ThemeKit.glass(true))
	root.add_child(primary_bar)
	primary_row = HBoxContainer.new()
	primary_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	primary_row.add_theme_constant_override("separation", 8)
	primary_bar.add_child(primary_row)
	_reparent(cast_button)
	_reparent(dock_button)
	_reparent(board_button)
	quest_button = ThemeKit.button("Quests", true)
	quest_button.custom_minimum_size = Vector2(112, 48)
	quest_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quest_button.pressed.connect(func() -> void: _toggle("quest"))
	primary_row.add_child(quest_button)
	probe_button = ThemeKit.button("Probe", true)
	probe_button.custom_minimum_size = Vector2(112, 48)
	probe_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	probe_button.pressed.connect(func() -> void: _launch("survey_probe"))
	primary_row.add_child(probe_button)


func _reparent(node: Control) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	primary_row.add_child(node)


func _build_actions() -> void:
	action_scroll = ScrollContainer.new()
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.focus_mode = Control.FOCUS_NONE
	action_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	action_scroll.gui_input.connect(_scroll_actions)
	root.add_child(action_scroll)
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	action_scroll.add_child(action_row)
	_group("COMBAT")
	_action("Lock", func() -> void: Game.tap("lock_cycle", 1))
	_action("Stop", func() -> void: Game.tap("order", {"kind": "stop"}))
	_group("SHIP")
	_action("Ship", func() -> void: _toggle("bay"))
	_action("Weld", _repair)
	_action("Hangar", func() -> void: _toggle("hangar"))
	_action("Harvest", func() -> void: _launch("harvest_drone"))
	_action("Boat", func() -> void: _launch(_boat_id()))
	_group("SURVEY")
	_action("Scan", func() -> void: _toggle("dossier"))
	_action("Mark", func() -> void:
		if Game.sim == null:
			return
		_say_result(QuestBoard.mark(Game.sim))
	)
	_action("Take", func() -> void:
		if Game.sim == null:
			return
		_say_result(QuestBoard.accept(Game.sim))
	)
	_action("Site", func() -> void:
		if Game.sim == null:
			return
		_say_result(Game.sim.enter_site())
	)
	_group("DOCK")
	_action("Market", func() -> void: _toggle("market"))
	_action("Lane", func() -> void:
		if Game.sim == null:
			return
		_say_result(Game.sim.try_lane())
	)
	_group("LAW")
	_action("Hail", func() -> void: Game.tap("hail", true))
	_action("Flag", func() -> void: Game.tap("flag", true))
	_action("Heat", func() -> void: _toggle("heat"))
	_action("Claim", func() -> void: _toggle("claim"))
	_action("Crack", func() -> void: Game.tap("crack", true))
	_group("COMMS")
	_action("Chat", _toggle_chat)


func _group(text: String) -> void:
	var tag := ThemeKit.label(text, 10, Color("6fa6b2"))
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.custom_minimum_size = Vector2(0, 0)
	if action_row.get_child_count() > 0:
		var gap := VSeparator.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gap.add_theme_constant_override("separation", 10)
		action_row.add_child(gap)
	action_row.add_child(tag)


func _action(text: String, call: Callable) -> void:
	var node := ThemeKit.button(text, false)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.custom_minimum_size = Vector2(84, 44)
	node.pressed.connect(call)
	action_row.add_child(node)


func _scroll_actions(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var button := event as InputEventMouseButton
	if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		action_scroll.scroll_horizontal += 96
	elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
		action_scroll.scroll_horizontal -= 96


func _toggle_stick() -> void:
	touch_chosen = true
	touch_on = not touch_on
	if not touch_on:
		Game.clear_flight()
	_fit()


func _center_card(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 220)
	root.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(ThemeKit.label(title, 22, Color("e6d7bf")))
	return card


func _refresh_helm() -> void:
	var sim = Game.sim
	var hull: Dictionary = sim.defs.ships[sim.player.class_id]
	var stats := Fit.stats(sim.defs, sim.player)
	var zoom_word := "Tactical"
	if Game.zoom < 0.28:
		zoom_word = "Sector"
	elif Game.zoom < 0.7:
		zoom_word = "Local"
	var moored := bool(sim.player.get("moored", false))
	if cast_button != null:
		cast_button.visible = moored
	if dock_button != null:
		dock_button.visible = sim.can_force_dock()
	_place_board_button(compact)
	helm_name.text = str(sim.defs.system.name).to_upper()
	var tag := DockBoard.tag_of(sim)
	show_tag = tag != ""
	var screen := get_viewport().get_visible_rect().size
	if tag != "" and screen.y < 520.0:
		helm_flight.text = tag
	elif compact:
		helm_flight.text = str(hull.callsign) if tag == "" else "%s  ·  %s" % [str(hull.callsign), tag]
	else:
		helm_flight.text = "%s   ·   %s" % [str(hull.callsign), str(hull.class_name)]
		if tag != "":
			helm_flight.text += "   ·   %s" % tag
	if helm_flight != null:
		helm_flight.autowrap_mode = TextServer.AUTOWRAP_OFF
		helm_flight.clip_text = true
		helm_flight.visible = screen.y >= 430.0 or show_tag
	var hp_now := int(sim.player.hp)
	var hp_max := int(sim.player.max_hp)
	stat_hull.text = "HULL  %d/%d" % [hp_now, hp_max]
	stat_hull.add_theme_color_override("font_color", Color("f0a0a0") if hp_now < hp_max * 0.45 else Color("e9fbff"))
	stat_speed.text = "%d m/s" % int(sim.player.vel.length())
	var boosting := bool(sim.player.get("boosting", false))
	stat_speed.add_theme_color_override("font_color", Color("ffd59a") if boosting else Color("f4fcff"))
	var law_name := Law.at(sim, sim.player.pos)
	var link_word := ""
	if Game.link != null and str(Game.link.role) == "host":
		link_word = "  ·  HOST %s" % str(Game.link.code)
	elif Game.link != null and str(Game.link.role) == "client":
		link_word = "  ·  GUEST"
	var heat := float(sim.heat.get(sim._pdo_id(), 0.0))
	var stage := sim.heat_stage()
	var heat_word := HeatWords.word(heat)
	if stage == "guns":
		heat_word = "guns"
	elif stage == "fine":
		heat_word = "fined"
	elif stage == "hail":
		heat_word = "hailed"
	stat_heat.text = "HEAT  %s" % heat_word
	var heat_color := Color("9fd4c8")
	if stage == "guns":
		heat_color = Color("f0a0a0")
	elif stage == "fine" or stage == "hail":
		heat_color = Color("f0c36a")
	stat_heat.add_theme_color_override("font_color", heat_color)
	stat_purse.text = "PURSE  %d" % DockBoard.purse(sim)
	stat_purse.add_theme_color_override("font_color", Color("f0d48a"))
	var place := "Moored" if moored else ScaleFrame.layer_name(int(sim.layer))
	var dock_word := ""
	if moored == false and str(sim.defs.system.id) == "HC-V1-R1-S1" and int(sim.layer) == ScaleFrame.BAND and sim.beacon_pos != Vector2.ZERO:
		var gap: float = sim.player.pos.distance_to(sim.beacon_pos)
		dock_word = "  ·  Helion Dock %d m" % int(gap)
	helm_zone.text = "%s  ·  %s  ·  %s%s%s" % [place, zoom_word, law_name, dock_word, link_word]
	helm_zone.add_theme_color_override("font_color", Law.color_of(law_name))
	if haul_cue != null:
		var cue := DockBoard.slip_line(sim)
		haul_cue.text = cue
		haul_cue.visible = cue != ""
	var repair := ""
	if sim.player.pos.distance_to(sim.beacon_pos) <= 170.0:
		repair = "  ·  Weld live"
	var gate := sim.nearby_gate()
	if not gate.is_empty():
		repair += "  ·  %s" % str(gate.name)
	helm_cargo.text = _cargo_line(sim, stats) + repair
	helm_cargo.visible = not compact
	helm_craft.text = _craft_line(sim)
	helm_craft.visible = not compact
	var bits: Array = []
	for line in sim.lines:
		bits.append(str(line.text))
	var keep := 2 if compact else 3
	if bits.size() > keep:
		bits = bits.slice(0, keep)
	log_label.text = "\n".join(bits)
	log_label.max_lines_visible = keep
	if log_card != null:
		log_card.visible = log_label.text != "" and log_card.size.y >= 28.0
	if screen.x >= 64.0:
		_layout_chrome(screen)


func _mass_line(stats: Dictionary) -> String:
	var mass := float(stats.mass)
	var base := float(stats.base_mass)
	if mass > base * 1.2:
		return "heavy %.0f t" % mass
	if mass > base * 1.08:
		return "loaded %.0f t" % mass
	return "mass %.0f t" % mass


func _cargo_line(sim, stats: Dictionary) -> String:
	if sim.player.cargo.is_empty():
		return "Hold empty.  0/%d" % int(stats.cargo_cap)
	var parts: Array = []
	for id in sim.player.cargo.keys():
		parts.append("%s ×%d" % [sim.resource_name(str(id)), int(sim.player.cargo[id])])
	return "%s    %d/%d" % ["   ".join(parts), Fit.cargo_used(sim.player), int(stats.cargo_cap)]


func _craft_line(sim) -> String:
	var bits: Array = []
	if sim.hangar_down():
		bits.append("Hangar down — craft cannot come aboard")
	for item in sim.craft:
		if str(item.state) == "docked":
			continue
		bits.append("%s %s" % [item.name, item.state])
	if bits.is_empty():
		return "Hangar sealed. Craft are aboard."
	if sim.hangar_down() and bits.size() == 1:
		return str(bits[0])
	return "   ".join(bits)


func _toggle(kind: String) -> void:
	if panel_kind == kind:
		_close_panel()
		return
	panel_kind = kind
	panel.show()
	panel_body.visible = kind in ["heat", "quest", "claim"]
	bay_box.visible = kind == "bay"
	hangar_box.visible = kind == "hangar"
	dossier_box.visible = kind == "dossier"
	board_box.visible = kind == "board"
	if market_box != null:
		market_box.visible = kind == "market"
	match kind:
		"bay":
			panel_title.text = "Ship"
			_build_bay()
		"hangar":
			panel_title.text = "Hangar"
			_build_hangar()
		"dossier":
			panel_title.text = "Scan dossier"
			_fill_dossier()
		"heat":
			panel_title.text = "Heat and memory"
			panel_body.text = _heat_text()
		"quest":
			panel_title.text = "Quest log"
			panel_body.text = _quest_text()
		"board":
			panel_title.text = "Helion Dock board"
			board_sig = ""
			_fill_board()
		"market":
			panel_title.text = "Helion market"
			_fill_market()
		"claim":
			panel_title.text = "Homestead"
			panel_body.text = _claim_text()
	_fit()


func _close_panel() -> void:
	if tag_edit != null and is_instance_valid(tag_edit):
		tag_edit.release_focus()
	Game.text_entry = false
	panel_kind = ""
	panel.hide()
	_fit()


func _place_minimap(screen: Vector2, primary_y: float, short: bool) -> void:
	if minimap == null:
		return
	var blocked := panel != null and panel.visible
	if blocked or stick_button == null:
		minimap.visible = false
		return
	var top := stick_button.position.y + stick_button.size.y + 6.0
	var room := primary_y - 8.0 - top
	var want := 156.0
	if compact:
		want = 104.0
	if short:
		want = 88.0
	var side := minf(want, room)
	var right := screen.x - 8.0
	var left_limit := 8.0
	if status_card != null and status_card.visible:
		left_limit = maxf(left_limit, status_card.position.x + status_card.size.x + 8.0)
	if banner != null and banner.visible:
		left_limit = maxf(left_limit, banner.position.x + banner.size.x + 8.0)
	if log_card != null and log_card.visible:
		left_limit = maxf(left_limit, log_card.position.x + log_card.size.x + 8.0)
	side = minf(side, right - left_limit)
	if side < 72.0 or room < 72.0:
		minimap.visible = false
		return
	minimap.visible = true
	minimap.position = Vector2(right - side, top)
	minimap.size = Vector2(side, side)


func _place_panel(screen: Vector2, primary_y: float, short: bool, pad_top: float) -> void:
	if panel == null:
		return
	var land := short and screen.x > screen.y and panel.visible
	if land:
		panel.custom_minimum_size = Vector2(0, 0)
		panel.clip_contents = true
		var x := 8.0
		if status_card != null:
			x = status_card.position.x + status_card.size.x + 8.0
		if primary_bar != null:
			x = maxf(x, primary_bar.position.x + primary_bar.size.x + 8.0)
		if action_scroll != null:
			x = maxf(x, action_scroll.position.x + action_scroll.size.x + 8.0)
		var right := screen.x - 8.0
		if hold_button != null and hold_button.visible:
			right = minf(right, hold_button.position.x - 8.0)
		if stick_button != null and stick_button.visible:
			right = minf(right, stick_button.position.x - 8.0)
		var y := 8.0
		var bottom := pad_top - 8.0
		if right - x < 200.0 and status_card != null:
			x = 8.0
			y = status_card.position.y + status_card.size.y + 6.0
			right = screen.x - 8.0
			bottom = primary_y - 8.0
		var height := bottom - y
		if height < 96.0:
			bottom = primary_y - 8.0
			height = maxf(0.0, bottom - y)
		panel.position = Vector2(x, y)
		panel.size = Vector2(maxf(120.0, right - x), maxf(0.0, height))
		if panel_scroll != null:
			panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
			panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			panel_scroll.clip_contents = true
		return
	if panel_scroll != null:
		panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if panel_kind == "bay" and not compact:
		# Fitting glass sits in the open helm: right of the status card, above
		# the tank capsule, and clear of Hold and Stick.
		var left := 360.0
		if status_card != null and status_card.size.x > 40.0:
			left = status_card.position.x + status_card.size.x + 12.0
		var right := screen.x - 16.0
		if hold_button != null and hold_button.visible:
			right = minf(right, hold_button.position.x - 8.0)
		if stick_button != null and stick_button.visible:
			right = minf(right, stick_button.position.x - 8.0)
		var top := 16.0
		var bottom := screen.y - 160.0
		if overlay != null:
			var cap: Control = overlay.get("capsule")
			if cap != null and cap.visible:
				bottom = minf(bottom, cap.position.y - 8.0)
		panel.custom_minimum_size = Vector2(0, 0)
		panel.position = Vector2(left, top)
		panel.size = Vector2(maxf(480.0, right - left), maxf(280.0, bottom - top))
		_fit_ship_pane()
		return
	var side := 460.0
	if compact:
		panel.custom_minimum_size = Vector2(0, 0)
		panel.position = Vector2(8, screen.y * 0.22)
		panel.size = Vector2(screen.x - 16.0, screen.y * 0.5)
	else:
		panel.custom_minimum_size = Vector2(420, 400)
		panel.position = Vector2(screen.x - side - 16.0, 16)
		panel.size = Vector2(side, screen.y - 150.0)


func _place_board_button(_is_compact: bool) -> void:
	if board_button == null:
		return
	var at := false
	if Game.sim != null and Game.mode == "sector":
		at = DockBoard.at_pad(Game.sim)
	board_button.visible = at


func _fill_board() -> void:
	if Game.sim == null or board_box == null:
		return
	var sim = Game.sim
	var sig := "%s|%d" % [DockBoard.at_pad(sim), DockBoard.purse(sim)]
	var row: Dictionary = {}
	for job in DockBoard.jobs(sim):
		row = job
		sig += "|%s:%s:%s" % [str(row.id), str(row.state), str(row.blurb)]
	if sig == board_sig and board_box.get_child_count() > 0:
		return
	board_sig = sig
	for child in board_box.get_children():
		child.queue_free()
	var where := "Stand the Helion pad to take a slip. Pay lands in the purse."
	if DockBoard.at_pad(sim):
		where = "You are on the Helion pad. Take a slip. Pay lands in the purse."
	board_box.add_child(_flat(where, 14, Color("cbb892")))
	board_box.add_child(_flat("Purse %d" % DockBoard.purse(sim), 16, Color("d7e6c8")))
	var market := ThemeKit.button("Market")
	market.pressed.connect(func() -> void: _toggle("market"))
	board_box.add_child(market)
	for slip in DockBoard.jobs(sim):
		row = slip
		var job_id := str(row.id)
		board_box.add_child(_board_line("%s    pay %d    [%s]" % [str(row.title), int(row.pay), str(row.state)], 16))
		board_box.add_child(_board_line(str(row.blurb), 13, Color("8d826c")))
		if str(row.state) == "open":
			var verb := "Take %s" % job_id
			var take := ThemeKit.button(verb)
			take.pressed.connect(_take_dock_job.bind(job_id))
			board_box.add_child(take)
		board_box.add_child(ThemeKit.label(" ", 8))


func _fill_market() -> void:
	if Game.sim == null or market_box == null:
		return
	var sim = Game.sim
	var focused := tag_edit != null and is_instance_valid(tag_edit) and tag_edit.has_focus()
	var draft := ""
	if tag_edit != null and is_instance_valid(tag_edit):
		draft = tag_edit.text
	if market_box.get_child_count() > 0 and (focused or draft != DockBoard.tag_of(sim)):
		_paint_market(sim)
		return
	var sig := "%s|%d|%d|%s" % [DockBoard.at_pad(sim), DockBoard.purse(sim), DockBoard.holding(sim), DockBoard.tag_of(sim)]
	if sig == market_sig and market_box.get_child_count() > 0:
		return
	market_sig = sig
	for child in market_box.get_children():
		child.queue_free()
	tag_edit = null
	var where := "The Helion market stands on the pad."
	if DockBoard.at_pad(sim):
		where = "Glasswheat on the Helion pad. Buy %d. Sell %d." % [DockBoard.BUY_PRICE, DockBoard.SELL_PRICE]
	market_box.add_child(_flat(where, 14, Color("cbb892")))
	market_purse = _flat("Purse %d" % DockBoard.purse(sim), 16, Color("d7e6c8"))
	market_box.add_child(market_purse)
	market_hold = _flat("Glasswheat in the hold  %d" % DockBoard.holding(sim), 15)
	market_box.add_child(market_hold)
	var buy := ThemeKit.button("Buy glasswheat")
	buy.pressed.connect(_buy_good)
	market_box.add_child(buy)
	var sell := ThemeKit.button("Sell glasswheat")
	sell.pressed.connect(_sell_good)
	market_box.add_child(sell)
	market_box.add_child(_flat("Yard. One mount is a first slip.", 14, Color("cbb892")))
	for kit_id in ["gun_sponson", "laser_bank", "missile_rack", "iron_belt", "splinter_pack"]:
		var kit: Dictionary = DockBoard.KIT[kit_id]
		var label := "%s  %d" % [str(kit.name), int(kit.price)]
		var buy_kit := ThemeKit.button(label)
		buy_kit.pressed.connect(_buy_kit.bind(kit_id))
		market_box.add_child(buy_kit)
	market_box.add_child(_flat("Corp tag", 14, Color("cbb892")))
	tag_edit = LineEdit.new()
	tag_edit.name = "CorpTag"
	tag_edit.placeholder_text = "Corp tag"
	tag_edit.max_length = DockBoard.TAG_LEN
	tag_edit.text = DockBoard.tag_of(sim)
	tag_edit.custom_minimum_size = Vector2(180, 44)
	tag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_edit.focus_mode = Control.FOCUS_ALL
	tag_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	tag_edit.context_menu_enabled = false
	tag_edit.caret_blink = true
	tag_edit.gui_input.connect(_focus_tag)
	tag_edit.text_submitted.connect(func(_text: String) -> void: _apply_tag())
	market_box.add_child(tag_edit)
	var set_tag := ThemeKit.button("Set tag")
	set_tag.pressed.connect(_apply_tag)
	market_box.add_child(set_tag)


func _focus_tag(event: InputEvent) -> void:
	if tag_edit == null or not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.pressed == false:
		return
	tag_edit.grab_focus()
	Game.text_entry = true
	Game.clear_flight_keys()


func _paint_market(sim) -> void:
	if market_purse != null and is_instance_valid(market_purse):
		market_purse.text = "Purse %d" % DockBoard.purse(sim)
	if market_hold != null and is_instance_valid(market_hold):
		market_hold.text = "Glasswheat in the hold  %d" % DockBoard.holding(sim)
	var where := "The Helion market stands on the pad."
	if DockBoard.at_pad(sim):
		where = "Glasswheat on the Helion pad. Buy %d. Sell %d." % [DockBoard.BUY_PRICE, DockBoard.SELL_PRICE]
	if market_box.get_child_count() > 0 and market_box.get_child(0) is Label:
		(market_box.get_child(0) as Label).text = where


func _board_line(text: String, size: int, color: Color = Color("e7f3f6")) -> Label:
	var node := ThemeKit.label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A zero-width wrap pass turns each slip into a column tall enough to paint through the bars.
	node.custom_minimum_size = Vector2(168, 0)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


func _flat(text: String, size: int, color: Color = Color("e7f3f6")) -> Label:
	var node := ThemeKit.label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.clip_text = true
	return node


func _buy_good() -> void:
	if Game.sim == null:
		return
	var message := DockBoard.buy_good(Game.sim)
	if message != "":
		Game.sim.say(message)
	market_sig = ""
	_fill_market()


func _sell_good() -> void:
	if Game.sim == null:
		return
	var message := DockBoard.sell_good(Game.sim)
	if message != "":
		Game.sim.say(message)
	market_sig = ""
	_fill_market()


func _apply_tag() -> void:
	if Game.sim == null or tag_edit == null or not is_instance_valid(tag_edit):
		return
	var clean := DockBoard.set_tag(Game.sim, tag_edit.text)
	tag_edit.text = clean
	tag_edit.release_focus()
	market_sig = ""
	_fill_market()


func _take_dock_job(job_id: String) -> void:
	if Game.sim == null:
		return
	var message := DockBoard.take(Game.sim, job_id)
	if message != "":
		Game.sim.say(message)
	board_sig = ""


func _toggle_chat() -> void:
	chat_open = not chat_open
	chat_line.visible = chat_open
	if chat_open:
		chat_line.grab_focus()
	else:
		chat_line.release_focus()


func _close_chat() -> void:
	chat_open = false
	chat_line.visible = false
	chat_line.release_focus()


func _submit_chat(text: String) -> void:
	_close_chat()
	var line := text.strip_edges()
	chat_line.text = ""
	if line == "" or Game.sim == null:
		return
	if Game.link != null and str(Game.link.role) == "client":
		Game.link.send_chat(str(Game.sim.player.get("player_id", "")), line)
		return
	Game.sim.post_chat(str(Game.sim.player.get("player_id", "")), line)


func _toggle_pause() -> void:
	if Game.sim == null or not Game.sim.player.alive:
		return
	Game.paused = not Game.paused
	pause_box.visible = Game.paused
	if Game.paused:
		_close_panel()
		Game.map_open = false


func _build_bay() -> void:
	for child in bay_box.get_children():
		child.queue_free()
	bay_buttons = {}
	ship_filters = {}
	ship_list = null
	ship_list_scroll = null
	var wide := not compact
	var split: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bay_box.add_child(split)
	var browser := VBoxContainer.new()
	browser.add_theme_constant_override("separation", 6)
	browser.custom_minimum_size = Vector2(300, 0)
	browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not wide else Control.SIZE_SHRINK_BEGIN
	browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(browser)
	var search := LineEdit.new()
	search.placeholder_text = "Search the yard"
	search.text = ship_query
	search.custom_minimum_size = Vector2(0, 36)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_search(search)
	search.text_changed.connect(func(next: String) -> void:
		ship_query = next
		_refill_ship_list()
	)
	browser.add_child(search)
	var loads := HBoxContainer.new()
	loads.add_theme_constant_override("separation", 4)
	for pair in [["belt", "Belt"], ["crystal", "Crystal"], ["rack", "Rack"]]:
		var chip := ThemeKit.button(str(pair[1]))
		chip.custom_minimum_size = Vector2(72, 44)
		chip.pressed.connect(_cycle_load.bind(str(pair[0])))
		loads.add_child(chip)
	browser.add_child(loads)
	var filters := GridContainer.new()
	filters.columns = 3
	filters.add_theme_constant_override("h_separation", 4)
	filters.add_theme_constant_override("v_separation", 4)
	browser.add_child(filters)
	for pair in [["", "All"], ["hull", "Hull"], ["offense", "Guns"], ["hangar", "Hangar"], ["farm", "Farm"], ["claim", "Claim"]]:
		var family := str(pair[0])
		var chip := ThemeKit.button(str(pair[1]))
		chip.custom_minimum_size = Vector2(72, 44)
		chip.pressed.connect(_pick_family.bind(family))
		filters.add_child(chip)
		ship_filters[family] = chip
		ThemeKit.paint(chip, family == ship_family)
	var crew_lines: Array = []
	for person in Game.sim.player.crew:
		crew_lines.append("%s — %s" % [person.name, person.skill])
	var crew_text := "No names on the board."
	if not crew_lines.is_empty():
		crew_text = ", ".join(crew_lines)
	var crew := ThemeKit.label(crew_text, 12, Color("9fd0c8"))
	crew.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	browser.add_child(crew)
	ship_list = VBoxContainer.new()
	ship_list.add_theme_constant_override("separation", 4)
	ship_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if wide:
		ship_list_scroll = ScrollContainer.new()
		ship_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ship_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ship_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ship_list_scroll.custom_minimum_size = Vector2(250, 220)
		ship_list_scroll.add_child(ship_list)
		browser.add_child(ship_list_scroll)
	else:
		browser.add_child(ship_list)
	bay_preview = ShipGlass.new()
	bay_preview.custom_minimum_size = Vector2(280, 320) if wide else Vector2(0, 200)
	bay_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bay_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if wide:
		split.add_child(bay_preview)
	else:
		split.add_child(bay_preview)
		split.move_child(bay_preview, 0)
	bay_detail = ThemeKit.label("", 13, Color("cbb892"))
	bay_box.add_child(bay_detail)
	_refill_ship_list()
	_fit_ship_pane()


func _fit_ship_pane() -> void:
	if panel_kind != "bay" or bay_box == null or panel == null:
		return
	var inner_h := panel.size.y - 86.0
	bay_box.custom_minimum_size = Vector2(0, maxf(200.0, inner_h))
	if ship_list_scroll != null:
		ship_list_scroll.custom_minimum_size = Vector2(250, maxf(160.0, inner_h - 150.0))


func _pick_family(family: String) -> void:
	ship_family = family
	for key in ship_filters.keys():
		var chip: Button = ship_filters[key]
		if is_instance_valid(chip):
			ThemeKit.paint(chip, str(key) == family)
	_refill_ship_list()


func _family_head(word: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := ThemeKit.label(word.to_upper(), 12, Color("c4a46a"))
	lab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(lab)
	var rule := ColorRect.new()
	rule.color = Color(0.72, 0.58, 0.32, 0.75)
	rule.custom_minimum_size = Vector2(24, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	return row


func _family_word(family: String) -> String:
	match family:
		"hull":
			return "Hull"
		"offense":
			return "Guns"
		"hangar":
			return "Hangar"
		"farm":
			return "Farm"
		"claim":
			return "Claim"
		_:
			return family.capitalize()


func _refill_ship_list() -> void:
	if ship_list == null or Game.sim == null:
		return
	for child in ship_list.get_children():
		child.queue_free()
	bay_buttons = {}
	var sim = Game.sim
	var query := ship_query.strip_edges().to_lower()
	var groups: Dictionary = {}
	var ids: Array = []
	for module_id in sim.player.yard:
		ids.append(str(module_id))
	for module_id in sim.player.modules:
		var key := str(module_id)
		if not ids.has(key):
			ids.append(key)
	for module_id in ids:
		if not sim.defs.modules.has(module_id):
			continue
		var mod: Dictionary = sim.defs.modules[module_id]
		var family := str(mod.get("family", ""))
		if ship_family != "" and family != ship_family:
			continue
		var blob := ("%s %s" % [str(mod.get("name", "")), str(mod.get("blurb", ""))]).to_lower()
		if query != "" and blob.find(query) < 0:
			continue
		if not groups.has(family):
			groups[family] = []
		var bucket: Array = groups[family]
		bucket.append(module_id)
	var order: Array = ["hull", "offense", "hangar", "farm", "claim"]
	var any := false
	for family in order:
		if not groups.has(family):
			continue
		any = true
		ship_list.add_child(_family_head(_family_word(str(family))))
		var members: Array = groups[family]
		members.sort()
		for module_id in members:
			_add_ship_row(str(module_id))
	for family in groups.keys():
		if order.has(str(family)):
			continue
		any = true
		ship_list.add_child(_family_head(_family_word(str(family))))
		var extra: Array = groups[family]
		extra.sort()
		for module_id in extra:
			_add_ship_row(str(module_id))
	if not any:
		ship_list.add_child(ThemeKit.label("Nothing in the yard matches.", 13, Color("8d826c")))
	_refresh_bay_text()


func _add_ship_row(module_id: String) -> void:
	var mod: Dictionary = Game.sim.defs.modules[module_id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name := ThemeKit.label(str(mod.name), 14)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.clip_text = true
	row.add_child(name)
	var meta := ThemeKit.label("", 12, Color("8d826c"))
	meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	meta.custom_minimum_size = Vector2(168, 0)
	row.add_child(meta)
	var button := ThemeKit.button("Bolt on")
	button.custom_minimum_size = Vector2(92, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.pressed.connect(_on_bolt.bind(module_id))
	if mod.has("weapon"):
		var before := Fit.stats(Game.sim.defs, Game.sim.player)
		var hypo: Dictionary = Game.sim.player.duplicate(true)
		if not hypo.modules.has(module_id):
			hypo.modules = hypo.modules.duplicate()
			hypo.modules.append(module_id)
		var after := Fit.stats(Game.sim.defs, hypo)
		button.tooltip_text = "Mass %+.0f. Power %+.0f. Signature %+.2f. %s" % [
			float(after.mass) - float(before.mass),
			float(after.power_draw) - float(before.power_draw),
			float(after.signature) - float(before.signature),
			Fit.weapon_line(mod.weapon),
		]
	row.add_child(button)
	ship_list.add_child(row)
	bay_buttons[module_id] = {"meta": meta, "button": button}


func _style_search(line: LineEdit) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.012, 0.025, 0.034, 0.94)
	box.border_color = Color(0.45, 0.68, 0.76, 0.5)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	var focus := box.duplicate() as StyleBoxFlat
	focus.border_color = Color(0.62, 0.92, 0.96, 0.92)
	line.add_theme_stylebox_override("normal", box)
	line.add_theme_stylebox_override("focus", focus)
	line.add_theme_color_override("font_color", Color("d7eef2"))
	line.add_theme_color_override("font_placeholder_color", Color("7a8e96"))
	line.add_theme_font_size_override("font_size", 14)


func _refresh_bay_text() -> void:
	if bay_detail == null or not is_instance_valid(bay_detail):
		return
	var sim = Game.sim
	var stats := Fit.stats(sim.defs, sim.player)
	var keel := "Keel within tolerance."
	if stats.keel_warn:
		keel = "Keel complaining."
	var power_line := "Power %.0f/%.0f." % [stats.power_draw, stats.power]
	if stats.power_spare < -0.01:
		power_line = "Power %.0f/%.0f. Overloaded." % [stats.power_draw, stats.power]
	var crew_line := "Crew %d/%d." % [int(stats.crew_used), int(stats.crew_budget)]
	if stats.crew_over:
		crew_line = "Crew %d/%d. Overloaded." % [int(stats.crew_used), int(stats.crew_budget)]
	var shut := ""
	if sim.in_combat():
		shut = "\nBay shut. Break off before you touch a bolt."
	HelmCombat.ensure_rounds(sim.player)
	var rounds: Dictionary = sim.player.rounds
	var kit_line := "Sig %.2f. Belt %s %d. Crystal %s. Rack %s %d." % [
		stats.signature,
		str(sim.player.get("belt", "iron")),
		int(rounds.get(str(sim.player.get("belt", "iron")), 0)),
		str(sim.player.get("crystal", "standard")),
		str(sim.player.get("rack", "splinter")),
		int(rounds.get(str(sim.player.get("rack", "splinter")), 0)),
	]
	var mounts := ""
	for mount in Fit.mounts(sim.defs, sim.player):
		mounts += "\n%s — %s." % [str(mount.name), Fit.weapon_line(mount)]
	bay_detail.text = "Mass %.0f t. Yaw %.0f°/s. Hold %d. Sensor %.0f. %s. %s %s %s. %s%s%s" % [
		stats.mass,
		stats.yaw_deg,
		stats.cargo_cap,
		stats.sensor,
		stats.signature_word.capitalize(),
		power_line,
		crew_line,
		keel,
		kit_line,
		mounts,
		shut,
	]
	var hot := bool(stats.keel_warn) or float(stats.power_spare) < -0.01 or bool(stats.crew_over)
	var tone := Color("e6d7bf")
	if hot:
		tone = Color("e7b15a")
	bay_detail.add_theme_color_override("font_color", tone)
	var fighting := sim.in_combat()
	for module_id in bay_buttons.keys():
		var row: Dictionary = bay_buttons[module_id]
		var meta: Label = row.meta
		var button: Button = row.button
		if not is_instance_valid(meta) or not is_instance_valid(button):
			continue
		var mod: Dictionary = sim.defs.modules[module_id]
		var mounted: bool = bool(sim.player.modules.has(module_id))
		var state := "Yard"
		if mounted:
			state = "Fitted"
		var weapon_note := ""
		if mod.has("weapon"):
			weapon_note = "  " + Fit.weapon_line(mod.weapon)
		var price := int(mod.get("price", 0))
		if price > 0 and not mounted and not DockBoard.paid_mount(sim, str(module_id)):
			weapon_note += "  %d" % price
		meta.text = "%s  %s%s" % [str(mod.size), state, weapon_note]
		button.disabled = fighting
		if mounted:
			button.text = "Pull off"
		else:
			button.text = "Bolt on"
	if bay_preview != null and is_instance_valid(bay_preview):
		bay_preview.queue_redraw()


func _on_bolt(module_id: String) -> void:
	if Game.sim == null:
		return
	var sim = Game.sim
	if sim.player.modules.has(module_id):
		sim.uninstall(module_id)
	else:
		var mod: Dictionary = sim.defs.modules.get(module_id, {})
		var price := int(mod.get("price", 0))
		if price > 0:
			if not DockBoard.at_pad(sim):
				sim.say("Weld that mount at the Helion pad.")
				return
			if not DockBoard.paid_mount(sim, module_id):
				var note := DockBoard.buy_kit(sim, module_id)
				if note != "":
					sim.say(note)
					return
		sim.install(module_id)
	_refresh_bay_text()
	if bay_preview != null and is_instance_valid(bay_preview):
		bay_preview.queue_redraw()


func _buy_kit(kit_id: String) -> void:
	if Game.sim == null:
		return
	var note := DockBoard.buy_kit(Game.sim, kit_id)
	if note != "":
		Game.sim.say(note)
	_refresh_bay_text()


func _cycle_load(kind: String) -> void:
	if Game.sim == null:
		return
	var ship: Dictionary = Game.sim.player
	HelmCombat.ensure_rounds(ship)
	if kind == "belt":
		var order := ["iron", "tungsten", "incendiary"]
		var at := order.find(str(ship.get("belt", "iron")))
		for step in order.size():
			var nxt: String = order[(at + 1 + step) % order.size()]
			if int(ship.rounds.get(nxt, 0)) > 0:
				ship.belt = nxt
				Game.sim.say("Belt set to %s." % nxt)
				break
	elif kind == "crystal":
		var order := ["standard", "infrared", "ultraviolet"]
		var at := order.find(str(ship.get("crystal", "standard")))
		ship.crystal = order[(at + 1) % order.size()]
		Game.sim.say("Crystal set to %s." % str(ship.crystal))
	elif kind == "rack":
		var order := ["splinter", "breacher", "siege"]
		var at := order.find(str(ship.get("rack", "splinter")))
		for step in order.size():
			var nxt: String = order[(at + 1 + step) % order.size()]
			if int(ship.rounds.get(nxt, 0)) > 0:
				ship.rack = nxt
				Game.sim.say("Rack set to %s." % nxt)
				break
	_refresh_bay_text()


func _build_hangar() -> void:
	for child in hangar_box.get_children():
		child.queue_free()
	hangar_rows = {}
	var sim = Game.sim
	hangar_box.add_child(ThemeKit.label("Launch, orbit, scan, recall. A lost craft stays lost until rebuild spends raw mass.", 13, Color("8d826c")))
	hangar_target = ThemeKit.label("", 14, Color("d7e6c8"))
	hangar_box.add_child(hangar_target)
	var picks := HBoxContainer.new()
	picks.add_theme_constant_override("separation", 8)
	for place in sim.nodes:
		var pick := ThemeKit.button(str(place.name))
		pick.pressed.connect(_pick_node.bind(str(place.id)))
		picks.add_child(pick)
	hangar_box.add_child(picks)
	for item in sim.craft:
		var spec: Dictionary = sim.defs.craft[item.def_id]
		var block := VBoxContainer.new()
		block.add_child(ThemeKit.label("%s" % item.name, 16))
		block.add_child(ThemeKit.label(str(spec.job), 13, Color("8d826c")))
		var state := ThemeKit.label("", 14, Color("d7e6c8"))
		block.add_child(state)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var uid := str(item.uid)
		var parked := str(item.def_id) in ["fighter", "salvage_tender"]
		var lost := str(item.state) == "lost"
		if lost:
			var rebuild := ThemeKit.button("Rebuild")
			rebuild.pressed.connect(_order_uid.bind(uid, "rebuild"))
			row.add_child(rebuild)
			block.add_child(ThemeKit.label("Loss is permanent until rebuild spends 1 raw mass.", 13, Color("c4512c")))
		elif parked:
			block.add_child(ThemeKit.label("Parked. It stays in the rack this slice.", 13, Color("8d826c")))
		elif str(item.def_id) == "survey_probe":
			row.add_child(_order_button("Launch", uid, "launch"))
			row.add_child(_order_button("Orbit", uid, "orbit"))
			row.add_child(_order_button("Scan", uid, "scan"))
			row.add_child(_order_button("Return", uid, "return"))
		elif str(item.def_id) == "harvest_drone":
			row.add_child(_order_button("Launch", uid, "launch"))
			row.add_child(_order_button("Return", uid, "return"))
		else:
			row.add_child(_order_button("Launch", uid, "launch"))
			row.add_child(_order_button("Return", uid, "return"))
		if row.get_child_count() > 0:
			block.add_child(row)
		hangar_box.add_child(block)
		hangar_rows[uid] = state
	hangar_sig = _craft_sig()
	_refresh_hangar()


func _craft_sig() -> String:
	if Game.sim == null:
		return ""
	var bits: PackedStringArray = PackedStringArray()
	for item in Game.sim.craft:
		bits.append("%s:%s" % [str(item.uid), str(item.state)])
	return "|".join(bits)


func _order_button(text: String, uid: String, verb: String) -> Button:
	var button := ThemeKit.button(text)
	button.pressed.connect(_order_uid.bind(uid, verb))
	return button


func _pick_node(node_id: String) -> void:
	hangar_node = node_id
	if panel_kind == "hangar":
		_build_hangar()


func _order_uid(uid: String, verb: String) -> void:
	if Game.sim == null:
		return
	var message := CraftOrders.order(Game.sim, uid, verb, hangar_node)
	if message != "":
		Game.sim.say(message)
	if panel_kind == "hangar":
		_build_hangar()


func _refresh_hangar() -> void:
	var sim = Game.sim
	if sim == null:
		return
	var sig := _craft_sig()
	if sig != hangar_sig:
		_build_hangar()
		return
	if hangar_target != null:
		var place = sim.survey_node(hangar_node)
		var name := hangar_node if place == null else str(place.name)
		hangar_target.text = "Orders use %s." % name
	for item in sim.craft:
		var state: Label = hangar_rows.get(item.uid)
		if state == null:
			continue
		var hp := int(item.hp)
		var bat := int(item.battery)
		var extra := ""
		if str(item.order) != "":
			extra = "    %s" % str(item.order)
		state.text = "%s%s    hp %d    battery %d" % [item.state, extra, hp, bat]


func _fill_dossier() -> void:
	for child in dossier_box.get_children():
		child.queue_free()
	var sim = Game.sim
	var tag := DockBoard.tag_of(sim)
	var shown := tag if tag != "" else "none"
	dossier_box.add_child(_flat("Corp tag  %s" % shown, 15, Color("d7e6c8")))
	var order := ["orbit", "atmosphere", "surface", "crust", "biosign", "ruins", "legal"]
	for place in sim.nodes:
		var title := "%s    %d m" % [place.name, int(sim.player.pos.distance_to(place.pos))]
		dossier_box.add_child(ThemeKit.label(title, 16))
		var dossier: Dictionary = sim.scans.get(place.id, {})
		var layers: Dictionary = dossier.get("layers", {})
		for key in order:
			var known := false
			var text := "sealed"
			if layers.has(key):
				known = bool(layers[key].known)
				text = str(layers[key].text) if known else "sealed"
			var col := Color("e6d7bf") if known else Color("6d6558")
			dossier_box.add_child(ThemeKit.label("%s — %s" % [key, text], 13, col))
		if bool(dossier.get("complete", false)):
			var left := int(sim.deposits.get(place.id, 0))
			var legal := str(place.legal_title)
			dossier_box.add_child(ThemeKit.label("Seam: %s, %d left. Title: %s." % [place.resource.name, left, legal], 14, Color("d7e6c8")))
		else:
			dossier_box.add_child(ThemeKit.label("Probe has not sealed this node.", 13, Color("8d826c")))
		dossier_box.add_child(ThemeKit.label(" ", 8))


func _heat_text() -> String:
	var sim = Game.sim
	var blocks: Array = []
	for row in HeatWords.lines(sim, sim.defs):
		var mem: Array = row.memory
		var memory := "Memory clear." if mem.is_empty() else "Memory: " + ", ".join(mem)
		blocks.append("%s  (%s, %s)\nHeat %.0f — %s\n%s\n%s" % [
			row.name, row.kind, row.temper, row.heat, row.word, row.blurb, memory
		])
	blocks.append("Rule layers share one slate for a human agent or an NPC. Controller is a field, not a second health bar.")
	return "\n\n".join(blocks)


func _quest_text() -> String:
	var blocks: Array = []
	for entry in QuestLog.entries(Game.sim.defs, Game.sim):
		var where := ""
		if str(entry.get("where", "")) != "":
			where = "\nWhere: %s (%s)." % [str(entry.where), str(entry.get("link", ""))]
		var giver := ""
		if str(entry.get("giver", "")) != "":
			var giver_id := str(entry.giver)
			var giver_name := giver_id
			if Game.sim.defs.factions.has(giver_id):
				giver_name = str(Game.sim.defs.factions[giver_id].name)
			elif giver_id == "homestead":
				giver_name = "homestead notice"
			giver = "\nGiver: %s." % giver_name
		blocks.append("%s  [%s / %s]%s%s\n%s" % [entry.title, entry.kind, entry.state, giver, where, entry.summary])
	blocks.append("Mark sets the next place. Take accepts an offered contract. The keel does not move.")
	if blocks.is_empty():
		return "The log is blank."
	return "\n\n".join(blocks)


func _claim_text() -> String:
	var status := PocketRules.status(Game.sim)
	return "%s\nEligible: %s\nCore planted: %s\nFrozen: %s\nWalked: %s\n\n%s\n\n%s" % [
		status.name,
		"yes" if status.eligible else "no",
		"yes" if status.owned else "no",
		"yes" if status.frozen else "no",
		"yes" if status.surveyed else "no",
		status.line,
		Homestead.text(Game.sim),
	]


func _say_result(message: String) -> void:
	if message != "" and Game.sim != null:
		Game.sim.say(message)


func reset_overlays() -> void:
	Game.map_open = false
	_close_panel()
	if pause_box != null:
		pause_box.hide()
	if dead_box != null:
		dead_box.hide()
	dossier_timer = 0.0


func _recall_uid(uid: String) -> void:
	if Game.sim == null:
		return
	CraftOrders.recall(Game.sim, uid)


func _repair() -> void:
	if Game.sim == null:
		return
	var message := Game.sim.try_repair()
	if message != "":
		Game.sim.say(message)


func _launch(def_id: String) -> void:
	if def_id == "" or Game.sim == null:
		return
	var message := CraftOrders.launch(Game.sim, def_id)
	if message != "":
		Game.sim.say(message)


func _boat_id() -> String:
	if Game.sim == null:
		return ""
	for def_id in ["fighter", "salvage_tender", "away_shuttle"]:
		for item in Game.sim.craft:
			if str(item.def_id) == def_id:
				return def_id
	return ""


func _save() -> void:
	var message := Game.write_save()
	if Game.sim != null and message != "Log written.":
		Game.sim.say(message)


func _load() -> void:
	var message := Game.try_load()
	if message != "":
		if Game.sim != null:
			Game.sim.say(message)
		return
	Game.paused = false
	pause_box.hide()
	if Game.sim.player.alive:
		dead_box.hide()
	_close_panel()
	var world := get_parent().get_node_or_null("Sector")
	if world != null and world.has_method("snap"):
		world.snap()


func _menu() -> void:
	Game.abandon()
	var main := get_parent()
	if main.has_method("show_menu"):
		main.show_menu()


class ShipGlass extends Control:
	func _draw() -> void:
		if Game.sim == null or size.x < 8.0 or size.y < 8.0:
			return
		var ship: Dictionary = Game.sim.player
		var hull: Dictionary = Game.sim.defs.ships[str(ship.class_id)]
		var accent := Color(str(hull.accent))
		var body := Color(str(hull.color))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.016, 0.022, 0.72))
		var center := size * 0.5 + Vector2(0, 8)
		var radius := minf(size.x, size.y) * 0.34
		_corner_brackets(accent)
		draw_circle(center, radius * 1.05, Color(0.03, 0.07, 0.09, 0.45))
		var grid := Color(0.45, 0.72, 0.84, 0.1)
		var step := radius * 0.28
		for i in range(-4, 5):
			_grid_chord(center, radius * 0.92, true, float(i) * step, grid)
			_grid_chord(center, radius * 0.92, false, float(i) * step, grid)
		var tick := Color(0.62, 0.78, 0.84, 0.55)
		var tick_long := Color(0.86, 0.78, 0.52, 0.9)
		for i in 72:
			var ang := TAU * float(i) / 72.0
			var dir := Vector2(cos(ang), sin(ang))
			var major := i % 6 == 0
			var inner := radius - (9.0 if major else 4.0)
			draw_line(center + dir * inner, center + dir * radius, tick_long if major else tick, 1.4 if major else 1.0)
		draw_arc(center, radius, 0.0, TAU, 96, Color(0.72, 0.86, 0.92, 0.85), 1.6, true)
		draw_arc(center, radius * 0.78, 0.0, TAU, 80, Color(0.45, 0.64, 0.72, 0.35), 1.0, true)
		draw_arc(center, radius * 0.46, 0.0, TAU, 64, Color(0.45, 0.64, 0.72, 0.22), 1.0, true)
		var gap := radius * 0.16
		var arm := radius * 0.42
		var hair := Color(0.7, 0.84, 0.9, 0.28)
		draw_line(center + Vector2(gap, 0), center + Vector2(arm, 0), hair, 1.0)
		draw_line(center + Vector2(-arm, 0), center + Vector2(-gap, 0), hair, 1.0)
		draw_line(center + Vector2(0, gap), center + Vector2(0, arm), hair, 1.0)
		draw_line(center + Vector2(0, -arm), center + Vector2(0, -gap), hair, 1.0)
		var shapes: Array = Silhouette.shapes_of(Game.sim.defs, ship.modules)
		var layers: Array = Silhouette.layers_of(Game.sim.defs, ship.modules)
		var geom := Silhouette.parts(str(ship.class_id), shapes, layers)
		var bounds := _hull_bounds(geom)
		var span := maxf(bounds.size.x, bounds.size.y)
		var plan_scale := (radius * 1.35) / maxf(span, 1.0)
		var mid := bounds.position + bounds.size * 0.5
		var rot := -PI * 0.5
		var origin := center - mid.rotated(rot) * plan_scale
		var hp := clampf(float(ship.hp) / maxf(float(ship.max_hp), 1.0), 0.0, 1.0)
		Silhouette.draw(self, origin, rot, str(ship.class_id), shapes, plan_scale, body, accent, hp, false, layers)
		_draw_marks(center, radius * 1.12, hull, ship, accent)
		var font := ThemeDB.fallback_font
		if font == null:
			return
		var title := str(hull.callsign)
		var title_size := 18
		var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
		draw_string(font, Vector2(center.x - title_w * 0.5, 22.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color("f4ecdf"))
		var rule := minf(title_w, size.x * 0.36)
		draw_line(Vector2(center.x - rule * 0.5, 28.0), Vector2(center.x + rule * 0.5, 28.0), Color(accent.r, accent.g, accent.b, 0.9), 1.2)
		var klass := str(hull.get("class_name", ""))
		var class_size := 12
		var class_w := font.get_string_size(klass, HORIZONTAL_ALIGNMENT_LEFT, -1, class_size).x
		draw_string(font, Vector2(center.x - class_w * 0.5, 44.0), klass, HORIZONTAL_ALIGNMENT_LEFT, -1, class_size, Color("c4a46a"))
		var mounts := Fit.mounts(Game.sim.defs, ship)
		var words: PackedStringArray = PackedStringArray()
		for mount in mounts:
			words.append(str(mount.get("name", "")))
		var fit_line := "Clean keel" if words.is_empty() else " · ".join(words)
		var fit_size := 12
		var fit_w := font.get_string_size(fit_line, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_size).x
		if fit_w > size.x - 16.0 and words.size() > 1:
			fit_line = "%d mounts fitted" % words.size()
			fit_w = font.get_string_size(fit_line, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_size).x
		draw_string(font, Vector2(center.x - fit_w * 0.5, size.y - 14.0), fit_line, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_size, Color("d7e6ea"))

	func _corner_brackets(accent: Color) -> void:
		var col := Color(accent.r, accent.g, accent.b, 0.85)
		var arm := 14.0
		var inset := 8.0
		var corners: Array = [
			Vector2(inset, inset),
			Vector2(size.x - inset, inset),
			Vector2(inset, size.y - inset),
			Vector2(size.x - inset, size.y - inset),
		]
		var signs: Array = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
		for i in corners.size():
			var at: Vector2 = corners[i]
			var sign: Vector2 = signs[i]
			draw_line(at, at + Vector2(sign.x * arm, 0), col, 1.3)
			draw_line(at, at + Vector2(0, sign.y * arm), col, 1.3)

	func _grid_chord(center: Vector2, radius: float, horizontal: bool, offset: float, color: Color) -> void:
		var reach_sq := radius * radius - offset * offset
		if reach_sq <= 1.0:
			return
		var reach := sqrt(reach_sq)
		if horizontal:
			draw_line(center + Vector2(-reach, offset), center + Vector2(reach, offset), color, 1.0)
		else:
			draw_line(center + Vector2(offset, -reach), center + Vector2(offset, reach), color, 1.0)

	func _draw_marks(center: Vector2, radius: float, hull: Dictionary, ship: Dictionary, accent: Color) -> void:
		var marks: Array = []
		var used: Dictionary = {}
		for module_id in ship.modules:
			var mod: Dictionary = Game.sim.defs.modules.get(str(module_id), {})
			marks.append(mod)
			used[str(mod.get("slot", ""))] = true
		for slot_name in hull.get("slots", []):
			if used.has(str(slot_name)):
				continue
			marks.append({})
		var count := mini(marks.size(), 12)
		if count == 0:
			return
		for i in count:
			var ang := -PI * 0.5 + TAU * (float(i) + 0.5) / float(count)
			var at := center + Vector2(cos(ang), sin(ang)) * radius
			var mod: Dictionary = marks[i]
			_mark_glyph(at, not mod.is_empty(), str(mod.get("family", "")), accent)

	func _mark_glyph(at: Vector2, fitted: bool, family: String, accent: Color) -> void:
		var s := 5.5
		if not fitted:
			var open := PackedVector2Array([
				at + Vector2(0, -s),
				at + Vector2(s, 0),
				at + Vector2(0, s),
				at + Vector2(-s, 0),
				at + Vector2(0, -s),
			])
			draw_polyline(open, Color(0.62, 0.8, 0.88, 0.8), 1.2, true)
			return
		var ink := accent
		ink.a = 0.95
		match family:
			"offense":
				draw_colored_polygon(PackedVector2Array([
					at + Vector2(0, -s),
					at + Vector2(s * 0.85, s * 0.7),
					at + Vector2(-s * 0.85, s * 0.7),
				]), ink)
			"hangar":
				draw_arc(at, s * 0.75, 0.0, TAU, 16, ink, 1.6, true)
				draw_circle(at, 1.6, ink)
			"farm":
				draw_line(at + Vector2(-s, 0), at + Vector2(s, 0), ink, 1.6)
				draw_line(at + Vector2(0, -s), at + Vector2(0, s), ink, 1.6)
			"claim":
				draw_rect(Rect2(at - Vector2(s * 0.55, s * 0.55), Vector2(s * 1.1, s * 1.1)), ink, false, 1.5)
			_:
				draw_colored_polygon(PackedVector2Array([
					at + Vector2(0, -s),
					at + Vector2(s, 0),
					at + Vector2(0, s),
					at + Vector2(-s, 0),
				]), ink)

	func _hull_bounds(geom: Dictionary) -> Rect2:
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
			var c := Vector2(float(circle.x), float(circle.y))
			var rad := float(circle.r)
			lo.x = minf(lo.x, c.x - rad)
			lo.y = minf(lo.y, c.y - rad)
			hi.x = maxf(hi.x, c.x + rad)
			hi.y = maxf(hi.y, c.y + rad)
		if hi.x < lo.x:
			return Rect2(Vector2.ZERO, Vector2(40, 16))
		return Rect2(lo, hi - lo)
