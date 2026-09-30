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


var backdrop: Control
var root: Control
var stage: SubViewportContainer
var yard_line: Label
var pinned_keel := ""


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
	root_box = VBoxContainer.new()
	root_box.custom_minimum_size = Vector2(520, 280)
	root_box.add_theme_constant_override("separation", 10)
	root.add_child(root_box)
	root_box.add_child(ThemeKit.label("DARK SECTOR", 42, Color("e6d7bf")))
	var sky := "HELION DOCK"
	if Game.defs.has("system"):
		sky = str(Game.defs.system.name).to_upper()
	root_box.add_child(ThemeKit.label(sky, 16, Color("8a7344")))
	root_box.add_child(ThemeKit.label("One keel. The dock is a place, not a menu.", 14, Color("b7ab96")))
	var new_game := ThemeKit.button("New keel")
	new_game.pressed.connect(func(): _show_select("offline"))
	var host := ThemeKit.button("Host the dock")
	host.pressed.connect(func(): _show_select("host"))
	var dedicated := ThemeKit.button("Dedicated host")
	dedicated.pressed.connect(func():
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
	root_box.add_child(new_game)
	root_box.add_child(host)
	root_box.add_child(dedicated)
	root_box.add_child(address_line)
	root_box.add_child(join)
	root_box.add_child(continue_button)
	note = ThemeKit.label("", 13, Color("c4512c"))
	root_box.add_child(note)
	if not OS.has_feature("web"):
		root_box.add_child(quit)
	select_box = VBoxContainer.new()
	select_box.add_theme_constant_override("separation", 8)
	select_box.visible = false
	root.add_child(select_box)
	select_box.add_child(ThemeKit.label("Choose the keel. The other two stay in someone else's yard.", 16, Color("cbb892")))
	yard_line = ThemeKit.label("Needle is in the yard.", 14, Color("9eecf5"))
	select_box.add_child(yard_line)
	var keel_scroll := ScrollContainer.new()
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
	var wide := minf(460.0, screen.x - 24.0)
	var tall := minf(520.0, screen.y * 0.72)
	var left := 28.0 if screen.x > 860.0 else 12.0
	root_box.position = Vector2(left, maxf(16.0, screen.y * 0.06))
	root_box.size = Vector2(wide, tall)
	if address_line != null:
		address_line.custom_minimum_size = Vector2(minf(480.0, wide - 8.0), 40)
	var select_h := minf(340.0, screen.y * 0.46) if screen.x > 860.0 else minf(screen.y * 0.58, screen.y - 36.0)
	select_box.position = Vector2(12, screen.y - select_h - 8.0)
	select_box.size = Vector2(screen.x - 24.0, select_h)
	if keel_row != null:
		var stacked := screen.x < 860.0
		keel_row.columns = 1 if stacked else 3
		for card in keel_row.get_children():
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var card_w := screen.x - 36.0 if stacked else 240.0
			card.custom_minimum_size = Vector2(card_w, 0)
	backdrop.queue_redraw()


func show_root() -> void:
	_show_root()
	show()


func _show_root() -> void:
	root_box.show()
	select_box.hide()
	var has := Game.has_save()
	continue_button.disabled = not has
	continue_button.text = "Continue log" if has else "No log on the slate"


func _show_select(next: String) -> void:
	intent = next
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
		var fit := ""
		if klass == "vesper":
			fit = " Spine mast."
		elif klass == "anvil":
			fit = " Wide bay."
		elif klass == "kestrel":
			fit = " Wing guns."
		yard_line.text = "%s is in the yard.%s" % [str(hull.callsign), fit]


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
	box.add_child(ThemeKit.label(str(hull.callsign), 22))
	box.add_child(ThemeKit.label(str(hull.class_name), 13, Color("8a7344")))
	var previews := HBoxContainer.new()
	previews.add_theme_constant_override("separation", 4)
	previews.add_child(_preview(class_id, [], "As launched"))
	var yard: Array = hull.yard
	if not yard.is_empty():
		previews.add_child(_preview(class_id, [str(yard[0])], "Bolted"))
	box.add_child(previews)
	box.add_child(ThemeKit.label(str(hull.select_blurb), 13, Color("d9d0c2")))
	var stats := Fit.stats(Game.defs, {"class_id": class_id, "modules": []})
	box.add_child(ThemeKit.label(
		"Yaw %.0f°/s. Mass %.0f. Hold %d. Signature %s." % [stats.yaw_deg, stats.mass, stats.cargo_cap, stats.signature_word],
		13,
		Color("cbb892")
	))
	var craft_bits: Array = []
	for entry in hull.starting_craft:
		craft_bits.append("%d %s" % [int(entry.count), str(Game.defs.craft[entry.id].name)])
	box.add_child(ThemeKit.label("Rack: " + ", ".join(craft_bits), 13, Color("9fd0c8")))
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
	col.add_child(ThemeKit.label(caption, 12, Color("8a7344")))
	return col


class Backdrop extends Control:
	var stars: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 48291
		for _i in 160:
			stars.append(Vector2(rng.randf(), rng.randf()))

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 64.0)), Color(0.02, 0.03, 0.05, 0.42), true)
		draw_rect(Rect2(Vector2(0.0, size.y - 72.0), Vector2(size.x, 72.0)), Color(0.02, 0.03, 0.05, 0.5), true)
		draw_line(Vector2(40, 22), Vector2(size.x - 40, 22), Color("8a7344"), 1.0)
		draw_line(Vector2(40, size.y - 22), Vector2(size.x - 40, size.y - 22), Color("8a7344"), 1.0)


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
