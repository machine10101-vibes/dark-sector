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
	if hud == null:
		print("LAYOUT FAIL hud")
		quit(1)
		return true
	var screen := root.get_viewport().get_visible_rect().size
	print("LAYOUT SCREEN ", screen)
	_check_title(screen)
	_check_select(screen)
	_check_helm(screen, false)
	_check_helm(screen, true)
	if screen.y < 520.0 and screen.x > screen.y:
		_check_market(screen)
	if fails == 0:
		print("LAYOUT PASS")
	else:
		print("LAYOUT FAIL %d" % fails)
	quit(fails)
	return true


func _check_title(screen: Vector2) -> void:
	menu._show_root()
	menu._fit()
	_resort(menu)
	var glass: Control = menu.get("slate_glass")
	_inside(glass, screen, "title glass")
	_buttons(menu, screen, "title")
	var cont: Button = menu.get("continue_button")
	_inside_parent(cont, glass, "title continue")


func _check_select(screen: Vector2) -> void:
	menu._show_select("offline")
	menu._fit()
	_resort(menu)
	var glass: Control = menu.get("select_glass")
	_inside(glass, screen, "select glass")
	_buttons(menu, screen, "select")
	var back := _find_button(menu, "Back")
	_inside_parent(back, glass, "select back")
	if back != null and screen.x > screen.y and screen.y < 520.0 and back.get_global_rect().end.y > screen.y - 24.0:
		_bad("select back low %s" % back.get_global_rect())
	var row: Node = menu.get("keel_row")
	if row != null:
		for card in row.get_children():
			_inside_parent(card, glass, "select card")
			_inside(card, screen, "select card screen")


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
	hud.set("show_tag", true)
	var flight: Label = hud.get("helm_flight")
	if screen.y < 520.0:
		flight.text = "Red-Keel"
	else:
		flight.text = "Needle  ·  Red-Keel"
	flight.visible = true
	hud._layout_chrome(screen)
	_resort(hud)
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
	_inside_parent(flight, status, tag + " tag")
	_apart(flight, primary, tag + " tag/primary")
	if screen.y < 520.0 and flight.get_global_rect().size.y > 32.0:
		_bad(tag + " tag tall %s" % flight.get_global_rect())
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


func _check_market(screen: Vector2) -> void:
	hud.set("touch_on", true)
	hud.set("touch_chosen", true)
	hud.set("show_tag", true)
	var flight: Label = hud.get("helm_flight")
	flight.text = "Red-Keel"
	flight.autowrap_mode = TextServer.AUTOWRAP_OFF
	flight.visible = true
	var panel: Control = hud.get("panel")
	panel.show()
	var box: Node = hud.get("market_box")
	box.visible = true
	if box.get_child_count() == 0:
		for word in ["Buy glasswheat", "Sell glasswheat", "Set tag", "Slip", "Slip", "Slip", "Slip"]:
			var button := Button.new()
			button.text = word
			button.custom_minimum_size = Vector2(160, 44)
			box.add_child(button)
	hud._fit()
	_resort(hud)
	var primary: Control = hud.get("primary_bar")
	var actions: Control = hud.get("action_scroll")
	var status: Control = hud.get("status_card")
	var speed: Label = hud.get("stat_speed")
	var purse: Label = hud.get("stat_purse")
	_inside(panel, screen, "market panel")
	_apart(panel, status, "market/status")
	_apart(panel, primary, "market/primary")
	_apart(panel, actions, "market/actions")
	_inside_parent(speed, status, "market speed")
	_inside_parent(purse, status, "market purse")
	_inside_parent(flight, status, "market tag")
	_apart(flight, panel, "market tag/panel")
	if flight.text != "Red-Keel":
		_bad("tag line reads %s" % flight.text)
	if flight.get_global_rect().size.y > 32.0:
		_bad("tag line tall %s" % flight.get_global_rect())
	var scroll: Control = hud.get("panel_scroll")
	_inside_parent(scroll, panel, "market scroll")
	var pad: Node = hud.get("pad")
	var joy: Control = pad.get("joy")
	var gun: Control = pad.get("fire_button")
	_apart(panel, joy, "market/stick")
	_apart(panel, gun, "market/gun")
	if panel.get_global_rect().end.y > primary.position.y - 4.0:
		_bad("market covers bar %s vs primary %s" % [panel.get_global_rect(), primary.get_global_rect()])


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _buttons(host: Node, screen: Vector2, tag: String) -> void:
	_walk(host, screen, tag)


func _walk(node: Node, screen: Vector2, tag: String) -> void:
	if node is Button and node.visible:
		var button := node as Button
		var rect := button.get_global_rect()
		var bounds := Rect2(Vector2.ZERO, screen).grow(4.0)
		var text := button.text
		var must := text == "New keel" or text == "Back" or text.begins_with("Take the") or text.contains("Continue") or text.contains("No log") or text == "Cast" or text == "Cast off" or text == "Board" or text == "Quests" or text == "Probe"
		if must:
			if bounds.encloses(rect) == false:
				_bad("%s off %s %s" % [tag, text, rect])
		elif bounds.intersects(rect):
			var shown := bounds.intersection(rect)
			if shown.size.y < rect.size.y - 8.0 or shown.size.x < minf(rect.size.x, 48.0) - 8.0:
				_bad("%s clips %s" % [tag, text])
		if button.custom_minimum_size.y < 44.0:
			_bad("%s short target %s" % [tag, text])
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
		_bad("%s overlap %s vs %s" % [tag, a.get_global_rect(), b.get_global_rect()])


func _resort(node: Node) -> void:
	node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		_resort(child)


func _bad(message: String) -> void:
	fails += 1
	print("FAIL: ", message)
