extends CanvasLayer

## Screen readout. Not a world body — do not register it with FloatingOrigin.

var _label: Label
var _plate: ColorRect


func _ready() -> void:
	layer = 30
	_plate = ColorRect.new()
	_plate.color = Color(0.04, 0.05, 0.07, 0.78)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color("e6d7bf"))
	add_child(_label)
	_place()


func _place() -> void:
	var screen := get_viewport().get_visible_rect().size
	var at := Vector2(screen.x - 258.0, screen.y - 248.0)
	var box := Vector2(238.0, 146.0)
	if screen.x < 720.0:
		at = Vector2(8.0, 228.0)
		box = Vector2(minf(screen.x - 16.0, 210.0), 78.0)
	_plate.position = at
	_plate.size = box
	_label.position = at + Vector2(8.0, 6.0)
	_label.size = box - Vector2(14.0, 10.0)


func _process(_delta: float) -> void:
	_place()
	var gate: Variant = WorldCoord.gate()
	if gate == null or _label == null:
		return
	var origin: Vector2 = gate.origin_m
	var world := Vector2.ZERO
	var render := Vector2.ZERO
	var ship: Node2D = gate.focus
	if ship != null and is_instance_valid(ship):
		render = ship.global_position
		var stored: Variant = ship.get("world_m")
		if stored is Vector2:
			world = stored
		else:
			world = gate.world_of_node(ship)
	_label.text = "origin_m  %.1f, %.1f\nfocus world_m  %.1f, %.1f\nrender  %.1f, %.1f\nrebase  %d" % [
		origin.x, origin.y, world.x, world.y, render.x, render.y, gate.rebase_count
	]
