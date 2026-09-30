extends SceneTree

var fails := 0
var phase := 0
var menu: Node
var hud: Node


func _process(_dt: float) -> bool:
	phase += 1
	if phase < 4:
		return false
	if menu == null:
		menu = load("res://ui/menu.gd").new()
		root.add_child(menu)
		hud = load("res://ui/hud.gd").new()
		root.add_child(hud)
		return false
	var screen := root.get_viewport().get_visible_rect().size
	print("LAYOUT SCREEN ", screen)
	_check_title(screen)
	_check_select(screen)
	_check_helm(screen, false)
	_check_helm(screen, true)
	if fails == 0:
		print("LAYOUT PASS")
	else:
		print("LAYOUT FAIL %d" % fails)
	quit(fails)
	return true


func _check_title(screen: Vector2) -> void:
	menu._show_root()
	menu._fit()
	var glass: Control = menu.get("slate_glass")
	_inside(glass, screen, "title glass")
	_buttons(menu, screen, "title")


func _check_select(screen: Vector2) -> void:
	menu._show_select("offline")
	menu._fit()
	var glass: Control = menu.get("select_glass")
	_inside(glass, screen, "select glass")
	_buttons(menu, screen, "select")


func _check_helm(screen: Vector2, touch: bool) -> void:
	hud.set("touch_on", touch)
	hud.set("touch_chosen", true)
	hud._fit()
	var cast: Button = hud.get("cast_button")
	var dock: Button = hud.get("dock_button")
	var board: Button = hud.get("board_button")
	cast.visible = true
	dock.visible = true
	board.visible = true
	var cue: Label = hud.get("haul_cue")
	cue.text = "Ice ring 451 m — hold that way."
	cue.visible = true
	var speed: Label = hud.get("stat_speed")
	speed.text = "220 m/s"
	var purse: Label = hud.get("stat_purse")
	purse.text = "PURSE  200"
	hud._layout_chrome(screen)
	var tag := "helm touch" if touch else "helm keys"
	var primary: Control = hud.get("primary_bar")
	var actions: Control = hud.get("action_scroll")
	var status: Control = hud.get("status_card")
	var hold: Control = hud.get("hold_button")
	_inside(primary, screen, tag + " primary")
	_inside(actions, screen, tag + " actions")
	_inside(status, screen, tag + " status")
	_inside(hold, screen, tag + " hold")
	_apart(status, primary, tag + " status/primary")
	_apart(primary, actions, tag + " primary/actions")
	_inside_parent(cue, status, tag + " cue")
	_inside_parent(speed, status, tag + " speed")
	_inside_parent(purse, status, tag + " purse")
	for node in [cast, dock, board, hud.get("quest_button"), hud.get("probe_button")]:
		var button := node as Control
		if button.visible:
			_inside(button, screen, tag + " " + button.name)
			if button.get_global_rect().size.y < 40.0:
				_bad(tag + " short " + button.name)
	if touch:
		var pad: Node = hud.get("pad")
		var joy: Control = pad.get("joy")
		var gun: Control = pad.get("fire_button")
		_inside(joy, screen, tag + " stick")
		_inside(gun, screen, tag + " gun")
		_apart(joy, primary, tag + " stick/primary")
		_apart(gun, primary, tag + " gun/primary")
		_apart(joy, actions, tag + " stick/actions")


func _buttons(host: Node, screen: Vector2, tag: String) -> void:
	_walk(host, screen, tag)


func _walk(node: Node, screen: Vector2, tag: String) -> void:
	if node is Button and node.visible:
		var button := node as Button
		var rect := button.get_global_rect()
		var bounds := Rect2(Vector2.ZERO, screen).grow(6.0)
		if bounds.intersects(rect):
			var shown := bounds.intersection(rect)
			if shown.size.y < rect.size.y - 8.0 or shown.size.x < minf(rect.size.x, 48.0) - 8.0:
				_bad("%s clips %s" % [tag, button.text])
		if button.custom_minimum_size.y < 44.0:
			_bad("%s short target %s" % [tag, button.text])
	for child in node.get_children():
		_walk(child, screen, tag)


func _inside(node: Control, screen: Vector2, tag: String) -> void:
	if node == null or node.visible == false:
		_bad(tag + " missing")
		return
	var rect := node.get_global_rect()
	var bounds := Rect2(Vector2(-4, -4), screen + Vector2(8, 8))
	if bounds.encloses(rect) == false:
		_bad("%s off screen %s" % [tag, rect])


func _inside_parent(node: Control, parent: Control, tag: String) -> void:
	if node == null or node.visible == false:
		return
	var rect := node.get_global_rect()
	var host := parent.get_global_rect().grow(2.0)
	if host.encloses(rect) == false:
		_bad("%s clipped %s" % [tag, rect])


func _apart(a: Control, b: Control, tag: String) -> void:
	if a == null or b == null or a.visible == false or b.visible == false:
		return
	if a.get_global_rect().grow(-1).intersects(b.get_global_rect()):
		_bad(tag + " overlap")


func _bad(message: String) -> void:
	fails += 1
	print("FAIL: ", message)
