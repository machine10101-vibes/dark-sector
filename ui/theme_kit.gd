class_name ThemeKit
extends RefCounted

## Dark hull glass and a soft cyan edge. Buttons stay focus-free so W can cast off.


static func build() -> Theme:
	var theme := Theme.new()
	var normal := _button_box(false)
	var hover := _button_box(false)
	hover.bg_color = Color(0.1, 0.18, 0.22, 0.88)
	hover.border_color = Color(0.62, 0.92, 0.96, 0.85)
	var pressed := _button_box(false)
	pressed.bg_color = Color(0.14, 0.28, 0.32, 0.92)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", pressed)
	theme.set_color("font_color", "Button", Color("d7eef2"))
	theme.set_color("font_hover_color", "Button", Color("f4fcff"))
	theme.set_color("font_disabled_color", "Button", Color("7f9098"))
	theme.set_color("font_color", "Label", Color("e7f3f6"))
	theme.set_font_size("font_size", "Label", 15)
	theme.set_font_size("font_size", "Button", 15)
	theme.set_stylebox("panel", "PanelContainer", glass())
	return theme


static func glass(strong: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.04, 0.06, 0.78 if strong else 0.58)
	box.border_color = Color(0.55, 0.86, 0.94, 0.62 if strong else 0.32)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 16
	return box


static func veil() -> StyleBoxFlat:
	var box := glass(false)
	box.bg_color = Color(0.02, 0.035, 0.05, 0.5)
	box.border_color = Color(0.62, 0.86, 0.92, 0.42)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func chip_box(strong: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if strong:
		box.bg_color = Color(0.07, 0.13, 0.16, 0.9)
		box.border_color = Color(0.78, 0.93, 0.98, 0.82)
	else:
		box.bg_color = Color(0.04, 0.08, 0.1, 0.55)
		box.border_color = Color(0.45, 0.7, 0.76, 0.28)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box


static func _button_box(primary: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if primary:
		box.bg_color = Color(0.07, 0.16, 0.2, 0.9)
		box.border_color = Color(0.55, 0.92, 0.96, 0.92)
		box.set_border_width_all(1)
	else:
		box.bg_color = Color(0.04, 0.07, 0.1, 0.62)
		box.border_color = Color(0.38, 0.58, 0.66, 0.4)
		box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func paint(node: Button, primary: bool) -> void:
	var normal := _button_box(primary)
	var hover := _button_box(primary)
	hover.bg_color = Color(0.12, 0.24, 0.28, 0.94)
	var pressed := _button_box(primary)
	pressed.bg_color = Color(0.16, 0.32, 0.36, 0.96)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("disabled", pressed)
	node.add_theme_color_override("font_color", Color("e9fbff") if primary else Color("c5d6dc"))
	node.add_theme_font_size_override("font_size", 16 if primary else 14)


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
