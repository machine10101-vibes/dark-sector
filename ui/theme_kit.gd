class_name ThemeKit
extends RefCounted


static func build() -> Theme:
	var theme := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("141820")
	normal.border_color = Color("8a7344")
	normal.set_border_width_all(1)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("1d241c")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("2a2418")
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", pressed)
	theme.set_color("font_color", "Button", Color("e6d7bf"))
	theme.set_color("font_hover_color", "Button", Color("f4ecdf"))
	theme.set_color("font_disabled_color", "Button", Color("8a8070"))
	theme.set_color("font_color", "Label", Color("e6d7bf"))
	theme.set_font_size("font_size", "Label", 15)
	theme.set_font_size("font_size", "Button", 15)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.055, 0.067, 0.086, 0.94)
	panel.border_color = Color("8a7344")
	panel.set_border_width_all(1)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme


static func label(text: String, size: int = 15, color: Color = Color("e6d7bf")) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node
