extends SceneTree

var fails := 0
var phase := 0
var edit: LineEdit
var main: Node


func _process(_dt: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	if edit == null:
		main = load("res://scripts/main.gd").new()
		root.add_child(main)
		edit = LineEdit.new()
		edit.position = Vector2(24, 24)
		edit.size = Vector2(280, 40)
		edit.max_length = 12
		root.add_child(edit)
		return false
	edit.grab_focus()
	if phase < 6:
		return false
	var game := root.get_node("/root/Game")
	game.set("mode", "sector")
	game.clear_flight_keys()
	if edit.has_focus() == false:
		_bad("the corp field did not take focus")
	var typed := "Red-Keel!!"
	for i in typed.length():
		_press(typed.substr(i, 1))
	if edit.text != typed:
		_bad("the field kept '%s'" % edit.text)
	if DockBoard.clip_tag(edit.text) != "Red-Keel":
		_bad("set tag would store '%s'" % DockBoard.clip_tag(edit.text))
	if edit.has_focus() == false:
		_bad("the field lost focus while typing")
	var held: Dictionary = game.get("key_down")
	if held.has(int(KEY_E)) or held.has(int(KEY_D)):
		_bad("a letter in the tag moved the keel")
	edit.release_focus()
	game.set("text_entry", false)
	var before := edit.text
	_press("e")
	if edit.has_focus():
		_bad("a flight key left the field focused after Set tag")
	if edit.text != before:
		_bad("a flight key typed into a closed field")
	if fails == 0:
		print("TAG KEYS PASS")
	else:
		print("TAG KEYS FAIL %d" % fails)
	quit(fails)
	return true


func _press(ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.unicode = ch.unicode_at(0)
	var code := KEY_NONE
	match ch:
		"R", "r":
			code = KEY_R
		"e", "E":
			code = KEY_E
		"d", "D":
			code = KEY_D
		"K", "k":
			code = KEY_K
		"l", "L":
			code = KEY_L
		"-":
			code = KEY_MINUS
		"!":
			code = KEY_1
			ev.shift_pressed = true
	ev.keycode = code
	ev.physical_keycode = code
	root.push_input(ev)
	var again := ev.duplicate() as InputEventKey
	root.push_input(again)
	var echo := ev.duplicate() as InputEventKey
	echo.echo = true
	root.push_input(echo)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	up.unicode = 0
	root.push_input(up)


func _bad(message: String) -> void:
	fails += 1
	print("FAIL: ", message)
