extends Node

var menu: CanvasLayer
var sector: Node2D
var hud: CanvasLayer
var tones: Node


func _ready() -> void:
	tones = preload("res://audio/tones.gd").new()
	add_child(tones)
	menu = preload("res://ui/menu.gd").new()
	add_child(menu)
	menu.start_game.connect(_on_start)
	menu.continue_game.connect(_on_continue)
	menu.quit_game.connect(func(): get_tree().quit())


func _process(_delta: float) -> void:
	if Game.sim == null or Game.mode != "sector":
		return
	if tones != null and tones.has_method("play"):
		var thrusting: bool = Input.is_key_pressed(KEY_W) and bool(Game.sim.player.alive) and not Game.paused
		if thrusting and not bool(get_meta("was_thrust", false)):
			tones.play("thrust")
		set_meta("was_thrust", thrusting)
		for name in Game.sim.sfx_queue:
			tones.play(str(name))
		Game.sim.sfx_queue.clear()


func _on_start(class_id: String) -> void:
	Game.begin_new(class_id)
	_enter_sector()


func _on_continue() -> void:
	var message := Game.try_load()
	if message != "":
		return
	_enter_sector()


func _enter_sector() -> void:
	menu.hide()
	if sector == null:
		sector = preload("res://world/sector_view.gd").new()
		sector.name = "Sector"
		add_child(sector)
		hud = preload("res://ui/hud.gd").new()
		hud.name = "Hud"
		add_child(hud)
	sector.show()
	hud.show()
	if hud.has_method("reset_overlays"):
		hud.reset_overlays()
	if sector.has_method("snap"):
		sector.snap()


func show_menu() -> void:
	if sector != null:
		sector.hide()
	if hud != null:
		hud.hide()
	menu.show_root()
	menu.show()
