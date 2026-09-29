extends CanvasLayer

var root: Control
var helm_name: Label
var helm_flight: Label
var helm_zone: Label
var helm_cargo: Label
var helm_craft: Label
var banner: Label
var log_label: Label
var panel: PanelContainer
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
var dossier_timer := 0.0
var hold_button: Button


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ThemeKit.build()
	add_child(root)
	_build_helm()
	_build_panel()
	_build_pause()
	_build_dead()
	var hint := ThemeKit.label(
		"W thrust   S retro   A/D yaw   Q/E strafe   SPACE gun   wheel zoom     1 probe   2 harvest     B bay   H hangar   D dossier   F heat   J quests   K claim     Hold / Esc pause   F5 save   F9 load",
		12,
		Color("8d826c")
	)
	hint.position = Vector2(16, 692)
	hint.size = Vector2(1240, 22)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	hold_button = ThemeKit.button("Hold")
	hold_button.pressed.connect(_toggle_pause)
	root.add_child(hold_button)
	get_viewport().size_changed.connect(_fit)
	call_deferred("_fit")


func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	root.position = Vector2.ZERO
	root.size = screen
	if panel != null:
		panel.position = Vector2(screen.x - 472, 12)
		panel.size = Vector2(460, screen.y - 48)
	if pause_box != null:
		pause_box.position = screen * 0.5 - Vector2(220, 160)
		pause_box.size = Vector2(440, 330)
	if dead_box != null:
		dead_box.position = screen * 0.5 - Vector2(220, 160)
		dead_box.size = Vector2(440, 330)
	if hold_button != null:
		hold_button.position = Vector2(screen.x - 188, 12)
		hold_button.size = Vector2(172, 40)
	if log_label != null:
		log_label.position = Vector2(16, screen.y - 168)
		log_label.size = Vector2(700, 120)
	if banner != null:
		banner.position = Vector2(16, 118)
		banner.size = Vector2(860, 48)


func _process(_delta: float) -> void:
	if Game.mode != "sector" or Game.sim == null:
		return
	_refresh_helm()
	if banner != null:
		var text := ""
		if Game.sim.banner != "" and Game.sim.banner_t < 9.0:
			text = Game.sim.banner
		banner.text = text
		banner.visible = text != ""
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
	elif panel_kind == "bay":
		_refresh_bay_text()


func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != "sector" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		if panel_kind != "":
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
		KEY_D:
			_toggle("dossier")
		KEY_F:
			_toggle("heat")
		KEY_J:
			_toggle("quest")
		KEY_K:
			_toggle("claim")
		KEY_1, KEY_KP_1:
			_launch("survey_probe")
		KEY_2, KEY_KP_2:
			_launch("harvest_drone")
		KEY_3, KEY_KP_3:
			_launch(_boat_id())
		KEY_F5:
			_save()
		KEY_F9:
			_load()
		_:
			return
	get_viewport().set_input_as_handled()


func _build_helm() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(16, 12)
	box.custom_minimum_size = Vector2(760, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	helm_name = ThemeKit.label("DARK SECTOR", 13, Color("8a7344"))
	helm_flight = ThemeKit.label("", 16, Color("e6d7bf"))
	helm_zone = ThemeKit.label("", 14, Color("cbb892"))
	helm_cargo = ThemeKit.label("", 14, Color("d7e6c8"))
	helm_craft = ThemeKit.label("", 14, Color("9fd0c8"))
	box.add_child(helm_name)
	box.add_child(helm_flight)
	box.add_child(helm_zone)
	box.add_child(helm_cargo)
	box.add_child(helm_craft)
	banner = ThemeKit.label("", 16, Color("e7b15a"))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	log_label = ThemeKit.label("", 14, Color("b7ab96"))
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_label)


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.visible = false
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
	panel_title = ThemeKit.label("", 20, Color("e6d7bf"))
	box.add_child(panel_title)
	var close := ThemeKit.button("Close")
	close.pressed.connect(_close_panel)
	box.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.custom_minimum_size = Vector2(420, 0)
	scroll.add_child(inner)
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
	var note := ThemeKit.label("Your agent id is still on the wreck. Load an earlier log, or leave and take a new keel. The dock keeps the wreck either way.", 14)
	note.custom_minimum_size = Vector2(360, 0)
	var load := ThemeKit.button("Read the log")
	load.pressed.connect(_load)
	var menu := ThemeKit.button("Leave the dock")
	menu.pressed.connect(_menu)
	var box := dead_box.get_child(0)
	box.add_child(note)
	box.add_child(load)
	box.add_child(menu)


func _center_card(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 300)
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
	var zone: String = sim.zone_at(sim.player.pos)
	var zoom_word := "Tactical"
	if Game.zoom < 0.28:
		zoom_word = "Sector"
	elif Game.zoom < 0.7:
		zoom_word = "Local"
	helm_name.text = "%s    %s    %s" % [str(sim.defs.system.name).to_upper(), hull.class_name, hull.callsign]
	var keel := "Keel complaining." if stats.keel_warn else "Keel within tolerance."
	helm_flight.text = "%d m/s    yaw %.0f°/s    %s    sig %s    %s    %s" % [
		int(sim.player.vel.length()),
		stats.yaw_deg,
		_mass_line(stats),
		stats.signature_word,
		keel,
		zoom_word,
	]
	var heat := float(sim.heat.get(sim._pdo_id(), 0.0))
	helm_zone.text = "%s    %s heat %s (%.0f)" % [sim.zone_label(zone), sim._pdo_name(), HeatWords.word(heat), heat]
	helm_cargo.text = _cargo_line(sim, stats)
	helm_craft.text = _craft_line(sim)
	var bits: Array = []
	for line in sim.lines:
		bits.append(str(line.text))
	log_label.text = "\n".join(bits)


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
	for item in sim.craft:
		if str(item.state) == "docked":
			continue
		bits.append("%s %s" % [item.name, item.state])
	if bits.is_empty():
		return "Hangar sealed. Craft are aboard."
	return "Out: " + "   ".join(bits)


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
	match kind:
		"bay":
			panel_title.text = "Ship bay"
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
		"claim":
			panel_title.text = "Homestead"
			panel_body.text = _claim_text()


func _close_panel() -> void:
	panel_kind = ""
	panel.hide()


func _toggle_pause() -> void:
	if Game.sim == null or not Game.sim.player.alive:
		return
	Game.paused = not Game.paused
	pause_box.visible = Game.paused
	if Game.paused:
		_close_panel()


func _build_bay() -> void:
	for child in bay_box.get_children():
		child.queue_free()
	bay_buttons = {}
	var sim = Game.sim
	bay_preview = BayPreview.new()
	bay_preview.custom_minimum_size = Vector2(400, 170)
	bay_box.add_child(bay_preview)
	bay_detail = ThemeKit.label("", 14)
	bay_box.add_child(bay_detail)
	var crew_lines: Array = []
	for person in sim.player.crew:
		crew_lines.append("%s — %s" % [person.name, person.skill])
	var crew_text := "No names on the board."
	if not crew_lines.is_empty():
		crew_text = "\n".join(crew_lines)
	bay_box.add_child(ThemeKit.label("Crew\n" + crew_text, 14, Color("cbb892")))
	bay_box.add_child(ThemeKit.label("Overload is allowed. A heavy keel just turns and accelerates worse. Pull a part off while nobody is shooting.", 13, Color("8d826c")))
	var order: Array = ["cargo_blister", "gun_sponson", "sensor_mast", "farm_cassette", "armor_belt"]
	for module_id in order:
		if not sim.defs.modules.has(module_id):
			continue
		if not sim.player.yard.has(module_id) and not sim.player.modules.has(module_id):
			continue
		var mod: Dictionary = sim.defs.modules[module_id]
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 2)
		var title := "%s    %s    %s" % [mod.name, mod.size, mod.family]
		block.add_child(ThemeKit.label(title, 15))
		var meta := ThemeKit.label("", 13, Color("8d826c"))
		block.add_child(meta)
		var button := ThemeKit.button("Bolt on")
		button.pressed.connect(_on_bolt.bind(str(module_id)))
		block.add_child(button)
		bay_box.add_child(block)
		bay_buttons[str(module_id)] = {"meta": meta, "button": button}
	_refresh_bay_text()


func _refresh_bay_text() -> void:
	if bay_detail == null or not is_instance_valid(bay_detail):
		return
	var sim = Game.sim
	var stats := Fit.stats(sim.defs, sim.player)
	var com: Vector2 = stats.com
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
	bay_detail.text = "Mass %.0f t. Center of mass %.1f m off the spine. Thrust-to-weight %.2f. Yaw %.0f°/s.\nHold %d. Sensor %.0f. Signature %s. %s %s %s%s" % [
		stats.mass,
		com.length(),
		stats.ttw,
		stats.yaw_deg,
		stats.cargo_cap,
		stats.sensor,
		stats.signature_word,
		power_line,
		crew_line,
		keel,
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
		var foot: Dictionary = mod.get("footprint", {})
		var favored := _favored_line(sim, mod)
		var mounted: bool = bool(sim.player.modules.has(module_id))
		var state := "In the yard."
		if mounted:
			state = "On the keel."
		meta.text = "Mass %.0f. Power %.0f. Crew %.0f. Footprint %.0f×%.0f. %s %s" % [
			float(mod.mass), float(mod.power), float(mod.crew),
			float(foot.get("w", 0)), float(foot.get("h", 0)),
			favored, state,
		]
		button.disabled = fighting
		if mounted:
			button.text = "Pull off"
		else:
			button.text = "Bolt on"
	if bay_preview != null and is_instance_valid(bay_preview):
		bay_preview.queue_redraw()


func _favored_line(sim, mod: Dictionary) -> String:
	var favored := str(mod.get("favored", ""))
	if favored == "":
		return "Any keel."
	var hull: Dictionary = sim.defs.ships.get(favored, {})
	return "%s-favored." % str(hull.get("callsign", favored))


func _on_bolt(module_id: String) -> void:
	if Game.sim == null:
		return
	if Game.sim.player.modules.has(module_id):
		Game.sim.uninstall(module_id)
	else:
		Game.sim.install(module_id)
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
		blocks.append("%s  [%s / %s]\n%s" % [entry.title, entry.kind, entry.state, entry.summary])
	if blocks.is_empty():
		return "The log is blank."
	return "\n\n".join(blocks)


func _claim_text() -> String:
	var status := PocketRules.status(Game.sim)
	return "%s\nEligible: %s\nCore planted: %s\nWalked: %s\n\n%s\n\nFly into the pale ring trailing Cinder. A shuttle can walk it. Planting a core is the next work." % [
		status.name,
		"yes" if status.eligible else "no",
		"yes" if status.owned else "no",
		"yes" if status.surveyed else "no",
		status.line,
	]


func reset_overlays() -> void:
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


class BayPreview extends Control:
	func _draw() -> void:
		if Game.sim == null:
			return
		var ship: Dictionary = Game.sim.player
		var hull: Dictionary = Game.sim.defs.ships[ship.class_id]
		var shapes: Array = Silhouette.shapes_of(Game.sim.defs, ship.modules)
		var layers: Array = Silhouette.layers_of(Game.sim.defs, ship.modules)
		var origin := size * 0.5
		var scale := 1.2
		Silhouette.draw(
			self,
			origin,
			-PI * 0.5,
			str(ship.class_id),
			shapes,
			scale,
			Color(str(hull.color)),
			Color(str(hull.accent)),
			clampf(float(ship.hp) / maxf(float(ship.max_hp), 1.0), 0.0, 1.0),
			false,
			layers
		)
		var stats := Fit.stats(Game.sim.defs, ship)
		var com: Vector2 = stats.com
		var mark: Vector2 = Transform2D(-PI * 0.5, origin) * (com * scale)
		draw_line(mark + Vector2(-5, 0), mark + Vector2(5, 0), Color("e7b15a"), 1.3, true)
		draw_line(mark + Vector2(0, -5), mark + Vector2(0, 5), Color("e7b15a"), 1.3, true)
