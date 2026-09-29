extends Node

var menu: CanvasLayer
var helm: Node
var sector: Node2D
var hud: CanvasLayer
var desk: CanvasLayer
var tones: Node
var origin_hud: CanvasLayer


func _ready() -> void:
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
	if tones != null and tones.has_method("play"):
		var thrusting: bool = (Input.is_key_pressed(KEY_W) or float(Game.flight.get("thrust", 0.0)) > 0.2) and bool(Game.sim.player.alive) and not Game.paused
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
		menu.set_note(err)
		return
	_enter_sector()


func _on_join(class_id: String, address: String) -> void:
	var err := Game.begin_join(class_id, address)
	if err != "":
		menu.set_note(err)
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


func _enter_sector() -> void:
	menu.hide()
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
	if origin_hud == null:
		origin_hud = preload("res://ui/OriginDebugHUD.gd").new()
		origin_hud.name = "OriginDebug"
		add_child(origin_hud)
	origin_hud.show()


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
