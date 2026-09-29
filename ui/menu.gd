extends CanvasLayer

signal start_game(class_id: String)
signal continue_game
signal quit_game

var root_box: VBoxContainer
var select_box: Control
var continue_button: Button


var backdrop: Control
var root: Control


func _ready() -> void:
	layer = 30
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
	new_game.pressed.connect(func(): _show_select())
	continue_button = ThemeKit.button("Continue log")
	continue_button.pressed.connect(func(): continue_game.emit())
	var quit := ThemeKit.button("Leave")
	quit.pressed.connect(func(): quit_game.emit())
	root_box.add_child(new_game)
	root_box.add_child(continue_button)
	if not OS.has_feature("web"):
		root_box.add_child(quit)
	select_box = VBoxContainer.new()
	select_box.add_theme_constant_override("separation", 8)
	select_box.visible = false
	root.add_child(select_box)
	select_box.add_child(ThemeKit.label("Choose the keel. The other two stay in someone else's yard.", 16, Color("cbb892")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	select_box.add_child(row)
	for class_id in ["vesper", "anvil", "kestrel"]:
		row.add_child(_card(class_id))
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
	root.position = Vector2.ZERO
	root.size = screen
	root_box.position = Vector2((screen.x - 520.0) * 0.5, (screen.y - 340.0) * 0.5)
	root_box.size = Vector2(520, 340)
	select_box.position = Vector2(28, 18)
	select_box.size = screen - Vector2(56, 32)
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


func _show_select() -> void:
	root_box.hide()
	select_box.show()


func _choose(class_id: String) -> void:
	start_game.emit(class_id)


func _card(class_id: String) -> PanelContainer:
	var hull: Dictionary = Game.defs.ships[class_id]
	var card := PanelContainer.new()
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
		draw_rect(Rect2(Vector2.ZERO, size), Color("07080c"), true)
		for star in stars:
			draw_circle(Vector2(star.x * size.x, star.y * size.y), 1.15, Color(0.90, 0.84, 0.72, 0.25 + star.y * 0.45))
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
			false
		)
