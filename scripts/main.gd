extends Node

var menu: CanvasLayer
var helm: Node
var sector: Node2D
var hud: CanvasLayer
var desk: CanvasLayer
var tones: Node
var origin_hud: CanvasLayer
var _glyph_down := false
var _glyph_unicode := 0


func _ready() -> void:
	_hold_browser_keys()
	tones = preload("res://audio/tones.gd").new()
	add_child(tones)
	menu = preload("res://ui/menu.gd").new()
	add_child(menu)
	menu.start_game.connect(_on_start)
	menu.host_game.connect(_on_host)
	menu.join_game.connect(_on_join)
	menu.continue_game.connect(_on_continue)
	menu.quit_game.connect(_on_quit)


func _process(_delta: float) -> void:
	if Game.link != null and str(Game.link.role) == "host" and Game.sim != null:
		var saved := float(get_meta("host_save_t", 0.0)) + _delta
		if saved >= 2.0:
			Game.write_host_log(true)
			saved = 0.0
		set_meta("host_save_t", saved)
	if Game.sim == null or Game.mode != "sector":
		return
	Game.text_entry = _editing_text()
	if Game.text_entry:
		Game.clear_flight_keys()
	if tones != null and tones.has_method("play"):
		var thrusting: bool = (not Game.text_entry) and (not Game.map_open) and (Input.is_key_pressed(KEY_W) or float(Game.flight.get("thrust", 0.0)) > 0.2) and bool(Game.sim.player.alive) and not Game.paused
		if thrusting and not bool(get_meta("was_thrust", false)):
			tones.play("thrust")
		set_meta("was_thrust", thrusting)
		for name in Game.sim.sfx_queue:
			tones.play(str(name))
		Game.sim.sfx_queue.clear()


func _on_start(class_id: String) -> void:
	Game.begin_new(class_id)
	_enter_sector()


func _on_host(class_id: String) -> void:
	var err := Game.begin_host(class_id)
	if err != "":
		menu.back_to_slate(err)
		return
	_enter_sector()


func _on_join(class_id: String, address: String) -> void:
	var err := Game.begin_join(class_id, address)
	if err != "":
		menu.back_to_slate(err)
		return
	_enter_sector()


func _on_continue() -> void:
	var message := Game.try_load()
	if message != "":
		return
	_enter_sector()


func _unhandled_input(event: InputEvent) -> void:
	if helm == null or Game.mode != "sector":
		return
	var board = helm.get("world_vp")
	if board is SubViewport:
		board.push_unhandled_input(event)


func _input(event: InputEvent) -> void:
	if Game.mode != "sector" or not (event is InputEventKey):
		return
	var hud := get_node_or_null("Hud")
	if _editing_text():
		Game.text_entry = true
		Game.clear_flight_keys()
		_take_text(event as InputEventKey)
		return
	if hud != null and bool(hud.get("chat_open")):
		Game.text_entry = true
		Game.clear_flight_keys()
		return
	Game.text_entry = false
	var key_ev := event as InputEventKey
	if Game.map_open:
		Game.clear_flight_keys()
		Game.clear_flight()
		if key_ev.pressed and not key_ev.echo:
			var code := key_ev.keycode
			if code == KEY_NONE:
				code = key_ev.physical_keycode
			if code == KEY_ESCAPE or code == KEY_TAB:
				Game.set_map_open(false)
		var map_vp := get_viewport()
		if map_vp != null:
			map_vp.set_input_as_handled()
		return
	if key_ev.pressed and not key_ev.echo:
		var tab := key_ev.keycode == KEY_TAB or key_ev.physical_keycode == KEY_TAB
		if tab:
			Game.set_map_open(true)
			var tab_vp := get_viewport()
			if tab_vp != null:
				tab_vp.set_input_as_handled()
			return
	if _is_flight_key(key_ev.keycode) == false and _is_flight_key(key_ev.physical_keycode) == false:
		return
	if key_ev.echo:
		return
	# Record before GUI focus navigation. W is ui_up, so a focused scroll,
	# hint, or leftover line edit would otherwise eat the cast-off.
	Game.note_flight_key(key_ev.keycode, key_ev.pressed)
	Game.note_flight_key(key_ev.physical_keycode, key_ev.pressed)
	var vp := get_viewport()
	if vp == null:
		return
	var owner := vp.gui_get_focus_owner()
	if owner != null:
		vp.gui_release_focus()
	vp.set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Game.clear_flight_keys()
		Game.clear_flight()
		Game.cast_pulse = 0.0
		if hud != null:
			var pad: Node = hud.get("pad")
			if pad != null and pad.has_method("release"):
				pad.release()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_canvas()


func _is_flight_key(code: Key) -> bool:
	match code:
		KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_SHIFT:
			return true
		_:
			return false


func _focus_canvas() -> void:
	var vp := get_viewport()
	if vp != null and _editing_text() == false:
		vp.gui_release_focus()
	if OS.has_feature("web") == false:
		return
	JavaScriptBridge.eval("var c=document.getElementById('canvas');if(c){c.setAttribute('tabindex','0');c.focus();}", true)


func _take_text(key_ev: InputEventKey) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var edit := vp.gui_get_focus_owner() as LineEdit
	if edit == null:
		return
	# A repeat or a second keydown before keyup was landing in the field
	# after the real letters, so Red-Keel!! stored as Red-Keeld-.
	if key_ev.echo:
		vp.set_input_as_handled()
		return
	if key_ev.pressed and key_ev.unicode != 0:
		if _glyph_down and key_ev.unicode == _glyph_unicode:
			vp.set_input_as_handled()
			return
		_glyph_down = true
		_glyph_unicode = key_ev.unicode
		edit.insert_text_at_caret(char(key_ev.unicode))
		vp.set_input_as_handled()
		return
	if key_ev.pressed == false:
		_glyph_down = false


func _editing_text() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	return vp.gui_get_focus_owner() is LineEdit


func _hold_browser_keys() -> void:
	if OS.has_feature("web") == false:
		return
	JavaScriptBridge.eval("if(!window.__dsKeys){window.__dsKeys=1;window.addEventListener('keydown',function(e){if(e.code==='F5'||e.code==='F9'||e.key==='F5'||e.key==='F9'){e.preventDefault();}},true);}", true)


func _enter_sector() -> void:
	var yard_stage: Node = menu.get("stage")
	if yard_stage != null and yard_stage.has_method("set_live"):
		yard_stage.set_live(false)
	menu.hide()
	_focus_canvas()
	if helm == null:
		helm = preload("res://world/overhead.gd").new()
		helm.name = "Helm"
		add_child(helm)
		sector = helm.get("sector")
		hud = preload("res://ui/hud.gd").new()
		hud.name = "Hud"
		add_child(hud)
		desk = preload("res://ui/debug_pane.gd").new()
		desk.name = "DataDesk"
		add_child(desk)
	if helm.has_method("set_live"):
		helm.set_live(true)
	hud.show()
	if hud.has_method("reset_overlays"):
		hud.reset_overlays()
	if sector != null and sector.has_method("snap"):
		sector.snap()
	if origin_hud == null and OS.has_feature("web") == false:
		origin_hud = preload("res://ui/OriginDebugHUD.gd").new()
		origin_hud.name = "OriginDebug"
		add_child(origin_hud)
	if origin_hud != null:
		origin_hud.visible = OS.has_feature("web") == false


func _on_quit() -> void:
	if OS.has_feature("web"):
		return
	if Game.link != null and str(Game.link.role) == "host":
		Game.write_host_log(true)
	get_tree().quit()


func show_menu() -> void:
	if helm != null and helm.has_method("set_live"):
		helm.set_live(false)
	if hud != null:
		hud.hide()
	if origin_hud != null:
		origin_hud.hide()
	menu.show_root()
	menu.show()
