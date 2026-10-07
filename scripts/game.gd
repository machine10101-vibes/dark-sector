extends Node

var defs: Dictionary = {}
var sim: SectorSim
var mode := "menu"
var paused := false
var zoom := 0.9


func _ready() -> void:
	defs = {
		"ships": Serde.load_json("res://data/ships.json"),
		"modules": Serde.load_json("res://data/modules.json"),
		"craft": Serde.load_json("res://data/craft.json"),
		"system": Serde.load_json("res://data/system.json"),
		"factions": Serde.load_json("res://data/factions.json"),
		"quests": Serde.load_json("res://data/quests.json"),
		"claim": Serde.load_json("res://data/claim.json"),
		"harvest": Serde.load_json("res://data/harvest.json"),
	}


func save_path() -> String:
	return "user://dark_sector_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(save_path())


func begin_new(class_id: String) -> void:
	sim = SectorSim.new(defs)
	sim.new_game(class_id)
	zoom = 0.9
	paused = false
	mode = "sector"


func write_save() -> String:
	if sim == null:
		return "Nothing to write."
	var data: Dictionary = sim.to_dict()
	data["camera_zoom"] = zoom
	var file := FileAccess.open(save_path(), FileAccess.WRITE)
	if file == null:
		return "The slate would not take the log."
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	sim.say("Log written.")
	sim.sfx("save")
	return "Log written."


func try_load() -> String:
	if not has_save():
		return "No log on the slate."
	var file := FileAccess.open(save_path(), FileAccess.READ)
	if file == null:
		return "The log would not open."
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return "The log did not parse."
	if int(data.get("version", 0)) != 1:
		return "That log is from another keel."
	sim = SectorSim.new(defs)
	sim.from_dict(data)
	zoom = clampf(float(data.get("camera_zoom", 0.9)), 0.05, 1.55)
	paused = false
	mode = "sector"
	return ""


func abandon() -> void:
	paused = false
	mode = "menu"
