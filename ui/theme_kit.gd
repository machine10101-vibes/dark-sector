class_name ThemeKit
extends RefCounted

## Dark hull glass and a soft cyan edge. Buttons stay focus-free so W can cast off.


static func build() -> Theme:
	var theme := Theme.new()
	var normal := _button_box(false)
	var hover := _button_box(false)
	hover.bg_color = Color(0.04, 0.22, 0.28, 0.94)
	hover.border_color = Color(0.55, 0.96, 1.0, 0.95)
	var pressed := _button_box(false)
	pressed.bg_color = Color(0.08, 0.32, 0.38, 0.96)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", _quiet_box())
	theme.set_color("font_color", "Button", Color("d7eef2"))
	theme.set_color("font_hover_color", "Button", Color("f4fcff"))
	theme.set_color("font_disabled_color", "Button", Color("7f9098"))
	theme.set_color("font_color", "Label", Color("e7f3f6"))
	theme.set_font_size("font_size", "Label", 15)
	theme.set_font_size("font_size", "Button", 15)
	theme.set_stylebox("panel", "PanelContainer", glass())
	return theme


static func _clip(box: StyleBoxFlat, accent: bool = false) -> void:
	box.corner_radius_top_left = 0
	box.corner_radius_top_right = 5
	box.corner_radius_bottom_right = 0
	box.corner_radius_bottom_left = 5
	if accent:
		box.border_width_top = 2


static func glass(strong: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.012, 0.03, 0.045, 0.86 if strong else 0.7)
	box.border_color = Color(0.42, 0.9, 0.98, 0.78 if strong else 0.42)
	box.set_border_width_all(1)
	_clip(box, true)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0.0, 0.16, 0.22, 0.38)
	box.shadow_size = 12
	return box


static func rail(strong: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.008, 0.03, 0.045, 0.78 if strong else 0.5)
	box.border_color = Color(0.38, 0.88, 0.98, 0.82 if strong else 0.4)
	box.set_border_width_all(1)
	box.border_width_left = 2
	_clip(box, true)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	box.shadow_color = Color(0.0, 0.12, 0.18, 0.28)
	box.shadow_size = 6
	return box


static func slim_chip(strong: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if strong:
		box.bg_color = Color(0.03, 0.14, 0.18, 0.82)
		box.border_color = Color(0.5, 0.94, 1.0, 0.88)
	else:
		box.bg_color = Color(0.02, 0.06, 0.09, 0.42)
		box.border_color = Color(0.32, 0.7, 0.8, 0.36)
	box.set_border_width_all(1)
	box.border_width_left = 2 if strong else 1
	_clip(box, strong)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	return box


static func veil() -> StyleBoxFlat:
	var box := glass(false)
	# Dark enough that the ice limb stays behind the words instead of through them.
	box.bg_color = Color(0.008, 0.02, 0.03, 0.86)
	box.border_color = Color(0.48, 0.9, 0.98, 0.62)
	box.set_border_width_all(1)
	_clip(box, true)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func chip_box(strong: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if strong:
		box.bg_color = Color(0.04, 0.16, 0.2, 0.92)
		box.border_color = Color(0.58, 0.94, 1.0, 0.88)
	else:
		box.bg_color = Color(0.03, 0.08, 0.11, 0.62)
		box.border_color = Color(0.36, 0.7, 0.8, 0.36)
	box.set_border_width_all(1)
	_clip(box, strong)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box


static func _button_box(primary: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if primary:
		box.bg_color = Color(0.03, 0.16, 0.22, 0.94)
		box.border_color = Color(0.45, 0.94, 1.0, 0.95)
		box.set_border_width_all(1)
	else:
		box.bg_color = Color(0.02, 0.07, 0.1, 0.72)
		box.border_color = Color(0.28, 0.62, 0.72, 0.5)
		box.set_border_width_all(1)
	_clip(box, primary)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func paint(node: Button, primary: bool) -> void:
	var normal := _button_box(primary)
	var hover := _button_box(primary)
	hover.bg_color = Color(0.06, 0.26, 0.32, 0.96)
	hover.border_color = Color(0.62, 0.98, 1.0, 1.0)
	var pressed := _button_box(primary)
	pressed.bg_color = Color(0.1, 0.34, 0.4, 0.98)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("disabled", _quiet_box())
	node.add_theme_color_override("font_color", Color("e9fbff") if primary else Color("c5d6dc"))
	node.add_theme_color_override("font_disabled_color", Color("6d7c82"))
	node.add_theme_font_size_override("font_size", 16 if primary else 14)


static func _quiet_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.04, 0.05, 0.42)
	box.border_color = Color(0.22, 0.38, 0.44, 0.28)
	box.set_border_width_all(1)
	_clip(box, false)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func label(text: String, size: int = 15, color: Color = Color("e7f3f6")) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func slim_button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.custom_minimum_size = Vector2(72, 36)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var normal := _button_box(false)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	_clip(normal, false)
	normal.bg_color = Color(0.02, 0.08, 0.12, 0.62)
	normal.border_color = Color(0.38, 0.84, 0.94, 0.55)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.05, 0.2, 0.26, 0.9)
	hover.border_color = Color(0.58, 0.96, 1.0, 0.95)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.08, 0.28, 0.34, 0.95)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_color_override("font_color", Color("d7eef2"))
	node.add_theme_font_size_override("font_size", 13)
	return node


static func slim_toggle(text: String, on: bool) -> Button:
	var node := slim_button(text)
	if not on:
		return node
	var hot := slim_chip(true)
	hot.content_margin_left = 10
	hot.content_margin_right = 10
	hot.content_margin_top = 4
	hot.content_margin_bottom = 4
	node.add_theme_stylebox_override("normal", hot)
	node.add_theme_stylebox_override("hover", hot)
	node.add_theme_color_override("font_color", Color("f4fcff"))
	return node


static func button(text: String, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.custom_minimum_size = Vector2(0, 48 if primary else 44)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint(node, primary)
	return node


static func field(text: String = "", width: float = 56.0) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.focus_mode = Control.FOCUS_ALL
	edit.mouse_filter = Control.MOUSE_FILTER_STOP
	edit.context_menu_enabled = false
	edit.caret_blink = true
	edit.custom_minimum_size = Vector2(width, 32)
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.015, 0.05, 0.07, 0.82)
	box.border_color = Color(0.4, 0.86, 0.96, 0.55)
	box.set_border_width_all(1)
	_clip(box, false)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	var focus := box.duplicate()
	focus.border_color = Color(0.72, 0.94, 0.98, 0.9)
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_color_override("font_color", Color("d7e6c8"))
	edit.add_theme_color_override("font_placeholder_color", Color("8d826c"))
	edit.add_theme_font_size_override("font_size", 13)
	return edit
