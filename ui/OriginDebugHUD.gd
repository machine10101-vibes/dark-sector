extends CanvasLayer

## Screen readout. Not a world body — do not register it with FloatingOrigin.

var _label: Label


func _ready() -> void:
	layer = 30
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color("e6d7bf"))
	add_child(_label)


func _process(_delta: float) -> void:
	if FloatingOrigin == null or _label == null:
		return
	var origin: Vector2 = FloatingOrigin.origin_m
	var world := Vector2.ZERO
	var render := Vector2.ZERO
	var ship: Node2D = FloatingOrigin.focus
	if ship != null and is_instance_valid(ship):
		render = ship.global_position
		var stored: Variant = ship.get("world_m")
		if stored is Vector2:
			world = stored
		else:
			world = FloatingOrigin.world_of_node(ship)
	_label.text = "origin_m  %.1f, %.1f\nfocus world_m  %.1f, %.1f\nrender  %.1f, %.1f\nrebase  %d" % [
		origin.x, origin.y, world.x, world.y, render.x, render.y, FloatingOrigin.rebase_count
	]
