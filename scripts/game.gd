extends Node

var defs: Dictionary = {}
var sim: SectorSim
var link: ListenLink
var verbs: Dictionary = {}
var mode := "menu"
var paused := false
var zoom := 0.9


func _ready() -> void:
	defs = Catalog.boot()


func save_path() -> String:
	return "user://dark_sector_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(save_path())


func begin_new(class_id: String) -> void:
	_drop_link()
	sim = SectorSim.new(defs)
	sim.new_game(class_id)
	Catalog.arm_yards(sim)
	zoom = 0.9
	paused = false
	mode = "sector"


func begin_host(class_id: String) -> String:
	begin_new(class_id)
	link = ListenLink.new()
	var err := link.open_host()
	if err != "":
		link = null
		return err
	sim.say("Host is up on port %s. The spine is on this board: Helion Dock, Brass Lantern, Lease, Towline, First Soil, Perimeter. Gyre is the hatch. A second captain joins with that code." % link.code)
	return ""


func begin_join(class_id: String, address: String) -> String:
	begin_new(class_id)
	link = ListenLink.new()
	var who := "captain-%d" % int(Time.get_unix_time_from_system())
	sim.player.player_id = who
	var err := link.join(address, class_id, who)
	if err != "":
		link = null
		return err
	sim.say("Joining %s. The host keeps the world." % address)
	return ""


func tap(action: String, value = true) -> void:
	verbs[action] = value


func take_verbs() -> Dictionary:
	var out := verbs.duplicate()
	verbs = {}
	return out


func _drop_link() -> void:
	if link != null:
		link.close()
	link = null
	verbs = {}


func write_save() -> String:
	if sim == null:
		return "Nothing to write."
	if link != null and str(link.role) == "client":
		return "The host keeps the log."
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
	_drop_link()
	paused = false
	mode = "menu"
