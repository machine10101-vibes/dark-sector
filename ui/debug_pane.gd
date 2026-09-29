extends CanvasLayer

var panel: PanelContainer
var system_edit: LineEdit
var part_edit: LineEdit
var flag_edit: LineEdit
var out_label: Label


func _ready() -> void:
	layer = 40
	visible = false
	panel = PanelContainer.new()
	panel.position = Vector2(16, 180)
	panel.size = Vector2(460, 360)
	panel.theme = ThemeKit.build()
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(ThemeKit.label("Data desk  —  F3", 16, Color("e6d7bf")))
	box.add_child(ThemeKit.label("Reload, spawn a system, or grant a dropped def. No recompile.", 12, Color("8d826c")))
	system_edit = LineEdit.new()
	system_edit.placeholder_text = "System id  HC-V1-R3-S4"
	system_edit.text = "HC-V1-R3-S4"
	box.add_child(system_edit)
	part_edit = LineEdit.new()
	part_edit.placeholder_text = "Module, crop, or animal id"
	part_edit.text = "keel_cage"
	box.add_child(part_edit)
	flag_edit = LineEdit.new()
	flag_edit.placeholder_text = "Quest flag"
	flag_edit.text = "glass_standing"
	box.add_child(flag_edit)
	_button(box, "Reload data", _reload)
	_button(box, "Spawn system", _spawn)
	_button(box, "Grant module", _grant_module)
	_button(box, "Grant crop", _grant_crop)
	_button(box, "Grant animal", _grant_animal)
	_button(box, "Grant flag", _grant_flag)
	_button(box, "Print why and color", _print_why)
	out_label = ThemeKit.label("", 13, Color("d7e6c8"))
	out_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	out_label.custom_minimum_size = Vector2(420, 72)
	box.add_child(out_label)


func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != "sector" or Game.sim == null:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if (event as InputEventKey).keycode != KEY_F3:
		return
	visible = not visible
	get_viewport().set_input_as_handled()


func _button(box: VBoxContainer, text: String, call: Callable) -> void:
	var button := ThemeKit.button(text)
	button.pressed.connect(call)
	box.add_child(button)


func _reload() -> void:
	if Game.sim == null:
		return
	_show(Catalog.reload(Game.sim))


func _spawn() -> void:
	if Game.sim == null:
		return
	_show(Catalog.spawn(Game.sim, system_edit.text.strip_edges()))


func _grant_module() -> void:
	if Game.sim == null:
		return
	_show(Catalog.grant(Game.sim, "module", part_edit.text.strip_edges()))


func _grant_crop() -> void:
	if Game.sim == null:
		return
	_show(Catalog.grant(Game.sim, "crop", part_edit.text.strip_edges()))


func _grant_animal() -> void:
	if Game.sim == null:
		return
	_show(Catalog.grant(Game.sim, "animal", part_edit.text.strip_edges()))


func _grant_flag() -> void:
	if Game.sim == null:
		return
	_show(Catalog.grant(Game.sim, "flag", flag_edit.text.strip_edges()))


func _print_why() -> void:
	if Game.sim == null:
		return
	_show(Catalog.describe(Game.sim))


func _show(line: String) -> void:
	out_label.text = line
